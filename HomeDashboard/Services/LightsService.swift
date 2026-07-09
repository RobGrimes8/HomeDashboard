import Foundation

/// Philips Hue local REST API (v1).
/// Docs: https://developers.meethue.com/develop/hue-api/
final class LightsService {

    private let client: LocalHTTPClient
    private var config: AppConfig

    init(client: LocalHTTPClient, config: AppConfig) {
        self.client = client
        self.config = config
    }

    func updateConfig(_ config: AppConfig) {
        self.config = config
    }

    func fetchLights(completion: @escaping (Result<[SmartDevice], LocalHTTPError>) -> Void) {
        let clean = config.sanitized()
        guard let url = hueLightsURL(bridgeIP: clean.hueBridgeIP, username: clean.hueUsername) else {
            completion(.failure(.invalidURL))
            return
        }

        client.get(urlString: url.absoluteString) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let data):
                completion(self.parseLights(from: data))
            }
        }
    }

    func setLightOn(_ lightID: String, isOn: Bool, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        let clean = config.sanitized()
        guard let url = hueLightStateURL(bridgeIP: clean.hueBridgeIP, username: clean.hueUsername, lightID: lightID) else {
            completion(.failure(.invalidURL))
            return
        }
        client.put(urlString: url.absoluteString, body: ["on": isOn], completion: completion)
    }

    func setBrightness(_ lightID: String, brightness: Int, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        let clean = config.sanitized()
        guard let url = hueLightStateURL(bridgeIP: clean.hueBridgeIP, username: clean.hueUsername, lightID: lightID) else {
            completion(.failure(.invalidURL))
            return
        }
        let clamped = max(0, min(254, brightness))
        client.put(urlString: url.absoluteString, body: ["on": true, "bri": clamped], completion: completion)
    }

    private func hueLightsURL(bridgeIP: String, username: String) -> URL? {
        URL(string: "http://\(bridgeIP)/api/\(username)/lights")
    }

    private func hueLightStateURL(bridgeIP: String, username: String, lightID: String) -> URL? {
        URL(string: "http://\(bridgeIP)/api/\(username)/lights/\(lightID)/state")
    }

    private func parseLights(from data: Data) -> Result<[SmartDevice], LocalHTTPError> {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return .failure(.decodingFailed)
        }

        if let errors = json as? [[String: Any]],
           let first = errors.first,
           let error = first["error"] as? [String: Any],
           let description = error["description"] as? String {
            return .failure(.transport(NSError(
                domain: "HueBridge",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: description]
            )))
        }

        guard let dictionary = json as? [String: Any] else {
            return .failure(.decodingFailed)
        }

        var devices: [SmartDevice] = []

        for (id, value) in dictionary {
            guard let light = value as? [String: Any] else { continue }

            let state = light["state"] as? [String: Any]
            let isOn = state?["on"] as? Bool ?? false
            let reachable = state?["reachable"] as? Bool ?? true
            let brightness = state?["bri"] as? Int
            let name = light["name"] as? String ?? "Light \(id)"

            devices.append(SmartDevice(
                id: id,
                name: name,
                kind: .light,
                room: nil,
                isOn: isOn,
                brightness: brightness,
                volume: nil,
                isReachable: reachable
            ))
        }

        devices.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return .success(devices)
    }
}
