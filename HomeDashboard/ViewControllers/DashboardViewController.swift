import UIKit

final class DashboardViewController: UIViewController, DashboardServiceDelegate {

    private let service = DashboardService(config: AppConfig.load())
    private var snapshot = DashboardSnapshot.empty

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = DashboardTheme.textSecondary
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 20, bottom: 24, right: 20)
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.alwaysBounceVertical = true
        return view
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        return control
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home Dashboard"
        view.backgroundColor = .clear
        DashboardTheme.installBackground(in: view)
        DashboardTheme.styleNavigationBar(navigationController?.navigationBar)

        service.delegate = self
        setupLayout()
        collectionView.register(DeviceTileCell.self, forCellWithReuseIdentifier: DeviceTileCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.refreshControl = refreshControl
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        service.updateConfig(AppConfig.load())
        service.startAutoRefresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        service.stopAutoRefresh()
    }

    private func setupLayout() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            collectionView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func refreshPulled() {
        service.refreshNow()
    }

    private func updateStatusLabel() {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        let time = formatter.string(from: snapshot.lastUpdated)
        let count = snapshot.allDevices.count

        if let error = snapshot.errorMessage {
            statusLabel.text = "Updated \(time) · \(count) devices\n\(error)"
            statusLabel.textColor = UIColor(red: 1.0, green: 0.55, blue: 0.35, alpha: 1.0)
        } else {
            statusLabel.text = "Updated \(time) · \(count) devices on local network"
            statusLabel.textColor = DashboardTheme.textSecondary
        }
    }

    // MARK: - DashboardServiceDelegate

    func dashboardService(_ service: DashboardService, didUpdate snapshot: DashboardSnapshot) {
        self.snapshot = snapshot
        updateStatusLabel()
        collectionView.reloadData()
        refreshControl.endRefreshing()
    }

    func dashboardService(_ service: DashboardService, didFailWith error: Error) {
        updateStatusLabel()
        refreshControl.endRefreshing()
    }
}

extension DashboardViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return max(snapshot.allDevices.count, 1)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DeviceTileCell.reuseID, for: indexPath) as? DeviceTileCell
        else {
            return UICollectionViewCell()
        }

        if snapshot.allDevices.isEmpty {
            cell.configurePlaceholder()
        } else {
            cell.configure(with: snapshot.allDevices[indexPath.item])
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = collectionView.bounds.width - 40
        let columnWidth = (width - 16) / 2
        return CGSize(width: columnWidth, height: 130)
    }
}
