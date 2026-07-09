import UIKit

final class MainTabBarController: UITabBarController {

    private var tabBarBlur: UIVisualEffectView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        DashboardTheme.installBackground(in: view)

        configureGlassTabBar()

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

        viewControllers?.forEach { controller in
            if let nav = controller as? UINavigationController {
                DashboardTheme.styleNavigationBar(nav.navigationBar)
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutFloatingTabBar()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    private func configureGlassTabBar() {
        tabBar.isTranslucent = true
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
        tabBar.tintColor = DashboardTheme.accent
        tabBar.unselectedItemTintColor = DashboardTheme.textSecondary
        tabBar.barTintColor = .clear
        tabBar.layer.cornerRadius = 22
        tabBar.layer.masksToBounds = true
        tabBar.layer.borderWidth = 1
        tabBar.layer.borderColor = DashboardTheme.glassBorder.cgColor

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blur.frame = tabBar.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blur.isUserInteractionEnabled = false
        tabBar.insertSubview(blur, at: 0)
        tabBarBlur = blur
    }

    private func layoutFloatingTabBar() {
        let height = tabBar.frame.height
        let width = min(view.bounds.width - 96, 480)
        tabBar.frame = CGRect(
            x: (view.bounds.width - width) / 2,
            y: view.bounds.height - height - 10,
            width: width,
            height: height
        )
        tabBarBlur?.frame = tabBar.bounds

        let bottomInset = view.bounds.height - tabBar.frame.minY + 4
        viewControllers?.forEach { controller in
            controller.additionalSafeAreaInsets.bottom = max(0, bottomInset - view.safeAreaInsets.bottom)
        }
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
