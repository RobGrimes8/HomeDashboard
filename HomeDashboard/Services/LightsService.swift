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
        let url = "http://\(config.hueBridgeIP)/api/\(config.hueUsername)/lights"
        client.get(urlString: url) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let data):
                completion(self.parseLights(from: data))
            }
        }
    }

    func setLightOn(_ lightID: String, isOn: Bool, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        let url = "http://\(config.hueBridgeIP)/api/\(config.hueUsername)/lights/\(lightID)/state"
        client.put(urlString: url, body: ["on": isOn], completion: completion)
    }

    func setBrightness(_ lightID: String, brightness: Int, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        let url = "http://\(config.hueBridgeIP)/api/\(config.hueUsername)/lights/\(lightID)/state"
        let clamped = max(0, min(254, brightness))
        client.put(urlString: url, body: ["on": true, "bri": clamped], completion: completion)
    }

    private func parseLights(from data: Data) -> Result<[SmartDevice], LocalHTTPError> {
        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let dictionary = json as? [String: Any]
        else {
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
