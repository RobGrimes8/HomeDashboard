import Foundation

/// Local-only configuration. Edit `Config.json` in the app bundle or use Settings screen.
/// All communication stays on your home network — no cloud services.
struct AppConfig: Codable {
    var hueBridgeIP: String
    var hueUsername: String
    var sonosSpeakerIPs: [String]
    var refreshIntervalSeconds: TimeInterval
    var requestTimeoutSeconds: TimeInterval

    static let `default` = AppConfig(
        hueBridgeIP: "192.168.1.100",
        hueUsername: "YOUR_HUE_API_USERNAME",
        sonosSpeakerIPs: ["192.168.1.101", "192.168.1.102"],
        refreshIntervalSeconds: 15,
        requestTimeoutSeconds: 8
    )

    static func load() -> AppConfig {
        if let saved = loadFromDocuments() {
            return saved
        }

        guard
            let url = Bundle.main.url(forResource: "Config", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let config = try? JSONDecoder().decode(AppConfig.self, from: data)
        else {
            return .default
        }
        return config
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
        guard
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            let data = try? JSONEncoder().encode(self)
        else {
            return false
        }

        let url = documents.appendingPathComponent("Config.json")
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
