import UIKit

final class SonosViewController: UIViewController, DashboardServiceDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    private let service = DashboardService(config: AppConfig.load())
    private var speakers: [SmartDevice] = []

    private let subtitleLabel = UILabel()

    private let layout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 8, left: 24, bottom: 24, right: 24)
        return layout
    }()

    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sonos"
        view.backgroundColor = .clear
        DashboardTheme.installBackground(in: view)
        DashboardTheme.styleNavigationBar(navigationController?.navigationBar)

        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = DashboardTheme.textSecondary
        subtitleLabel.text = "Tap a speaker for playlists"

        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(SonosSpeakerCardCell.self, forCellWithReuseIdentifier: SonosSpeakerCardCell.reuseID)
        collectionView.alwaysBounceVertical = true

        [subtitleLabel, collectionView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            subtitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            collectionView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
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
        service.delegate = self
        service.updateConfig(AppConfig.load())
        service.refreshNow()
    }

    @objc private func refreshTapped() {
        service.refreshNow()
    }

    func dashboardService(_ service: DashboardService, didUpdate snapshot: DashboardSnapshot) {
        speakers = snapshot.speakers
        subtitleLabel.text = speakers.isEmpty
            ? "Add Sonos IPs in Settings"
            : "\(speakers.count) speakers · tap for playlists"
        collectionView.reloadData()
    }

    func dashboardService(_ service: DashboardService, didFailWith error: Error) {
        presentAlert(title: "Sonos Unavailable", message: error.localizedDescription)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return max(speakers.count, 1)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SonosSpeakerCardCell.reuseID, for: indexPath) as? SonosSpeakerCardCell else {
            return UICollectionViewCell()
        }

        if speakers.isEmpty {
            cell.configurePlaceholder()
            clearActions(for: cell)
            return cell
        }

        let speaker = speakers[indexPath.item]
        cell.configure(with: speaker)
        bindActions(for: cell, speaker: speaker)
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let columns: CGFloat = 2
        let spacing: CGFloat = 16
        let horizontalInset: CGFloat = 48
        let availableWidth = collectionView.bounds.width - horizontalInset - spacing
        let width = floor(availableWidth / columns)
        return CGSize(width: width, height: 188)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard !speakers.isEmpty else { return }
        let speaker = speakers[indexPath.item]
        let detail = SonosSpeakerDetailViewController(speaker: speaker, service: service)
        navigationController?.pushViewController(detail, animated: true)
    }

    private func clearActions(for cell: SonosSpeakerCardCell) {
        cell.onVolumeDown = nil
        cell.onVolumeUp = nil
        cell.onPrevious = nil
        cell.onPlayPause = nil
        cell.onNext = nil
    }

    private func bindActions(for cell: SonosSpeakerCardCell, speaker: SmartDevice) {
        let speakerID = speaker.id
        cell.onVolumeDown = { [weak self] in
            guard let self = self, let current = self.speakers.first(where: { $0.id == speakerID }) else { return }
            self.adjustVolume(for: current, by: -2, cell: cell)
        }
        cell.onVolumeUp = { [weak self] in
            guard let self = self, let current = self.speakers.first(where: { $0.id == speakerID }) else { return }
            self.adjustVolume(for: current, by: 2, cell: cell)
        }
        cell.onPrevious = { [weak self] in
            guard let self = self, let current = self.speakers.first(where: { $0.id == speakerID }) else { return }
            self.runTransport(on: current, action: { $0.previousSpeakerTrack($1, completion: $2) }, cell: cell)
        }
        cell.onPlayPause = { [weak self] in
            guard let self = self, let current = self.speakers.first(where: { $0.id == speakerID }) else { return }
            self.runTransport(on: current, action: { $0.toggleSpeakerPlayback($1, completion: $2) }, cell: cell, togglePlayState: true)
        }
        cell.onNext = { [weak self] in
            guard let self = self, let current = self.speakers.first(where: { $0.id == speakerID }) else { return }
            self.runTransport(on: current, action: { $0.skipSpeakerTrack($1, completion: $2) }, cell: cell)
        }
    }

    private func adjustVolume(for speaker: SmartDevice, by delta: Int, cell: SonosSpeakerCardCell) {
        service.adjustSpeakerVolume(speaker, by: delta) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let volume):
                    self?.updateSpeaker(speaker.id, volume: volume)
                    cell.setVolume(volume)
                case .failure(let error):
                    self?.presentAlert(title: "Volume Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func runTransport(
        on speaker: SmartDevice,
        action: (DashboardService, SmartDevice, @escaping (Result<Void, LocalHTTPError>) -> Void) -> Void,
        cell: SonosSpeakerCardCell,
        togglePlayState: Bool = false
    ) {
        action(service, speaker) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if togglePlayState {
                        let newState = !speaker.isOn
                        self?.updateSpeaker(speaker.id, isOn: newState)
                        cell.setPlaying(newState)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.service.refreshNow()
                    }
                case .failure(let error):
                    self?.presentAlert(title: "Playback Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func updateSpeaker(_ id: String, volume: Int? = nil, isOn: Bool? = nil) {
        guard let index = speakers.firstIndex(where: { $0.id == id }) else { return }
        if let volume = volume { speakers[index].volume = volume }
        if let isOn = isOn { speakers[index].isOn = isOn }
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
