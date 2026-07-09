import UIKit

final class SonosSpeakerDetailViewController: UIViewController, DashboardServiceDelegate, UITableViewDataSource, UITableViewDelegate {

    private var speaker: SmartDevice
    private let service: DashboardService
    private var playlists: [AppConfig.SpotifyPlaylist] = []

    private let headerView = UIView()
    private let nameLabel = UILabel()
    private let nowPlayingLabel = UILabel()
    private let volumeDownButton = UIButton(type: .system)
    private let volumeUpButton = UIButton(type: .system)
    private let volumeLabel = UILabel()
    private let previousButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let playlistsTitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(speaker: SmartDevice, service: DashboardService) {
        self.speaker = speaker
        self.service = service
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = speaker.name
        view.backgroundColor = .clear
        DashboardTheme.installBackground(in: view)
        DashboardTheme.styleNavigationBar(navigationController?.navigationBar)

        playlists = AppConfig.load().spotifyPlaylists

        nameLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        nameLabel.textColor = DashboardTheme.textPrimary

        nowPlayingLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        nowPlayingLabel.textColor = DashboardTheme.textSecondary
        nowPlayingLabel.numberOfLines = 2

        volumeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        volumeLabel.textColor = DashboardTheme.textPrimary
        volumeLabel.textAlignment = .center

        volumeDownButton.addTarget(self, action: #selector(volumeDownTapped), for: .touchUpInside)
        volumeUpButton.addTarget(self, action: #selector(volumeUpTapped), for: .touchUpInside)
        previousButton.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "playlist-cell")

        playlistsTitleLabel.text = "Spotify Playlists"
        playlistsTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        playlistsTitleLabel.textColor = DashboardTheme.textPrimary

        [headerView, nameLabel, nowPlayingLabel, volumeDownButton, volumeLabel, volumeUpButton,
         previousButton, playPauseButton, nextButton, playlistsTitleLabel, tableView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        view.addSubview(headerView)
        headerView.addSubview(nameLabel)
        headerView.addSubview(nowPlayingLabel)
        headerView.addSubview(volumeDownButton)
        headerView.addSubview(volumeLabel)
        headerView.addSubview(volumeUpButton)
        headerView.addSubview(previousButton)
        headerView.addSubview(playPauseButton)
        headerView.addSubview(nextButton)
        view.addSubview(playlistsTitleLabel)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            headerView.heightAnchor.constraint(equalToConstant: 170),

            nameLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),

            nowPlayingLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            nowPlayingLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            nowPlayingLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            volumeDownButton.topAnchor.constraint(equalTo: nowPlayingLabel.bottomAnchor, constant: 16),
            volumeDownButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            volumeDownButton.widthAnchor.constraint(equalToConstant: 44),
            volumeDownButton.heightAnchor.constraint(equalToConstant: 44),

            volumeLabel.centerYAnchor.constraint(equalTo: volumeDownButton.centerYAnchor),
            volumeLabel.leadingAnchor.constraint(equalTo: volumeDownButton.trailingAnchor, constant: 12),
            volumeLabel.widthAnchor.constraint(equalToConstant: 44),

            volumeUpButton.centerYAnchor.constraint(equalTo: volumeDownButton.centerYAnchor),
            volumeUpButton.leadingAnchor.constraint(equalTo: volumeLabel.trailingAnchor, constant: 12),
            volumeUpButton.widthAnchor.constraint(equalToConstant: 44),
            volumeUpButton.heightAnchor.constraint(equalToConstant: 44),

            playPauseButton.topAnchor.constraint(equalTo: volumeDownButton.bottomAnchor, constant: 16),
            playPauseButton.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 48),
            playPauseButton.heightAnchor.constraint(equalToConstant: 48),

            previousButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            previousButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -16),
            previousButton.widthAnchor.constraint(equalToConstant: 44),
            previousButton.heightAnchor.constraint(equalToConstant: 44),

            nextButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            nextButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 16),
            nextButton.widthAnchor.constraint(equalToConstant: 44),
            nextButton.heightAnchor.constraint(equalToConstant: 44),

            playlistsTitleLabel.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            playlistsTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            playlistsTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            tableView.topAnchor.constraint(equalTo: playlistsTitleLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        styleCircle(volumeDownButton, title: "−")
        styleCircle(volumeUpButton, title: "+")
        styleCircle(previousButton, title: "⏮")
        styleCircle(nextButton, title: "⏭")

        service.delegate = self
        updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        service.delegate = self
        service.updateConfig(AppConfig.load())
        playlists = AppConfig.load().spotifyPlaylists
        service.refreshNow()
        tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            service.delegate = nil
        }
    }

    func dashboardService(_ service: DashboardService, didUpdate snapshot: DashboardSnapshot) {
        if let updated = snapshot.speakers.first(where: { $0.id == speaker.id }) {
            speaker = updated
            updateUI()
        }
    }

    func dashboardService(_ service: DashboardService, didFailWith error: Error) {}

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(playlists.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "playlist-cell", for: indexPath)
        cell.backgroundColor = UIColor(white: 1.0, alpha: 0.08)
        cell.textLabel?.textColor = DashboardTheme.textPrimary
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        cell.accessoryType = .disclosureIndicator

        if playlists.isEmpty {
            cell.textLabel?.text = "Add playlists in Settings"
            cell.selectionStyle = .none
        } else {
            cell.textLabel?.text = playlists[indexPath.row].name
            cell.selectionStyle = .default
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !playlists.isEmpty else { return }

        let playlist = playlists[indexPath.row]
        service.playSpeakerPlaylist(speaker, playlist: playlist) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.speaker.isOn = true
                    self?.updateUI()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.service.refreshNow()
                    }
                case .failure(let error):
                    let hint = "Check Spotify is linked in the Sonos app (Settings → Services) and you have Spotify Premium. Enable Debug Log in Settings for details."
                    self?.presentAlert(
                        title: "Could Not Play Playlist",
                        message: "\(error.localizedDescription)\n\n\(hint)"
                    )
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 52
    }

    private func updateUI() {
        nameLabel.text = speaker.name
        nowPlayingLabel.text = speaker.nowPlaying ?? "Nothing playing"
        volumeLabel.text = "\(speaker.volume ?? 0)"
        styleCircle(playPauseButton, title: speaker.isOn ? "⏸" : "▶", active: speaker.isOn)
    }

    private func styleCircle(_ button: UIButton, title: String, active: Bool = false) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        button.layer.cornerRadius = 22
        button.layer.masksToBounds = true
        button.layer.borderWidth = 1
        if active {
            button.backgroundColor = DashboardTheme.accent.withAlphaComponent(0.55)
            button.layer.borderColor = DashboardTheme.onGlow.withAlphaComponent(0.6).cgColor
        } else {
            button.backgroundColor = UIColor(white: 1.0, alpha: 0.08)
            button.layer.borderColor = DashboardTheme.glassBorder.cgColor
        }
    }

    @objc private func volumeDownTapped() {
        service.adjustSpeakerVolume(speaker, by: -2) { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let volume) = result {
                    self?.speaker.volume = volume
                    self?.updateUI()
                }
            }
        }
    }

    @objc private func volumeUpTapped() {
        service.adjustSpeakerVolume(speaker, by: 2) { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let volume) = result {
                    self?.speaker.volume = volume
                    self?.updateUI()
                }
            }
        }
    }

    @objc private func previousTapped() {
        service.previousSpeakerTrack(speaker) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.service.refreshNow()
            }
        }
    }

    @objc private func playPauseTapped() {
        service.toggleSpeakerPlayback(speaker) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.speaker.isOn.toggle()
                    self?.updateUI()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.service.refreshNow()
                    }
                }
            }
        }
    }

    @objc private func nextTapped() {
        service.skipSpeakerTrack(speaker) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.service.refreshNow()
            }
        }
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
