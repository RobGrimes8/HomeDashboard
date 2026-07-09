import UIKit

final class LightsViewController: UIViewController, DashboardServiceDelegate, UITableViewDataSource, UITableViewDelegate {

    private let service = DashboardService(config: AppConfig.load())
    private var lights: [SmartDevice] = []
    private var statusMessage: String?

    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lights"
        view.backgroundColor = UIColor(white: 0.06, alpha: 1.0)

        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.barTintColor = UIColor(white: 0.08, alpha: 1.0)
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]

        tableView.backgroundColor = UIColor(white: 0.06, alpha: 1.0)
        tableView.separatorColor = UIColor(white: 0.18, alpha: 1.0)
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

    // MARK: - DashboardServiceDelegate

    func dashboardService(_ service: DashboardService, didUpdate snapshot: DashboardSnapshot) {
        lights = snapshot.lights
        if let error = snapshot.errorMessage?
            .split(separator: "\n")
            .first(where: { $0.hasPrefix("Lights:") }) {
            statusMessage = String(error.dropFirst("Lights: ".count))
        } else if lights.isEmpty {
            statusMessage = AppConfig.load().isHueConfigured
                ? "No lights returned from the bridge. Tap refresh."
                : nil
        } else {
            statusMessage = nil
        }
        tableView.reloadData()
    }

    func dashboardService(_ service: DashboardService, didFailWith error: Error) {
        presentAlert(title: "Lights Unavailable", message: error.localizedDescription)
    }

    // MARK: - UITableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(lights.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: LightControlCell.reuseID, for: indexPath) as? LightControlCell
        else {
            return UITableViewCell()
        }

        if lights.isEmpty {
            let config = AppConfig.load()
            if config.isHueConfigured {
                cell.configurePlaceholder(
                    title: "No lights found",
                    detail: statusMessage ?? "Check bridge IP and username, then tap refresh."
                )
            } else {
                cell.configurePlaceholder()
            }
            cell.onToggle = nil
            cell.onBrightnessChanged = nil
        } else {
            let light = lights[indexPath.row]
            cell.configure(with: light)
            cell.onToggle = { [weak self] in
                self?.service.toggleLight(light) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            self?.service.refreshNow()
                        case .failure(let error):
                            self?.presentAlert(title: "Could Not Toggle Light", message: error.localizedDescription)
                        }
                    }
                }
            }
            cell.onBrightnessChanged = { [weak self] value in
                self?.service.setLightBrightness(light, brightness: value) { result in
                    DispatchQueue.main.async {
                        if case .failure(let error) = result {
                            self?.presentAlert(title: "Brightness Failed", message: error.localizedDescription)
                        }
                    }
                }
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 110
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
