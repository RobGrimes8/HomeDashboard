import Foundation

/// Sonos local HTTP API (port 1400).
/// Uses the device status endpoint — no cloud account required.
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

        guard let url = URL(string: "http://\(speakerIP):1400/MediaRenderer/RenderingControl/Control") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("urn:schemas-upnp-org:service:RenderingControl:1#SetVolume", forHTTPHeaderField: "SOAPACTION")
        request.httpBody = body.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(.transport(error)))
                return
            }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                completion(.failure(.invalidResponse))
                return
            }
            completion(.success(()))
        }
        task.resume()
    }

    private func fetchSpeaker(at ip: String, completion: @escaping (Result<SmartDevice, LocalHTTPError>) -> Void) {
        let url = "http://\(ip):1400/status/player"
        client.get(urlString: url) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let data):
                completion(self.parsePlayerStatus(data: data, ip: ip))
            }
        }
    }

    private func parsePlayerStatus(data: Data, ip: String) -> Result<SmartDevice, LocalHTTPError> {
        guard let xml = String(data: data, encoding: .utf8) else {
            return .failure(.decodingFailed)
        }

        let name = extractXMLValue(named: "title", from: xml)
            ?? extractXMLValue(named: "roomName", from: xml)
            ?? "Sonos \(ip)"

        let volumeString = extractXMLValue(named: "volume", from: xml)
        let volume = volumeString.flatMap { Int($0) }

        let isPlaying = xml.contains("<state>PLAYING</state>") || xml.contains("<transportState>PLAYING</transportState>")

        return .success(SmartDevice(
            id: ip,
            name: name,
            kind: .speaker,
            room: extractXMLValue(named: "roomName", from: xml),
            isOn: isPlaying,
            brightness: nil,
            volume: volume,
            isReachable: true
        ))
    }

    private func extractXMLValue(named tag: String, from xml: String) -> String? {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: []),
            let match = regex.firstMatch(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml)),
            let range = Range(match.range(at: 1), in: xml)
        else {
            return nil
        }
        return String(xml[range])
    }
}
