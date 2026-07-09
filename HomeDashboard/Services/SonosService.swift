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
        guard let spotifyURI = normalizeSpotifyURI(uri) else {
            completion(.failure(.decodingFailed))
            return
        }

        guard let transportURI = spotifyTransportURI(from: spotifyURI) else {
            completion(.failure(.decodingFailed))
            return
        }

        let metadata = spotifyPlaylistMetadata(title: title, spotifyURI: spotifyURI, transportURI: transportURI)
        let escapedURI = transportURI.replacingOccurrences(of: "&", with: "&amp;")
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

        avTransportAction(
            ip: speakerIP,
            action: "urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI",
            body: body
        ) { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self?.play(speakerIP, completion: completion)
            }
        }
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

    private func normalizeSpotifyURI(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("spotify:") {
            return trimmed
        }

        if let url = URL(string: trimmed), let host = url.host, host.contains("spotify") {
            let parts = url.pathComponents.filter { $0 != "/" }
            if parts.count >= 2, parts[0] == "playlist" {
                return "spotify:playlist:\(parts[1])"
            }
        }

        return nil
    }

    private func spotifyTransportURI(from spotifyURI: String) -> String? {
        let encoded = spotifyURI.replacingOccurrences(of: ":", with: "%3a")
        return "x-sonos-spotify:\(encoded)?sid=9&flags=8224&sn=7"
    }

    private func spotifyPlaylistMetadata(title: String, spotifyURI: String, transportURI: String) -> String {
        let encodedURI = spotifyURI.replacingOccurrences(of: ":", with: "%3a")
        let itemId = "00052024\(encodedURI)"
        let escapedTitle = xmlEscape(title)
        let didl = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item id="\(itemId)" parentID="" restricted="true"><dc:title>\(escapedTitle)</dc:title><upnp:class>object.container.playlistContainer</upnp:class><r:contentService><r:containerType>playlist</r:containerType></r:contentService></item></DIDL-Lite>
        """
        return xmlEscape(didl)
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

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                completion(.failure(.invalidResponse))
                return
            }

            guard let data = data, let xml = String(data: data, encoding: .utf8) else {
                completion(.failure(.decodingFailed))
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
