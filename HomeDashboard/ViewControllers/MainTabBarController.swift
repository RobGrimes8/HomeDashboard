import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.isTranslucent = false
        tabBar.barTintColor = UIColor(white: 0.08, alpha: 1.0)
        tabBar.tintColor = UIColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1.0)
        tabBar.unselectedItemTintColor = UIColor(white: 0.55, alpha: 1.0)

        let dashboard = DashboardViewController()
        dashboard.tabBarItem = UITabBarItem(title: "Home", image: tabIcon(systemName: "house"), tag: 0)

        let lights = LightsViewController()
        lights.tabBarItem = UITabBarItem(title: "Lights", image: tabIcon(systemName: "lightbulb"), tag: 1)

        let sonos = SonosViewController()
        sonos.tabBarItem = UITabBarItem(title: "Sonos", image: tabIcon(systemName: "speaker.wave.2"), tag: 2)

        let settings = SettingsViewController()
        settings.tabBarItem = UITabBarItem(title: "Settings", image: tabIcon(systemName: "gearshape"), tag: 3)

        viewControllers = [
            UINavigationController(rootViewController: dashboard),
            UINavigationController(rootViewController: lights),
            UINavigationController(rootViewController: sonos),
            UINavigationController(rootViewController: settings)
        ]
    }

    /// SF Symbols require iOS 13+. Fall back to text labels on iOS 12.
    private func tabIcon(systemName: String) -> UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: systemName)
        }
        return nil
    }
}
