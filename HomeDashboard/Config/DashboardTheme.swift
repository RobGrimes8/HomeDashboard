import UIKit

enum DashboardTheme {
    // Midnight Glass palette
    static let backgroundTop = UIColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0)
    static let backgroundMid = UIColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1.0)
    static let backgroundBottom = UIColor(red: 0.12, green: 0.14, blue: 0.24, alpha: 1.0)
    static let background = backgroundMid

    static let glassFill = UIColor(white: 1.0, alpha: 0.06)
    static let glassBorder = UIColor(white: 1.0, alpha: 0.14)
    static let glassPurple = UIColor(red: 0.32, green: 0.22, blue: 0.52, alpha: 0.38)
    static let glassBlue = UIColor(red: 0.18, green: 0.32, blue: 0.58, alpha: 0.38)
    static let glassTeal = UIColor(red: 0.14, green: 0.42, blue: 0.48, alpha: 0.38)
    static let glassAmber = UIColor(red: 0.52, green: 0.34, blue: 0.14, alpha: 0.38)

    static let textPrimary = UIColor.white
    static let textSecondary = UIColor(white: 0.62, alpha: 1.0)
    static let accent = UIColor(red: 0.42, green: 0.62, blue: 0.96, alpha: 1.0)
    static let onGlow = UIColor(red: 0.50, green: 0.78, blue: 1.0, alpha: 1.0)
    static let offMuted = UIColor(white: 0.38, alpha: 1.0)

    // Legacy aliases used by older styling paths
    static let sidebar = UIColor(white: 0.06, alpha: 0.85)
    static let navBar = UIColor.clear
    static let cardTitle = textPrimary
    static let cardSubtitle = textSecondary
    static let cardBottom = glassFill
    static let onButton = accent
    static let offButton = UIColor(white: 0.28, alpha: 0.9)
    static let accentDark = UIColor(red: 0.22, green: 0.38, blue: 0.72, alpha: 1.0)

    static func installBackground(in view: UIView) {
        view.subviews.filter { $0.tag == 9001 }.forEach { $0.removeFromSuperview() }

        let background = GradientBackgroundView()
        background.tag = 9001
        background.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(background, at: 0)

        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: view.topAnchor),
            background.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            background.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    static func styleNavigationBar(_ navigationBar: UINavigationBar?) {
        guard let bar = navigationBar else { return }
        bar.setBackgroundImage(UIImage(), for: .default)
        bar.shadowImage = UIImage()
        bar.isTranslucent = true
        bar.barStyle = .black
        bar.tintColor = accent
        bar.titleTextAttributes = [.foregroundColor: textPrimary]
    }

    static func makePillButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        button.setTitleColor(textPrimary, for: .normal)
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.10)
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = glassBorder.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        return button
    }

    static func roomTint(for name: String) -> UIColor {
        let lower = name.lowercased()
        if lower.contains("kitchen") || lower.contains("garden") { return glassTeal }
        if lower.contains("bed") || lower.contains("living") || lower.contains("lounge") { return glassPurple }
        if lower.contains("office") || lower.contains("bath") { return glassBlue }
        if lower.contains("entrance") || lower.contains("door") || lower.contains("hall") { return glassAmber }
        return glassPurple
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
        if lower.contains("door") || lower.contains("front") || lower.contains("entrance") { return "🚪" }
        return "💡"
    }
}

/// Midnight gradient background with soft accent orbs (GlassHome-style).
final class GradientBackgroundView: UIView {

    private let gradientLayer = CAGradientLayer()
    private let orbLayers: [CALayer] = (0..<3).map { _ in CALayer() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        gradientLayer.colors = [
            DashboardTheme.backgroundTop.cgColor,
            DashboardTheme.backgroundMid.cgColor,
            DashboardTheme.backgroundBottom.cgColor
        ]
        gradientLayer.locations = [0, 0.45, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradientLayer)

        let orbColors: [UIColor] = [
            UIColor(red: 0.25, green: 0.35, blue: 0.75, alpha: 0.22),
            UIColor(red: 0.55, green: 0.28, blue: 0.65, alpha: 0.18),
            UIColor(red: 0.20, green: 0.55, blue: 0.70, alpha: 0.14)
        ]
        for (index, orb) in orbLayers.enumerated() {
            orb.backgroundColor = orbColors[index].cgColor
            layer.addSublayer(orb)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds

        let sizes: [CGFloat] = [240, 200, 180]
        let centers: [CGPoint] = [
            CGPoint(x: bounds.width * 0.82, y: bounds.height * 0.18),
            CGPoint(x: bounds.width * 0.12, y: bounds.height * 0.72),
            CGPoint(x: bounds.width * 0.55, y: bounds.height * 0.88)
        ]
        for (index, orb) in orbLayers.enumerated() {
            let size = sizes[index]
            orb.frame = CGRect(
                x: centers[index].x - size / 2,
                y: centers[index].y - size / 2,
                width: size,
                height: size
            )
            orb.cornerRadius = size / 2
        }
    }
}
