import Foundation

extension Notification.Name {
    static let debugLogDidChange = Notification.Name("DebugLogDidChange")
}

/// On-device debug log for development on iPad without Xcode debugger attached.
final class DebugLog {

    static let shared = DebugLog()

    private let maxEntries = 150
    private var entries: [String] = []
    private let lock = NSLock()
    private let enabledKey = "HomeDashboard.debugLogEnabled"

    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if newValue {
                log("Debug logging enabled")
            }
        }
    }

    private init() {}

    func log(_ message: String) {
        guard isEnabled else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(message)"

        lock.lock()
        entries.append(line)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        lock.unlock()

        NotificationCenter.default.post(name: .debugLogDidChange, object: nil)
    }

    func error(_ message: String) {
        log("ERROR \(message)")
    }

    func http(_ method: String, url: String, detail: String) {
        log("HTTP \(method) \(sanitize(url)) · \(detail)")
    }

    func allEntries() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
        NotificationCenter.default.post(name: .debugLogDidChange, object: nil)
    }

    private func sanitize(_ url: String) -> String {
        guard let range = url.range(of: "/api/") else { return url }
        let tail = url[range.upperBound...]
        guard let slash = tail.firstIndex(of: "/") else { return url }
        let suffix = tail[slash...]
        let prefix = url[..<range.upperBound]
        return "\(prefix)...\(suffix)"
    }
}
