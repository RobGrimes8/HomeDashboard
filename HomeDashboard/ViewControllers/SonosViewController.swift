import UIKit

final class SonosViewController: UIViewController, DashboardServiceDelegate, UITableViewDataSource, UITableViewDelegate {

    private let service = DashboardService(config: AppConfig.load())
    private var speakers: [SmartDevice] = []

    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sonos"
        view.backgroundColor = .clear
        DashboardTheme.installBackground(in: view)
        DashboardTheme.styleNavigationBar(navigationController?.navigationBar)

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SpeakerControlCell.self, forCellReuseIdentifier: SpeakerControlCell.reuseID)

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
        speakers = snapshot.speakers
        tableView.reloadData()
    }

    func dashboardService(_ service: DashboardService, didFailWith error: Error) {
        presentAlert(title: "Sonos Unavailable", message: error.localizedDescription)
    }

    // MARK: - UITableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(speakers.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: SpeakerControlCell.reuseID, for: indexPath) as? SpeakerControlCell
        else {
            return UITableViewCell()
        }

        if speakers.isEmpty {
            cell.configurePlaceholder()
            cell.onVolumeChanged = nil
        } else {
            let speaker = speakers[indexPath.row]
            cell.configure(with: speaker)
            cell.onVolumeChanged = { [weak self] value in
                self?.service.setSpeakerVolume(speaker, volume: value) { result in
                    DispatchQueue.main.async {
                        if case .failure(let error) = result {
                            self?.presentAlert(title: "Volume Failed", message: error.localizedDescription)
                        }
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
