import UIKit

final class LightsViewController: UIViewController, DashboardServiceDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    private let service = DashboardService(config: AppConfig.load())
    private var lightGroups: [SmartDevice] = []

    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let allLightsButton = UIButton(type: .system)
    private let refreshButton = UIButton(type: .system)

    private let groupsLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 4, left: 24, bottom: 24, right: 24)
        return layout
    }()

    private lazy var groupsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: groupsLayout)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        DashboardTheme.installBackground(in: view)

        titleLabel.text = "My Dashboard"
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = DashboardTheme.textPrimary

        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = DashboardTheme.textSecondary
        subtitleLabel.text = "Loading rooms..."

        configurePillButton(allLightsButton, title: "All Lights")
        configurePillButton(refreshButton, title: "Refresh")
        allLightsButton.addTarget(self, action: #selector(showAllLights), for: .touchUpInside)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)

        groupsCollectionView.backgroundColor = .clear
        groupsCollectionView.dataSource = self
        groupsCollectionView.delegate = self
        groupsCollectionView.register(GroupCardCell.self, forCellWithReuseIdentifier: GroupCardCell.reuseID)
        groupsCollectionView.showsVerticalScrollIndicator = false
        groupsCollectionView.alwaysBounceVertical = true

        [headerView, titleLabel, subtitleLabel, allLightsButton, refreshButton, groupsCollectionView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        headerView.addSubview(allLightsButton)
        headerView.addSubview(refreshButton)
        view.addSubview(groupsCollectionView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            headerView.heightAnchor.constraint(equalToConstant: 64),

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            refreshButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            refreshButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),

            allLightsButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            allLightsButton.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -10),

            groupsCollectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            groupsCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            groupsCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            groupsCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        service.delegate = self

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        service.updateConfig(AppConfig.load())
        service.refreshNow()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func configurePillButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        button.setTitleColor(DashboardTheme.textPrimary, for: .normal)
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.10)
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = DashboardTheme.glassBorder.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
    }

    @objc func configDidChange() {
        service.updateConfig(AppConfig.load())
        service.refreshNow()
    }

    @objc func refreshTapped() {
        service.refreshNow()
    }

    @objc func showAllLights() {
        navigationController?.pushViewController(LightListViewController(), animated: true)
    }

    func dashboardService(_ service: DashboardService, didUpdate snapshot: DashboardSnapshot) {
        lightGroups = snapshot.lightGroups
        if lightGroups.isEmpty {
            subtitleLabel.text = "No rooms found"
            subtitleLabel.textColor = DashboardTheme.textSecondary
        } else {
            subtitleLabel.text = "\(lightGroups.count) rooms"
            subtitleLabel.textColor = DashboardTheme.textSecondary
        }
        groupsCollectionView.reloadData()
    }

    func dashboardService(_ service: DashboardService, didFailWith error: Error) {
        subtitleLabel.text = error.localizedDescription
        subtitleLabel.textColor = UIColor(red: 1.0, green: 0.55, blue: 0.35, alpha: 1.0)
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
        cell.onTurnOn = { [weak self] in
            self?.setGroup(group, isOn: true, cell: cell)
        }
        cell.onTurnOff = { [weak self] in
            self?.setGroup(group, isOn: false, cell: cell)
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let columns: CGFloat = 3
        let spacing: CGFloat = 16
        let horizontalInset: CGFloat = 48
        let availableWidth = collectionView.bounds.width - horizontalInset - (spacing * (columns - 1))
        let width = floor(availableWidth / columns)
        return CGSize(width: width, height: 168)
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
                guard let self = self else { return }
                switch result {
                case .success:
                    if let index = self.lightGroups.firstIndex(where: { $0.id == group.id }) {
                        self.lightGroups[index] = SmartDevice(
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
                        self.service.refreshNow()
                    }
                case .failure(let error):
                    cell?.setPoweredOn(group.isOn)
                    self.presentAlert(title: "Could Not Toggle", message: error.localizedDescription)
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
