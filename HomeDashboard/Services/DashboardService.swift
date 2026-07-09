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
        }

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

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            let snapshot = DashboardSnapshot(
                lights: lights,
                speakers: speakers,
                lastUpdated: Date(),
                errorMessage: errors.isEmpty ? nil : errors.joined(separator: "\n")
            )
            self.latestSnapshot = snapshot
            self.delegate?.dashboardService(self, didUpdate: snapshot)

            if lights.isEmpty && speakers.isEmpty, let first = errors.first {
                self.delegate?.dashboardService(self, didFailWith: LocalHTTPError.transport(NSError(
                    domain: "HomeDashboard",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: first]
                )))
            }
        }
    }

    func toggleLight(_ device: SmartDevice, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        lightsService.setLightOn(device.id, isOn: !device.isOn, completion: completion)
    }

    func setLightBrightness(_ device: SmartDevice, brightness: Int, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        lightsService.setBrightness(device.id, brightness: brightness, completion: completion)
    }

    func setSpeakerVolume(_ device: SmartDevice, volume: Int, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        sonosService.setVolume(device.id, volume: volume, completion: completion)
    }
}
