import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.isTranslucent = false
        tabBar.barTintColor = DashboardTheme.sidebar
        tabBar.tintColor = DashboardTheme.accent
        tabBar.unselectedItemTintColor = UIColor(white: 0.55, alpha: 1.0)

        let lights = LightsViewController()
        lights.tabBarItem = UITabBarItem(title: "Rooms", image: tabIcon(systemName: "lightbulb", fallback: "L"), tag: 0)

        let dashboard = DashboardViewController()
        dashboard.tabBarItem = UITabBarItem(title: "Home", image: tabIcon(systemName: "house", fallback: "H"), tag: 1)

        let sonos = SonosViewController()
        sonos.tabBarItem = UITabBarItem(title: "Sonos", image: tabIcon(systemName: "speaker.wave.2", fallback: "S"), tag: 2)

        let settings = SettingsViewController()
        settings.tabBarItem = UITabBarItem(title: "Settings", image: tabIcon(systemName: "gearshape", fallback: "⚙"), tag: 3)

        viewControllers = [
            UINavigationController(rootViewController: lights),
            UINavigationController(rootViewController: dashboard),
            UINavigationController(rootViewController: sonos),
            UINavigationController(rootViewController: settings)
        ]
        selectedIndex = 0
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    /// SF Symbols require iOS 13+. On iOS 12, render a simple text badge so tabs stay visible.
    private func tabIcon(systemName: String, fallback: String) -> UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: systemName)
        }
        return textTabIcon(fallback)
    }

    private func textTabIcon(_ text: String) -> UIImage? {
        let size = CGSize(width: 28, height: 28)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        let font = UIFont.systemFont(ofSize: text.count == 1 ? 18 : 16, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let origin = CGPoint(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2
        )
        (text as NSString).draw(at: origin, withAttributes: attributes)

        return UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(.alwaysTemplate)
    }
}
