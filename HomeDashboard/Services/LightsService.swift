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
        guard let url = hueURL(bridgeIP: clean.hueBridgeIP, username: clean.hueUsername, path: "lights") else {
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

    func fetchGroups(completion: @escaping (Result<[SmartDevice], LocalHTTPError>) -> Void) {
        let clean = config.sanitized()
        guard let url = hueURL(bridgeIP: clean.hueBridgeIP, username: clean.hueUsername, path: "groups") else {
            completion(.failure(.invalidURL))
            return
        }

        client.get(urlString: url.absoluteString) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let data):
                completion(self.parseGroups(from: data))
            }
        }
    }

    func buildCustomGroups(from lights: [SmartDevice]) -> [SmartDevice] {
        let clean = config.sanitized()
        var groups: [SmartDevice] = []

        for (index, group) in clean.customLightGroups.enumerated() {
            let members = lights.filter { light in
                group.lightNames.contains { $0.caseInsensitiveCompare(light.name) == .orderedSame }
            }
            guard !members.isEmpty else { continue }

            let anyOn = members.contains { $0.isOn }
            let reachable = members.contains { $0.isReachable }
            let brightness = members.compactMap { $0.brightness }.max()

            groups.append(SmartDevice(
                id: "custom-\(index)",
                name: group.name,
                kind: .lightGroup,
                room: "\(members.count) lights",
                isOn: anyOn,
                brightness: brightness,
                volume: nil,
                isReachable: reachable
            ))
        }

        return groups
    }

    func setLightOn(_ lightID: String, isOn: Bool, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        setState(path: "lights/\(lightID)/state", body: ["on": isOn], completion: completion)
    }

    func setBrightness(_ lightID: String, brightness: Int, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        let clamped = max(0, min(254, brightness))
        setState(path: "lights/\(lightID)/state", body: ["on": true, "bri": clamped], completion: completion)
    }

    func setGroupOn(_ groupID: String, isOn: Bool, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        setState(path: "groups/\(groupID)/action", body: ["on": isOn], completion: completion)
    }

    func setGroupBrightness(_ groupID: String, brightness: Int, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        let clamped = max(0, min(254, brightness))
        setState(path: "groups/\(groupID)/action", body: ["on": true, "bri": clamped], completion: completion)
    }

    func setCustomGroupOn(index: Int, lights: [SmartDevice], isOn: Bool, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        applyToCustomGroup(index: index, lights: lights, isOn: isOn, brightness: nil, completion: completion)
    }

    func setCustomGroupBrightness(index: Int, lights: [SmartDevice], brightness: Int, completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        applyToCustomGroup(index: index, lights: lights, isOn: true, brightness: brightness, completion: completion)
    }

    private func applyToCustomGroup(
        index: Int,
        lights: [SmartDevice],
        isOn: Bool,
        brightness: Int?,
        completion: @escaping (Result<Void, LocalHTTPError>) -> Void
    ) {
        let clean = config.sanitized()
        guard index < clean.customLightGroups.count else {
            completion(.failure(.decodingFailed))
            return
        }

        let group = clean.customLightGroups[index]
        let members = lights.filter { light in
            group.lightNames.contains { $0.caseInsensitiveCompare(light.name) == .orderedSame }
        }

        guard !members.isEmpty else {
            completion(.failure(.decodingFailed))
            return
        }

        let group = DispatchGroup()
        var lastError: LocalHTTPError?
        let lock = NSLock()

        for member in members {
            group.enter()
            if let brightness = brightness {
                setBrightness(member.id, brightness: brightness) { result in
                    lock.lock()
                    if case .failure(let error) = result { lastError = error }
                    lock.unlock()
                    group.leave()
                }
            } else {
                setLightOn(member.id, isOn: isOn) { result in
                    lock.lock()
                    if case .failure(let error) = result { lastError = error }
                    lock.unlock()
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            if let error = lastError {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    private func setState(path: String, body: [String: Any], completion: @escaping (Result<Void, LocalHTTPError>) -> Void) {
        let clean = config.sanitized()
        guard let url = hueURL(bridgeIP: clean.hueBridgeIP, username: clean.hueUsername, path: path) else {
            completion(.failure(.invalidURL))
            return
        }
        client.post(urlString: url.absoluteString, body: body, completion: completion)
    }

    private func hueURL(bridgeIP: String, username: String, path: String) -> URL? {
        URL(string: "http://\(bridgeIP)/api/\(username)/\(path)")
    }

    private func parseLights(from data: Data) -> Result<[SmartDevice], LocalHTTPError> {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return .failure(.decodingFailed)
        }

        if let error = hueError(from: json) {
            return .failure(error)
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

    private func parseGroups(from data: Data) -> Result<[SmartDevice], LocalHTTPError> {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return .failure(.decodingFailed)
        }

        if let error = hueError(from: json) {
            return .failure(error)
        }

        guard let dictionary = json as? [String: Any] else {
            return .failure(.decodingFailed)
        }

        var devices: [SmartDevice] = []

        for (id, value) in dictionary {
            guard id != "0", let group = value as? [String: Any] else { continue }

            let lights = group["lights"] as? [String] ?? []
            guard !lights.isEmpty else { continue }

            let action = group["action"] as? [String: Any]
            let state = group["state"] as? [String: Any]
            let isOn = action?["on"] as? Bool ?? state?["any_on"] as? Bool ?? false
            let brightness = action?["bri"] as? Int
            let name = group["name"] as? String ?? "Group \(id)"
            let type = group["type"] as? String ?? "Group"

            devices.append(SmartDevice(
                id: "group-\(id)",
                name: name,
                kind: .lightGroup,
                room: "\(lights.count) lights · \(type)",
                isOn: isOn,
                brightness: brightness,
                volume: nil,
                isReachable: true
            ))
        }

        devices.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return .success(devices)
    }

    private func hueError(from json: Any) -> LocalHTTPError? {
        guard
            let errors = json as? [[String: Any]],
            let first = errors.first,
            let error = first["error"] as? [String: Any],
            let description = error["description"] as? String
        else {
            return nil
        }

        return .transport(NSError(
            domain: "HueBridge",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: description]
        ))
    }
}
