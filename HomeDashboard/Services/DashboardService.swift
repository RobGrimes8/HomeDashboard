import Foundation

protocol DashboardServiceDelegate: AnyObject {
    func dashboardService(_ service: DashboardService, didUpdate snapshot: DashboardSnapshot)
    func dashboardService(_ service: DashboardService, didFailWith error: Error)
}

/// Aggregates all local device services and refreshes on a timer.
final class DashboardService {

    weak var delegate: DashboardServiceDelegate?

    private var config: AppConfig
    private let lightsService: LightsService
    private let sonosService: SonosService
    private var refreshTimer: Timer?
    private(set) var latestSnapshot: DashboardSnapshot = .empty

    init(config: AppConfig) {
        self.config = config
        let client = LocalHTTPClient(timeout: config.requestTimeoutSeconds)
        self.lightsService = LightsService(client: client, config: config)
        self.sonosService = SonosService(client: client, config: config)
    }

    func updateConfig(_ config: AppConfig) {
        self.config = config
        lightsService.updateConfig(config)
        sonosService.updateConfig(config)
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshNow()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: config.refreshIntervalSeconds, repeats: true) { [weak self] _ in
            self?.refreshNow()
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refreshNow() {
        let group = DispatchGroup()
        var lightGroups: [SmartDevice] = []
        var lights: [SmartDevice] = []
        var speakers: [SmartDevice] = []
        var errors: [String] = []
        let lock = NSLock()

        if config.isHueConfigured {
            group.enter()
            lightsService.fetchLights { result in
                lock.lock()
                defer { lock.unlock() }
                switch result {
                case .success(let devices):
                    lights = devices
                case .failure(let error):
                    errors.append("Lights: \(error.localizedDescription)")
                }
                group.leave()
            }

            group.enter()
            lightsService.fetchGroups { result in
                lock.lock()
                defer { lock.unlock() }
                switch result {
                case .success(let devices):
                    lightGroups = devices
                case .failure(let error):
                    errors.append("Groups: \(error.localizedDescription)")
                }
                group.leave()
            }
        }

        if !config.sonosSpeakerIPs.isEmpty {
            group.enter()
            sonosService.fetchSpeakers { result in
                lock.lock()
                defer { lock.unlock() }
                switch result {
                case .success(let devices):
                    speakers = devices
                case .failure(let error):
                    errors.append("Sonos: \(error.localizedDescription)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            let customGroups = self.lightsService.buildCustomGroups(from: lights)
            let allGroups = lightGroups + customGroups

            DebugLog.shared.log("Refresh: \(allGroups.count) groups, \(lights.count) lights, \(speakers.count) speakers")

            let snapshot = DashboardSnapshot(
                lightGroups: allGroups,
                lights: lights,
                speakers: speakers,
                lastUpdated: Date(),
                errorMessage: errors.isEmpty ? nil : errors.joined(separator: "\n")
            )
            self.latestSnapshot = snapshot
            self.delegate?.dashboardService(self, didUpdate: snapshot)

            if allGroups.isEmpty && lights.isEmpty && speakers.isEmpty, let first = errors.first {
                self.delegate?.dashboardService(self, didFailWith: LocalHTTPError.transport(NSError(
                    domain: "HomeDashboard",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: first]
                )))
            }
        }
    }

    func toggleDevice(_ device: SmartDevice, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        DebugLog.shared.log("Toggle \(device.name) (\(device.kind.rawValue)) → \(!device.isOn ? "on" : "off")")
        switch device.kind {
        case .lightGroup:
            if device.id.hasPrefix("group-") {
                let groupID = String(device.id.dropFirst("group-".count))
                lightsService.setGroupOn(groupID, isOn: !device.isOn, completion: completion)
            } else if device.id.hasPrefix("custom-") {
                let index = Int(device.id.dropFirst("custom-".count)) ?? 0
                lightsService.setCustomGroupOn(
                    index: index,
                    lights: latestSnapshot.lights,
                    isOn: !device.isOn,
                    completion: completion
                )
            } else {
                completion(.failure(.decodingFailed))
            }
        case .light:
            lightsService.setLightOn(device.id, isOn: !device.isOn, completion: completion)
        default:
            completion(.failure(.decodingFailed))
        }
    }

    func setDeviceBrightness(_ device: SmartDevice, brightness: Int, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        switch device.kind {
        case .lightGroup:
            if device.id.hasPrefix("group-") {
                let groupID = String(device.id.dropFirst("group-".count))
                lightsService.setGroupBrightness(groupID, brightness: brightness, completion: completion)
            } else if device.id.hasPrefix("custom-") {
                let index = Int(device.id.dropFirst("custom-".count)) ?? 0
                lightsService.setCustomGroupBrightness(
                    index: index,
                    lights: latestSnapshot.lights,
                    brightness: brightness,
                    completion: completion
                )
            } else {
                completion(.failure(.decodingFailed))
            }
        case .light:
            lightsService.setBrightness(device.id, brightness: brightness, completion: completion)
        default:
            completion(.failure(.decodingFailed))
        }
    }

    func toggleLight(_ device: SmartDevice, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        toggleDevice(device, completion: completion)
    }

    func setLightBrightness(_ device: SmartDevice, brightness: Int, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        setDeviceBrightness(device, brightness: brightness, completion: completion)
    }

    func setSpeakerVolume(_ device: SmartDevice, volume: Int, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        sonosService.setVolume(device.id, volume: volume, completion: completion)
    }

    func adjustSpeakerVolume(_ device: SmartDevice, by delta: Int, completion: @escaping (Result<Int, LocalHTTPError>) -> Void) {
        sonosService.adjustVolume(device.id, by: delta, completion: completion)
    }

    func toggleSpeakerPlayback(_ device: SmartDevice, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        if device.isOn {
            sonosService.pause(device.id, completion: completion)
        } else {
            sonosService.play(device.id, completion: completion)
        }
    }

    func skipSpeakerTrack(_ device: SmartDevice, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        sonosService.nextTrack(device.id, completion: completion)
    }

    func previousSpeakerTrack(_ device: SmartDevice, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        sonosService.previousTrack(device.id, completion: completion)
    }

    func playSpeakerPlaylist(
        _ device: SmartDevice,
        playlist: AppConfig.SpotifyPlaylist,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        sonosService.playSpotifyPlaylist(on: device.id, title: playlist.name, uri: playlist.uri, completion: completion)
    }

    func fetchSpeakerFavorites(
        _ device: SmartDevice,
        completion: @escaping (Result<[SonosFavorite], LocalHTTPError>) -> Void
    ) {
        sonosService.fetchFavorites(on: device.id, completion: completion)
    }

    func fetchSpeakerFavoriteBrowseDebug(
        _ device: SmartDevice,
        browseID: String,
        completion: @escaping (Result<String, LocalHTTPError>) -> Void
    ) {
        sonosService.fetchFavoriteBrowseDebug(on: device.id, browseID: browseID, completion: completion)
    }

    func playSpeakerFavorite(
        _ device: SmartDevice,
        favorite: SonosFavorite,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        sonosService.playFavorite(on: device.id, favorite: favorite, completion: completion)
    }
}
