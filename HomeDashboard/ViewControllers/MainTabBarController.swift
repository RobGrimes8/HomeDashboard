import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.isTranslucent = false
        tabBar.barTintColor = UIColor(white: 0.08, alpha: 1.0)
        tabBar.tintColor = UIColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1.0)
        tabBar.unselectedItemTintColor = UIColor(white: 0.55, alpha: 1.0)

        let dashboard = DashboardViewController()
        dashboard.tabBarItem = UITabBarItem(title: "Home", image: tabIcon(systemName: "house", fallback: "H"), tag: 0)

        let lights = LightsViewController()
        lights.tabBarItem = UITabBarItem(title: "Lights", image: tabIcon(systemName: "lightbulb", fallback: "L"), tag: 1)

        let sonos = SonosViewController()
        sonos.tabBarItem = UITabBarItem(title: "Sonos", image: tabIcon(systemName: "speaker.wave.2", fallback: "S"), tag: 2)

        let settings = SettingsViewController()
        settings.tabBarItem = UITabBarItem(title: "Settings", image: tabIcon(systemName: "gearshape", fallback: "⚙"), tag: 3)

        viewControllers = [
            UINavigationController(rootViewController: dashboard),
            UINavigationController(rootViewController: lights),
            UINavigationController(rootViewController: sonos),
            UINavigationController(rootViewController: settings)
        ]
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
