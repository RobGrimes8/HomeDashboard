import UIKit

final class LightsViewController: UIViewController, DashboardServiceDelegate, UITableViewDataSource, UITableViewDelegate {

    private let service = DashboardService(config: AppConfig.load())
    private var lightGroups: [SmartDevice] = []
    private var lights: [SmartDevice] = []
    private var statusMessage: String?

    private enum Section: Int, CaseIterable {
        case groups
        case lights
    }

    private let tableView = UITableView(frame: .zero, style: .grouped)

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidChange),
            name: .appConfigDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func configDidChange() {
        service.updateConfig(AppConfig.load())
        service.refreshNow()
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
        lightGroups = snapshot.lightGroups
        lights = snapshot.lights
        if let error = snapshot.errorMessage?
            .split(separator: "\n")
            .first(where: { $0.hasPrefix("Lights:") || $0.hasPrefix("Groups:") }) {
            statusMessage = String(error.dropFirst(error.hasPrefix("Lights:") ? "Lights: ".count : "Groups: ".count))
        } else if lights.isEmpty && lightGroups.isEmpty {
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

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .groups:
            return max(lightGroups.count, 1)
        case .lights:
            return max(lights.count, 1)
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        switch section {
        case .groups:
            return "Groups"
        case .lights:
            return "Individual Lights"
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard Section(rawValue: section) == .groups else { return nil }
        if lightGroups.isEmpty {
            return "Hue rooms appear here automatically. Add custom groups in Settings using light names."
        }
        return "Control a whole room at once. Create more groups in Settings or the Hue app."
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: LightControlCell.reuseID, for: indexPath) as? LightControlCell,
            let section = Section(rawValue: indexPath.section)
        else {
            return UITableViewCell()
        }

        switch section {
        case .groups:
            if lightGroups.isEmpty {
                cell.configurePlaceholder(
                    title: "No groups yet",
                    detail: "Hue rooms sync automatically, or add custom groups in Settings."
                )
                cell.onToggle = nil
                cell.onBrightnessChanged = nil
            } else {
                configureCell(cell, with: lightGroups[indexPath.row])
            }
        case .lights:
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
                configureCell(cell, with: lights[indexPath.row])
            }
        }

        return cell
    }

    private func configureCell(_ cell: LightControlCell, with device: SmartDevice) {
        cell.configure(with: device)
        cell.onToggle = { [weak self, weak cell] in
            guard let self = self, let cell = cell else { return }
            self.service.toggleDevice(device) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.service.refreshNow()
                    case .failure(let error):
                        cell.setToggle(isOn: device.isOn)
                        self.presentAlert(title: "Could Not Toggle", message: error.localizedDescription)
                    }
                }
            }
        }
        cell.onBrightnessChanged = { [weak self] value in
            self?.service.setDeviceBrightness(device, brightness: value) { result in
                DispatchQueue.main.async {
                    if case .failure(let error) = result {
                        self?.presentAlert(title: "Brightness Failed", message: error.localizedDescription)
                    } else {
                        self?.service.refreshNow()
                    }
                }
            }
        }
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
