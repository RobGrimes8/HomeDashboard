import UIKit

final class SonosSpeakerDetailViewController: UIViewController, DashboardServiceDelegate, UITableViewDataSource, UITableViewDelegate {

    private enum Section: Int, CaseIterable {
        case sonosFavorites
        case configuredPlaylists
    }

    private var speaker: SmartDevice
    private let service: DashboardService
    private var sonosFavorites: [SonosFavorite] = []
    private var playlists: [AppConfig.SpotifyPlaylist] = []
    private var isLoadingFavorites = false

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
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120

        playlistsTitleLabel.text = "Playlists"
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
        loadSonosFavorites()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        service.delegate = self
        service.updateConfig(AppConfig.load())
        playlists = AppConfig.load().spotifyPlaylists
        service.refreshNow()
        loadSonosFavorites()
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

    private func loadSonosFavorites() {
        isLoadingFavorites = true
        tableView.reloadData()

        service.fetchSpeakerFavorites(speaker) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingFavorites = false
                switch result {
                case .success(let favorites):
                    self.sonosFavorites = favorites
                case .failure:
                    self.sonosFavorites = []
                }
                self.tableView.reloadData()
            }
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .sonosFavorites:
            if isLoadingFavorites { return 1 }
            return max(sonosFavorites.count, 1)
        case .configuredPlaylists:
            return max(playlists.count, 1)
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        switch section {
        case .sonosFavorites:
            return "Sonos Favorites (DEBUG — tap for full detail)"
        case .configuredPlaylists:
            return playlists.isEmpty ? nil : "Settings Playlists"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "playlist-cell", for: indexPath)
            return cell
        }

        switch section {
        case .sonosFavorites:
            let identifier = "favorite-debug-cell"
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
                ?? UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
            styleDebugCell(cell)

            if isLoadingFavorites {
                cell.textLabel?.text = "Loading Sonos favorites…"
                cell.detailTextLabel?.text = nil
                cell.selectionStyle = .none
            } else if sonosFavorites.isEmpty {
                cell.textLabel?.text = "No favorites — tap ♥ in the Sonos app"
                cell.detailTextLabel?.text = nil
                cell.selectionStyle = .none
            } else {
                let favorite = sonosFavorites[indexPath.row]
                cell.textLabel?.text = "#\(indexPath.row): \(favorite.title)"
                cell.detailTextLabel?.text = favoriteDebugPreview(favorite)
                cell.selectionStyle = .default
            }
            return cell

        case .configuredPlaylists:
            let cell = tableView.dequeueReusableCell(withIdentifier: "playlist-cell", for: indexPath)
            cell.backgroundColor = UIColor(white: 1.0, alpha: 0.08)
            cell.textLabel?.textColor = DashboardTheme.textPrimary
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            cell.textLabel?.numberOfLines = 2
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default

            if playlists.isEmpty {
                cell.textLabel?.text = "Optional: add playlists in Settings"
                cell.selectionStyle = .none
            } else {
                cell.textLabel?.text = playlists[indexPath.row].name
            }
            return cell
        }
    }

    private func styleDebugCell(_ cell: UITableViewCell) {
        cell.backgroundColor = UIColor(white: 1.0, alpha: 0.08)
        cell.textLabel?.textColor = DashboardTheme.textPrimary
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        cell.textLabel?.numberOfLines = 2
        cell.detailTextLabel?.textColor = DashboardTheme.textSecondary
        cell.detailTextLabel?.font = UIFont(name: "Menlo-Regular", size: 10) ?? UIFont.systemFont(ofSize: 10)
        cell.detailTextLabel?.numberOfLines = 0
        cell.accessoryType = .disclosureIndicator
    }

    private func favoriteDebugPreview(_ favorite: SonosFavorite) -> String {
        let uri = favorite.uri.isEmpty ? "(empty)" : favorite.uri
        let objectID = favorite.objectID ?? "(nil)"
        let bodyPreview = favorite.rawBody
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let clippedBody = bodyPreview.count > 200 ? String(bodyPreview.prefix(200)) + "…" : bodyPreview
        return """
        tag=\(favorite.elementTag) itemID=\(favorite.itemID)
        objectID=\(objectID)
        uri=\(uri)
        opening=\(favorite.openingTag.isEmpty ? "(empty)" : favorite.openingTag)
        body=\(clippedBody.isEmpty ? "(empty)" : clippedBody)
        """
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }

        switch section {
        case .sonosFavorites:
            guard !isLoadingFavorites, !sonosFavorites.isEmpty else { return }
            let favorite = sonosFavorites[indexPath.row]
            let debugVC = FavoriteDebugViewController(
                favorite: favorite,
                index: indexPath.row,
                speaker: speaker,
                service: service
            )
            navigationController?.pushViewController(debugVC, animated: true)
        case .configuredPlaylists:
            guard !playlists.isEmpty else { return }
            let playlist = playlists[indexPath.row]
            service.playSpeakerPlaylist(speaker, playlist: playlist) { [weak self] result in
                self?.handlePlaybackResult(result)
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let section = Section(rawValue: indexPath.section) else { return 52 }
        switch section {
        case .sonosFavorites:
            return UITableView.automaticDimension
        case .configuredPlaylists:
            return 52
        }
    }

    private func handlePlaybackResult(_ result: Result<Void, LocalHTTPError>) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch result {
            case .success:
                self.speaker.isOn = true
                self.updateUI()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.service.refreshNow()
                }
            case .failure(let error):
                let hint = "Favorites from the Sonos app work best. Add playlists with ♥ in Sonos → My Sonos, then pull to refresh here."
                let message: String
                if case .decodingFailed = error {
                    message = "Sonos did not return playable playlist data. Check Spotify is linked in the Sonos app.\n\n\(hint)"
                } else {
                    message = "\(error.localizedDescription)\n\n\(hint)"
                }
                self.presentAlert(
                    title: "Could Not Play",
                    message: message
                )
            }
        }
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

// MARK: - TEMP DEBUG — remove after favorites playback is fixed

final class FavoriteDebugViewController: UIViewController {

    private let favorite: SonosFavorite
    private let index: Int
    private let speaker: SmartDevice
    private let service: DashboardService

    private let textView = UITextView()
    private let activityIndicator = UIActivityIndicatorView(style: .gray)

    init(
        favorite: SonosFavorite,
        index: Int,
        speaker: SmartDevice,
        service: DashboardService
    ) {
        self.favorite = favorite
        self.index = index
        self.speaker = speaker
        self.service = service
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Favorite #\(index)"
        view.backgroundColor = DashboardTheme.background

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Copy",
            style: .plain,
            target: self,
            action: #selector(copyTapped)
        )

        textView.font = UIFont(name: "Menlo-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11)
        textView.textColor = DashboardTheme.textPrimary
        textView.backgroundColor = UIColor(white: 1.0, alpha: 0.06)
        textView.isEditable = false
        textView.alwaysBounceVertical = true
        textView.text = favorite.debugSummary

        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()

        [textView, activityIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])

        loadBrowseDebug()
    }

    private func loadBrowseDebug() {
        let browseID = favorite.objectID ?? favorite.itemID
        guard !browseID.isEmpty else {
            appendBrowseSection("(no objectID/itemID to browse)")
            activityIndicator.stopAnimating()
            return
        }

        service.fetchSpeakerFavoriteBrowseDebug(speaker, browseID: browseID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.activityIndicator.stopAnimating()
                switch result {
                case .failure(let error):
                    self.appendBrowseSection("BROWSE FAILED: \(error.localizedDescription)")
                case .success(let xml):
                    self.appendBrowseSection(xml)
                }
            }
        }
    }

    private func appendBrowseSection(_ text: String) {
        textView.text = (textView.text ?? "") + "\n\n=== SONOS BROWSE (live) ===\n" + text
        let end = NSRange(location: (textView.text as NSString).length - 1, length: 1)
        textView.scrollRangeToVisible(end)
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = textView.text
        let alert = UIAlertController(title: "Copied", message: "Favorite debug text copied to clipboard.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
