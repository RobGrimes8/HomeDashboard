import Foundation

/// Local-only configuration. Edit `Config.json` in the app bundle or use Settings screen.
/// All communication stays on your home network — no cloud services.
struct AppConfig: Codable {
    var hueBridgeIP: String
    var hueUsername: String
    var sonosSpeakerIPs: [String]
    var refreshIntervalSeconds: TimeInterval
    var requestTimeoutSeconds: TimeInterval
    var customLightGroups: [CustomLightGroup]

    struct CustomLightGroup: Codable, Equatable {
        var name: String
        var lightNames: [String]
    }

    static let `default` = AppConfig(
        hueBridgeIP: "192.168.1.100",
        hueUsername: "YOUR_HUE_API_USERNAME",
        sonosSpeakerIPs: ["192.168.1.101", "192.168.1.102"],
        refreshIntervalSeconds: 15,
        requestTimeoutSeconds: 8,
        customLightGroups: []
    )

    var isHueConfigured: Bool {
        let ip = hueBridgeIP.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = hueUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return !ip.isEmpty && !user.isEmpty && user != "YOUR_HUE_API_USERNAME"
    }

    static func customGroupsText(from groups: [CustomLightGroup]) -> String {
        return groups.map { group in
            "\(group.name)=\(group.lightNames.joined(separator: ", "))"
        }.joined(separator: "\n")
    }

    static func parseCustomGroupsText(_ text: String) -> [CustomLightGroup] {
        return text
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return nil }

                let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let lightNames = parts[1]
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                guard !name.isEmpty, !lightNames.isEmpty else { return nil }
                return CustomLightGroup(name: name, lightNames: lightNames)
            }
    }

    func sanitized() -> AppConfig {
        AppConfig(
            hueBridgeIP: hueBridgeIP.trimmingCharacters(in: .whitespacesAndNewlines),
            hueUsername: hueUsername.trimmingCharacters(in: .whitespacesAndNewlines),
            sonosSpeakerIPs: sonosSpeakerIPs
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            refreshIntervalSeconds: refreshIntervalSeconds,
            requestTimeoutSeconds: requestTimeoutSeconds,
            customLightGroups: customLightGroups
                .map {
                    CustomLightGroup(
                        name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        lightNames: $0.lightNames
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    )
                }
                .filter { !$0.name.isEmpty && !$0.lightNames.isEmpty }
        )
    }

    static func load() -> AppConfig {
        if let saved = loadFromDocuments() {
            return saved.sanitized()
        }

        guard
            let url = Bundle.main.url(forResource: "Config", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let config = try? JSONDecoder().decode(AppConfig.self, from: data)
        else {
            return .default
        }
        return config.sanitized()
    }

    static func loadFromDocuments() -> AppConfig? {
        guard
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            return nil
        }

        let url = documents.appendingPathComponent("Config.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppConfig.self, from: data)
    }

    func saveToDocuments() -> Bool {
        let clean = sanitized()
        guard
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            let data = try? JSONEncoder().encode(clean)
        else {
            return false
        }

        let url = documents.appendingPathComponent("Config.json")
        do {
            try data.write(to: url, options: .atomic)
            DebugLog.shared.log("Config saved to Documents (Hue …\(clean.hueUsername.suffix(4)), \(clean.customLightGroups.count) custom groups)")
            NotificationCenter.default.post(name: .appConfigDidChange, object: nil)
            return true
        } catch {
            return false
        }
    }
}

extension Notification.Name {
    static let appConfigDidChange = Notification.Name("AppConfigDidChange")
}
