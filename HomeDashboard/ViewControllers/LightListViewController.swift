import UIKit

/// Full list of individual lights with brightness sliders.
final class LightListViewController: UIViewController, DashboardServiceDelegate, UITableViewDataSource, UITableViewDelegate {

    private let service = DashboardService(config: AppConfig.load())
    private var lights: [SmartDevice] = []
    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "All Lights"
        view.backgroundColor = .clear
        DashboardTheme.installBackground(in: view)
        DashboardTheme.styleNavigationBar(navigationController?.navigationBar)

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(LightControlCell.self, forCellReuseIdentifier: LightControlCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        service.delegate = self
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refreshTapped)
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        service.updateConfig(AppConfig.load())
        service.refreshNow()
    }

    @objc private func refreshTapped() {
        service.refreshNow()
    }

    func dashboardService(_ service: DashboardService, didUpdate snapshot: DashboardSnapshot) {
        lights = snapshot.lights
        tableView.reloadData()
    }

    func dashboardService(_ service: DashboardService, didFailWith error: Error) {
        presentAlert(title: "Lights Unavailable", message: error.localizedDescription)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(lights.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: LightControlCell.reuseID, for: indexPath) as? LightControlCell else {
            return UITableViewCell()
        }

        if lights.isEmpty {
            cell.configurePlaceholder(title: "No lights", detail: "Configure Hue in Settings")
            cell.onToggle = nil
            cell.onBrightnessChanged = nil
            return cell
        }

        let light = lights[indexPath.row]
        cell.configure(with: light)
        cell.onToggle = { [weak self, weak cell] in
            guard let self = self, let cell = cell else { return }
            self.service.toggleDevice(light) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.service.refreshNow()
                    case .failure(let error):
                        cell.setToggle(isOn: light.isOn)
                        self.presentAlert(title: "Could Not Toggle", message: error.localizedDescription)
                    }
                }
            }
        }
        cell.onBrightnessChanged = { [weak self] value in
            self?.service.setDeviceBrightness(light, brightness: value) { result in
                DispatchQueue.main.async {
                    if case .failure(let error) = result {
                        self?.presentAlert(title: "Brightness Failed", message: error.localizedDescription)
                    }
                }
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
