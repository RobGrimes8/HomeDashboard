import UIKit

final class LightsViewController: UIViewController, DashboardServiceDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITableViewDataSource, UITableViewDelegate {

    private let service = DashboardService(config: AppConfig.load())
    private var lightGroups: [SmartDevice] = []
    private var lights: [SmartDevice] = []
    private var statusMessage: String?

    private let groupsTitleLabel = UILabel()
    private let groupsCollectionView: UICollectionView
    private let lightsTitleLabel = UILabel()
    private let lightsTableView = UITableView(frame: .zero, style: .plain)

    private let groupsLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 14
        layout.minimumLineSpacing = 14
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        return layout
    }()

    init() {
        groupsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: groupsLayout)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lights"
        view.backgroundColor = DashboardTheme.background

        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.barTintColor = DashboardTheme.navBar
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]

        groupsTitleLabel.text = "Rooms"
        groupsTitleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        groupsTitleLabel.textColor = .white

        lightsTitleLabel.text = "Individual Lights"
        lightsTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        lightsTitleLabel.textColor = UIColor(white: 0.82, alpha: 1.0)

        groupsCollectionView.backgroundColor = .clear
        groupsCollectionView.dataSource = self
        groupsCollectionView.delegate = self
        groupsCollectionView.register(GroupCardCell.self, forCellWithReuseIdentifier: GroupCardCell.reuseID)
        groupsCollectionView.showsHorizontalScrollIndicator = false

        lightsTableView.backgroundColor = .clear
        lightsTableView.separatorColor = UIColor(white: 0.22, alpha: 1.0)
        lightsTableView.dataSource = self
        lightsTableView.delegate = self
        lightsTableView.register(LightControlCell.self, forCellReuseIdentifier: LightControlCell.reuseID)

        [groupsTitleLabel, groupsCollectionView, lightsTitleLabel, lightsTableView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            groupsTitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            groupsTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            groupsCollectionView.topAnchor.constraint(equalTo: groupsTitleLabel.bottomAnchor, constant: 12),
            groupsCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            groupsCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            groupsCollectionView.heightAnchor.constraint(equalToConstant: 190),

            lightsTitleLabel.topAnchor.constraint(equalTo: groupsCollectionView.bottomAnchor, constant: 16),
            lightsTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            lightsTableView.topAnchor.constraint(equalTo: lightsTitleLabel.bottomAnchor, constant: 8),
            lightsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lightsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            lightsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
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

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeLeft
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
        groupsCollectionView.reloadData()
        lightsTableView.reloadData()
    }

    func dashboardService(_ service: DashboardService, didFailWith error: Error) {
        presentAlert(title: "Lights Unavailable", message: error.localizedDescription)
    }

    // MARK: - Groups Collection

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return max(lightGroups.count, 1)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GroupCardCell.reuseID, for: indexPath) as? GroupCardCell else {
            return UICollectionViewCell()
        }

        if lightGroups.isEmpty {
            cell.configurePlaceholder()
            cell.onTurnOn = nil
            cell.onTurnOff = nil
            return cell
        }

        let group = lightGroups[indexPath.item]
        cell.configure(with: group)
        cell.onTurnOn = { [weak self, weak cell] in
            self?.setGroup(group, isOn: true, cell: cell)
        }
        cell.onTurnOff = { [weak self, weak cell] in
            self?.setGroup(group, isOn: false, cell: cell)
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let columns: CGFloat = 4
        let inset: CGFloat = 40
        let spacing: CGFloat = 14 * (columns - 1)
        let width = floor((collectionView.bounds.width - inset - spacing) / columns)
        return CGSize(width: max(width, 150), height: 170)
    }

    private func setGroup(_ group: SmartDevice, isOn: Bool, cell: GroupCardCell?) {
        guard group.isOn != isOn else { return }

        cell?.setPoweredOn(isOn)

        let target = SmartDevice(
            id: group.id,
            name: group.name,
            kind: group.kind,
            room: group.room,
            isOn: !isOn,
            brightness: group.brightness,
            volume: group.volume,
            isReachable: group.isReachable
        )

        service.toggleDevice(target) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.service.refreshNow()
                case .failure(let error):
                    cell?.setPoweredOn(group.isOn)
                    self?.presentAlert(title: "Could Not Toggle", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Lights Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(lights.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: LightControlCell.reuseID, for: indexPath) as? LightControlCell else {
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
            configureLightCell(cell, with: lights[indexPath.row])
        }

        return cell
    }

    private func configureLightCell(_ cell: LightControlCell, with device: SmartDevice) {
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
        return 100
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
