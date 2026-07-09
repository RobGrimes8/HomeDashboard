import Foundation

/// Sonos local HTTP API (port 1400).
/// Uses UPnP SOAP and device description — no cloud account required.
final class SonosService {

    private let client: LocalHTTPClient
    private var config: AppConfig

    init(client: LocalHTTPClient, config: AppConfig) {
        self.client = client
        self.config = config
    }

    func updateConfig(_ config: AppConfig) {
        self.config = config
    }

    func fetchSpeakers(completion: @escaping (Result<[SmartDevice], LocalHTTPError>) -> Void) {
        let group = DispatchGroup()
        var speakers: [SmartDevice] = []
        var firstError: LocalHTTPError?
        let lock = NSLock()

        for ip in config.sonosSpeakerIPs {
            group.enter()
            fetchSpeaker(at: ip) { result in
                lock.lock()
                defer { lock.unlock() }

                switch result {
                case .success(let device):
                    speakers.append(device)
                case .failure(let error):
                    if firstError == nil { firstError = error }
                    speakers.append(SmartDevice(
                        id: ip,
                        name: "Sonos (\(ip))",
                        kind: .speaker,
                        room: nil,
                        isOn: false,
                        brightness: nil,
                        volume: nil,
                        nowPlaying: nil,
                        isReachable: false
                    ))
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if speakers.isEmpty, let error = firstError {
                completion(.failure(error))
            } else {
                speakers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                completion(.success(speakers))
            }
        }
    }

    func setVolume(_ speakerIP: String, volume: Int, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        let clamped = max(0, min(100, volume))
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:SetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
              <InstanceID>0</InstanceID>
              <Channel>Master</Channel>
              <DesiredVolume>\(clamped)</DesiredVolume>
            </u:SetVolume>
          </s:Body>
        </s:Envelope>
        """

        performSOAP(
            ip: speakerIP,
            controlPath: "/MediaRenderer/RenderingControl/Control",
            action: "urn:schemas-upnp-org:service:RenderingControl:1#SetVolume",
            body: body
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func adjustVolume(_ speakerIP: String, by delta: Int, completion: @escaping (Result<Int, LocalHTTPError>) -> Void) {
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:SetRelativeVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
              <InstanceID>0</InstanceID>
              <Channel>Master</Channel>
              <Adjustment>\(delta)</Adjustment>
            </u:SetRelativeVolume>
          </s:Body>
        </s:Envelope>
        """

        performSOAP(
            ip: speakerIP,
            controlPath: "/MediaRenderer/RenderingControl/Control",
            action: "urn:schemas-upnp-org:service:RenderingControl:1#SetRelativeVolume",
            body: body
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let xml):
                if let volumeString = self.extractXMLValue(named: "NewVolume", from: xml),
                   let volume = Int(volumeString) {
                    completion(.success(volume))
                } else {
                    completion(.failure(.decodingFailed))
                }
            }
        }
    }

    func play(_ speakerIP: String, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        avTransportAction(
            ip: speakerIP,
            action: "urn:schemas-upnp-org:service:AVTransport:1#Play",
            body: """
            <?xml version="1.0" encoding="utf-8"?>
            <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
              <s:Body>
                <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                  <InstanceID>0</InstanceID>
                  <Speed>1</Speed>
                </u:Play>
              </s:Body>
            </s:Envelope>
            """,
            completion: completion
        )
    }

    func pause(_ speakerIP: String, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        avTransportAction(
            ip: speakerIP,
            action: "urn:schemas-upnp-org:service:AVTransport:1#Pause",
            body: """
            <?xml version="1.0" encoding="utf-8"?>
            <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
              <s:Body>
                <u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                  <InstanceID>0</InstanceID>
                </u:Pause>
              </s:Body>
            </s:Envelope>
            """,
            completion: completion
        )
    }

    func nextTrack(_ speakerIP: String, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        avTransportAction(
            ip: speakerIP,
            action: "urn:schemas-upnp-org:service:AVTransport:1#Next",
            body: """
            <?xml version="1.0" encoding="utf-8"?>
            <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
              <s:Body>
                <u:Next xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                  <InstanceID>0</InstanceID>
                </u:Next>
              </s:Body>
            </s:Envelope>
            """,
            completion: completion
        )
    }

    func previousTrack(_ speakerIP: String, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        avTransportAction(
            ip: speakerIP,
            action: "urn:schemas-upnp-org:service:AVTransport:1#Previous",
            body: """
            <?xml version="1.0" encoding="utf-8"?>
            <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
              <s:Body>
                <u:Previous xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                  <InstanceID>0</InstanceID>
                </u:Previous>
              </s:Body>
            </s:Envelope>
            """,
            completion: completion
        )
    }

    func playSpotifyPlaylist(
        on speakerIP: String,
        title: String,
        uri: String,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        guard let parsed = parseSpotifyURI(uri), parsed.kind == "playlist" else {
            DebugLog.shared.error("Spotify playlist URI not recognized: \(uri)")
            completion(.failure(.decodingFailed))
            return
        }

        attemptSpotifyPlaylistPlayback(
            on: speakerIP,
            title: title,
            parsed: parsed,
            regions: ["2311", "3079"],
            regionIndex: 0,
            completion: completion
        )
    }

    private struct ParsedSpotifyURI {
        let kind: String
        let id: String

        var spotifyURI: String { "spotify:\(kind):\(id)" }
        var encodedURI: String { spotifyURI.replacingOccurrences(of: ":", with: "%3a") }
    }

    private func attemptSpotifyPlaylistPlayback(
        on speakerIP: String,
        title: String,
        parsed: ParsedSpotifyURI,
        regions: [String],
        regionIndex: Int,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        guard regionIndex < regions.count else {
            completion(.failure(.invalidResponse))
            return
        }

        let region = regions[regionIndex]
        let request = spotifyPlaylistRequest(title: title, parsed: parsed, region: region)

        setSpotifyPlaylistTransport(on: speakerIP, request: request) { [weak self] result in
            switch result {
            case .success:
                self?.play(speakerIP, completion: completion)
            case .failure(let setError):
                self?.addSpotifyPlaylistToQueue(on: speakerIP, request: request) { queueResult in
                    switch queueResult {
                    case .success:
                        self?.play(speakerIP, completion: completion)
                    case .failure:
                        let nextRegion = regionIndex + 1
                        if nextRegion < regions.count {
                            DebugLog.shared.log("Spotify playlist retry with region \(regions[nextRegion])")
                            self?.attemptSpotifyPlaylistPlayback(
                                on: speakerIP,
                                title: title,
                                parsed: parsed,
                                regions: regions,
                                regionIndex: nextRegion,
                                completion: completion
                            )
                        } else {
                            DebugLog.shared.error("Spotify playlist failed: \(setError.localizedDescription)")
                            completion(.failure(setError))
                        }
                    }
                }
            }
        }
    }

    private struct SpotifyPlaylistRequest {
        let transportURI: String
        let queueURI: String
        let itemId: String
        let title: String
        let cdUdn: String
    }

    private func spotifyPlaylistRequest(title: String, parsed: ParsedSpotifyURI, region: String) -> SpotifyPlaylistRequest {
        let encodedURI = parsed.encodedURI
        return SpotifyPlaylistRequest(
            transportURI: "x-rincon-cpcontainer:1006206c\(encodedURI)?sid=9&flags=8300&sn=7",
            queueURI: "x-rincon-cpcontainer:1006206c\(encodedURI)",
            itemId: "1006206c\(encodedURI)",
            title: title,
            cdUdn: "SA_RINCON\(region)_X_#Svc\(region)-0-Token"
        )
    }

    private func spotifyShareMetadata(for request: SpotifyPlaylistRequest) -> String {
        let escapedTitle = xmlEscape(request.title)
        let didl = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item id="\(request.itemId)" parentID="10fe2664playlists" restricted="true"><dc:title>\(escapedTitle)</dc:title><upnp:class>object.container.playlistContainer</upnp:class><desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">\(request.cdUdn)</desc></item></DIDL-Lite>
        """
        return xmlEscape(didl)
    }

    private func setSpotifyPlaylistTransport(
        on speakerIP: String,
        request: SpotifyPlaylistRequest,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        let metadata = spotifyShareMetadata(for: request)
        let escapedURI = request.transportURI.replacingOccurrences(of: "&", with: "&amp;")
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <InstanceID>0</InstanceID>
              <CurrentURI>\(escapedURI)</CurrentURI>
              <CurrentURIMetaData>\(metadata)</CurrentURIMetaData>
            </u:SetAVTransportURI>
          </s:Body>
        </s:Envelope>
        """

        DebugLog.shared.log("Spotify SetAVTransportURI \(request.transportURI) (\(request.cdUdn))")
        avTransportAction(
            ip: speakerIP,
            action: "urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI",
            body: body,
            completion: completion
        )
    }

    private func addSpotifyPlaylistToQueue(
        on speakerIP: String,
        request: SpotifyPlaylistRequest,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        let metadata = spotifyShareMetadata(for: request)
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:AddURIToQueue xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <InstanceID>0</InstanceID>
              <EnqueuedURI>\(request.queueURI)</EnqueuedURI>
              <EnqueuedURIMetaData>\(metadata)</EnqueuedURIMetaData>
              <DesiredFirstTrackNumberEnqueued>1</DesiredFirstTrackNumberEnqueued>
              <EnqueueAsNext>false</EnqueueAsNext>
            </u:AddURIToQueue>
          </s:Body>
        </s:Envelope>
        """

        DebugLog.shared.log("Spotify AddURIToQueue \(request.queueURI) (\(request.cdUdn))")
        avTransportAction(
            ip: speakerIP,
            action: "urn:schemas-upnp-org:service:AVTransport:1#AddURIToQueue",
            body: body,
            completion: completion
        )
    }

    private func fetchSpeaker(at ip: String, completion: @escaping (Result<SmartDevice, LocalHTTPError>) -> Void) {
        let group = DispatchGroup()
        var roomName: String?
        var volume: Int?
        var playback = PlaybackStatus(isPlaying: false, nowPlaying: nil)
        var firstError: LocalHTTPError?
        let lock = NSLock()

        group.enter()
        fetchRoomName(at: ip) { result in
            lock.lock()
            defer { lock.unlock() }
            switch result {
            case .success(let name):
                roomName = name
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
            group.leave()
        }

        group.enter()
        fetchVolume(at: ip) { result in
            lock.lock()
            defer { lock.unlock() }
            switch result {
            case .success(let level):
                volume = level
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
            group.leave()
        }

        group.enter()
        fetchPlaybackStatus(at: ip) { result in
            lock.lock()
            defer { lock.unlock() }
            switch result {
            case .success(let status):
                playback = status
            case .failure(let error):
                if firstError == nil { firstError = error }
            }
            group.leave()
        }

        group.notify(queue: .main) {
            guard roomName != nil || volume != nil || playback.nowPlaying != nil else {
                completion(.failure(firstError ?? .invalidResponse))
                return
            }

            let name = roomName ?? "Sonos \(ip)"
            completion(.success(SmartDevice(
                id: ip,
                name: name,
                kind: .speaker,
                room: roomName,
                isOn: playback.isPlaying,
                brightness: nil,
                volume: volume,
                nowPlaying: playback.nowPlaying,
                isReachable: true
            )))
        }
    }

    private struct PlaybackStatus {
        let isPlaying: Bool
        let nowPlaying: String?
    }

    private func fetchRoomName(at ip: String, completion: @escaping (Result<String, LocalHTTPError>) -> Void) {
        let url = "http://\(ip):1400/xml/device_description.xml"
        client.get(urlString: url) { result in
            switch result {
            case .failure(let error):
                self.fetchRoomNameFromInfo(at: ip, fallbackError: error, completion: completion)
            case .success(let data):
                guard let xml = String(data: data, encoding: .utf8) else {
                    self.fetchRoomNameFromInfo(at: ip, fallbackError: .decodingFailed, completion: completion)
                    return
                }

                if let room = self.extractXMLValue(named: "roomName", from: xml), !room.isEmpty {
                    completion(.success(room))
                    return
                }

                if let friendly = self.extractXMLValue(named: "friendlyName", from: xml), !friendly.isEmpty {
                    completion(.success(friendly))
                    return
                }

                self.fetchRoomNameFromInfo(at: ip, fallbackError: .decodingFailed, completion: completion)
            }
        }
    }

    private func fetchRoomNameFromInfo(
        at ip: String,
        fallbackError: LocalHTTPError,
        completion: @escaping (Result<String, LocalHTTPError>) -> Void
    ) {
        let url = "http://\(ip):1400/status/info"
        client.get(urlString: url) { result in
            switch result {
            case .failure:
                completion(.failure(fallbackError))
            case .success(let data):
                guard
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let roomName = json["roomName"] as? String,
                    !roomName.isEmpty
                else {
                    completion(.failure(fallbackError))
                    return
                }
                completion(.success(roomName))
            }
        }
    }

    private func fetchVolume(at ip: String, completion: @escaping (Result<Int, LocalHTTPError>) -> Void) {
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:GetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
              <InstanceID>0</InstanceID>
              <Channel>Master</Channel>
            </u:GetVolume>
          </s:Body>
        </s:Envelope>
        """

        performSOAP(
            ip: ip,
            controlPath: "/MediaRenderer/RenderingControl/Control",
            action: "urn:schemas-upnp-org:service:RenderingControl:1#GetVolume",
            body: body
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let xml):
                if let volumeString = self.extractXMLValue(named: "CurrentVolume", from: xml),
                   let volume = Int(volumeString) {
                    completion(.success(volume))
                } else {
                    completion(.failure(.decodingFailed))
                }
            }
        }
    }

    private func fetchPlaybackStatus(at ip: String, completion: @escaping (Result<PlaybackStatus, LocalHTTPError>) -> Void) {
        let url = "http://\(ip):1400/status/player"
        client.get(urlString: url) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let data):
                guard let xml = String(data: data, encoding: .utf8) else {
                    completion(.failure(.decodingFailed))
                    return
                }

                let isPlaying = xml.contains("<state>PLAYING</state>")
                    || xml.contains("<transportState>PLAYING</transportState>")
                let title = self.extractXMLValue(named: "title", from: xml)
                let artist = self.extractXMLValue(named: "artist", from: xml)
                let nowPlaying = self.nowPlayingText(title: title, artist: artist, isPlaying: isPlaying)
                completion(.success(PlaybackStatus(isPlaying: isPlaying, nowPlaying: nowPlaying)))
            }
        }
    }

    private func nowPlayingText(title: String?, artist: String?, isPlaying: Bool) -> String? {
        if let title = title, !title.isEmpty {
            if let artist = artist, !artist.isEmpty {
                return "\(title) · \(artist)"
            }
            return title
        }
        return isPlaying ? "Playing" : "Nothing playing"
    }

    private func avTransportAction(
        ip: String,
        action: String,
        body: String,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        performSOAP(
            ip: ip,
            controlPath: "/MediaRenderer/AVTransport/Control",
            action: action,
            body: body
        ) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func parseSpotifyURI(_ input: String) -> ParsedSpotifyURI? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("spotify:") {
            let withoutQuery = trimmed.split(separator: "?").first.map(String.init) ?? trimmed
            let parts = withoutQuery.split(separator: ":").map(String.init)
            guard parts.count == 3, parts[0] == "spotify", !parts[2].isEmpty else { return nil }
            return ParsedSpotifyURI(kind: parts[1], id: parts[2])
        }

        if let url = URL(string: trimmed), let host = url.host, host.contains("spotify") {
            let parts = url.pathComponents.filter { $0 != "/" }
            if parts.count >= 2 {
                return ParsedSpotifyURI(kind: parts[0], id: parts[1])
            }
        }

        return nil
    }

    private func xmlEscape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func performSOAP(
        ip: String,
        controlPath: String,
        action: String,
        body: String,
        completion: @escaping (Result<String, LocalHTTPError>) -> Void
    ) {
        guard let url = URL(string: "http://\(ip):1400\(controlPath)") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(action, forHTTPHeaderField: "SOAPACTION")
        request.httpBody = body.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.transport(error)))
                return
            }

            guard let data = data, let xml = String(data: data, encoding: .utf8) else {
                completion(.failure(.decodingFailed))
                return
            }

            if let fault = self.extractXMLValue(named: "faultstring", from: xml) {
                DebugLog.shared.error("Sonos SOAP fault: \(fault)")
                completion(.failure(.transport(NSError(domain: "SonosSOAP", code: 1, userInfo: [NSLocalizedDescriptionKey: fault]))))
                return
            }

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                DebugLog.shared.error("Sonos SOAP HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                completion(.failure(.invalidResponse))
                return
            }

            completion(.success(xml))
        }
        task.resume()
    }

    private func extractXMLValue(named tag: String, from xml: String) -> String? {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
            let match = regex.firstMatch(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml)),
            let range = Range(match.range(at: 1), in: xml)
        else {
            return nil
        }

        let value = String(xml[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
