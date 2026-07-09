import UIKit

final class LightsViewController: UIViewController, DashboardServiceDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    private let service = DashboardService(config: AppConfig.load())
    private var lightGroups: [SmartDevice] = []
    private let statusLabel = UILabel()

    private let groupsLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        return layout
    }()

    private lazy var groupsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: groupsLayout)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Rooms"
        view.backgroundColor = DashboardTheme.background

        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.barTintColor = DashboardTheme.navBar
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.prefersLargeTitles = false

        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = UIColor(white: 0.65, alpha: 1.0)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.text = "Swipe for more rooms · Tap ON or OFF"

        groupsCollectionView.backgroundColor = .clear
        groupsCollectionView.dataSource = self
        groupsCollectionView.delegate = self
        groupsCollectionView.register(GroupCardCell.self, forCellReuseIdentifier: GroupCardCell.reuseID)
        groupsCollectionView.showsHorizontalScrollIndicator = true
        groupsCollectionView.alwaysBounceHorizontal = true

        [statusLabel, groupsCollectionView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            groupsCollectionView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            groupsCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            groupsCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            groupsCollectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])

        service.delegate = self
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "All Lights",
            style: .plain,
            target: self,
            action: #selector(showAllLights)
        )
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

    @objc private func showAllLights() {
        navigationController?.pushViewController(LightListViewController(), animated: true)
    }

    func dashboardService(_ service: DashboardService, didUpdate snapshot: DashboardSnapshot) {
        lightGroups = snapshot.lightGroups
        if lightGroups.isEmpty {
            statusLabel.text = "No rooms found. Check Settings, then refresh."
        } else {
            statusLabel.text = "\(lightGroups.count) rooms · swipe sideways · All Lights for individual control"
        }
        groupsCollectionView.reloadData()
    }

    func dashboardService(_ service: DashboardService, didFailWith error: Error) {
        statusLabel.text = error.localizedDescription
        statusLabel.textColor = UIColor(red: 1.0, green: 0.55, blue: 0.35, alpha: 1.0)
    }

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
        let height = max(collectionView.bounds.height - 16, 220)
        return CGSize(width: 220, height: height)
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
                    if let index = self?.lightGroups.firstIndex(where: { $0.id == group.id }) {
                        self?.lightGroups[index] = SmartDevice(
                            id: group.id,
                            name: group.name,
                            kind: group.kind,
                            room: group.room,
                            isOn: isOn,
                            brightness: group.brightness,
                            volume: group.volume,
                            isReachable: group.isReachable
                        )
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.service.refreshNow()
                    }
                case .failure(let error):
                    cell?.setPoweredOn(group.isOn)
                    self?.presentAlert(title: "Could Not Toggle", message: error.localizedDescription)
                }
            }
        }
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
