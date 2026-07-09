import UIKit

enum DashboardTheme {
    static let background = UIColor(red: 0.11, green: 0.13, blue: 0.16, alpha: 1.0)
    static let sidebar = UIColor(red: 0.07, green: 0.09, blue: 0.12, alpha: 1.0)
    static let cardBottom = UIColor(red: 0.93, green: 0.95, blue: 0.96, alpha: 1.0)
    static let cardTitle = UIColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1.0)
    static let cardSubtitle = UIColor(red: 0.45, green: 0.50, blue: 0.55, alpha: 1.0)
    static let accent = UIColor(red: 0.18, green: 0.74, blue: 0.82, alpha: 1.0)
    static let accentDark = UIColor(red: 0.10, green: 0.52, blue: 0.62, alpha: 1.0)
    static let onButton = UIColor(red: 0.20, green: 0.78, blue: 0.72, alpha: 1.0)
    static let offButton = UIColor(red: 0.78, green: 0.82, blue: 0.86, alpha: 1.0)
    static let navBar = UIColor(red: 0.08, green: 0.10, blue: 0.13, alpha: 1.0)

    static func applyGradient(to view: UIView) {
        view.layer.sublayers?.filter { $0.name == "cardGradient" }.forEach { $0.removeFromSuperlayer() }

        let gradient = CAGradientLayer()
        gradient.name = "cardGradient"
        gradient.colors = [
            accent.cgColor,
            accentDark.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.frame = view.bounds
        gradient.cornerRadius = view.layer.cornerRadius
        view.layer.insertSublayer(gradient, at: 0)
    }

    static func roomIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("office") || lower.contains("desk") { return "💼" }
        if lower.contains("living") || lower.contains("lounge") { return "🛋" }
        if lower.contains("bed") { return "🛏" }
        if lower.contains("bath") || lower.contains("toilet") { return "🛁" }
        if lower.contains("kitchen") { return "🍳" }
        if lower.contains("garden") || lower.contains("outside") { return "🌿" }
        if lower.contains("tv") || lower.contains("entertainment") { return "📺" }
        if lower.contains("door") || lower.contains("front") { return "🚪" }
        return "💡"
    }
}
