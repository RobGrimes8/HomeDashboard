import UIKit

final class SonosSpeakerCardCell: UICollectionViewCell {

    static let reuseID = "SonosSpeakerCardCell"

    var onVolumeDown: (() -> Void)?
    var onVolumeUp: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onNext: (() -> Void)?

    private let glassPanel = GlassPanelView()
    private let nameLabel = UILabel()
    private let nowPlayingLabel = UILabel()
    private let volumeDownButton = UIButton(type: .system)
    private let volumeUpButton = UIButton(type: .system)
    private let volumeLabel = UILabel()
    private let previousButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private var isPlaying = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        glassPanel.cornerRadius = 16
        glassPanel.panelTint = DashboardTheme.glassTeal

        nameLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        nameLabel.textColor = DashboardTheme.textPrimary
        nameLabel.numberOfLines = 2

        nowPlayingLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        nowPlayingLabel.textColor = DashboardTheme.textSecondary
        nowPlayingLabel.numberOfLines = 2

        volumeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        volumeLabel.textColor = DashboardTheme.textPrimary
        volumeLabel.textAlignment = .center

        volumeDownButton.addTarget(self, action: #selector(volumeDownTapped), for: .touchUpInside)
        volumeUpButton.addTarget(self, action: #selector(volumeUpTapped), for: .touchUpInside)
        previousButton.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        [glassPanel, nameLabel, nowPlayingLabel, volumeDownButton, volumeLabel, volumeUpButton,
         previousButton, playPauseButton, nextButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        contentView.addSubview(glassPanel)
        glassPanel.addSubview(nameLabel)
        glassPanel.addSubview(nowPlayingLabel)
        glassPanel.addSubview(volumeDownButton)
        glassPanel.addSubview(volumeLabel)
        glassPanel.addSubview(volumeUpButton)
        glassPanel.addSubview(previousButton)
        glassPanel.addSubview(playPauseButton)
        glassPanel.addSubview(nextButton)

        NSLayoutConstraint.activate([
            glassPanel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            glassPanel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            glassPanel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            glassPanel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            nameLabel.topAnchor.constraint(equalTo: glassPanel.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: glassPanel.leadingAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(equalTo: volumeDownButton.leadingAnchor, constant: -8),

            volumeUpButton.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -12),
            volumeUpButton.topAnchor.constraint(equalTo: glassPanel.topAnchor, constant: 12),
            volumeUpButton.widthAnchor.constraint(equalToConstant: 36),
            volumeUpButton.heightAnchor.constraint(equalToConstant: 36),

            volumeLabel.centerYAnchor.constraint(equalTo: volumeUpButton.centerYAnchor),
            volumeLabel.trailingAnchor.constraint(equalTo: volumeUpButton.leadingAnchor, constant: -4),
            volumeLabel.widthAnchor.constraint(equalToConstant: 32),

            volumeDownButton.centerYAnchor.constraint(equalTo: volumeUpButton.centerYAnchor),
            volumeDownButton.trailingAnchor.constraint(equalTo: volumeLabel.leadingAnchor, constant: -4),
            volumeDownButton.widthAnchor.constraint(equalToConstant: 36),
            volumeDownButton.heightAnchor.constraint(equalToConstant: 36),

            nowPlayingLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            nowPlayingLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            nowPlayingLabel.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -14),

            playPauseButton.bottomAnchor.constraint(equalTo: glassPanel.bottomAnchor, constant: -14),
            playPauseButton.centerXAnchor.constraint(equalTo: glassPanel.centerXAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 44),
            playPauseButton.heightAnchor.constraint(equalToConstant: 44),

            previousButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            previousButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -12),
            previousButton.widthAnchor.constraint(equalToConstant: 40),
            previousButton.heightAnchor.constraint(equalToConstant: 40),

            nextButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            nextButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 12),
            nextButton.widthAnchor.constraint(equalToConstant: 40),
            nextButton.heightAnchor.constraint(equalToConstant: 40)
        ])

        styleCircle(volumeDownButton, title: "−")
        styleCircle(volumeUpButton, title: "+")
        styleCircle(previousButton, title: "⏮")
        styleCircle(nextButton, title: "⏭")
        styleCircle(playPauseButton, title: "⏸", active: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with speaker: SmartDevice) {
        isPlaying = speaker.isOn
        nameLabel.text = speaker.name
        nowPlayingLabel.text = speaker.nowPlaying ?? (speaker.isReachable ? "Nothing playing" : "Unreachable")
        glassPanel.setGlowActive(speaker.isOn)
        setVolume(speaker.volume ?? 0)
        let enabled = speaker.isReachable
        [volumeDownButton, volumeUpButton, previousButton, playPauseButton, nextButton].forEach {
            $0.isEnabled = enabled
            $0.alpha = enabled ? 1.0 : 0.45
        }
        updatePlayPauseButton()
    }

    func configurePlaceholder() {
        isPlaying = false
        nameLabel.text = "No speakers"
        nowPlayingLabel.text = "Add Sonos IPs in Settings"
        glassPanel.setGlowActive(false)
        setVolume(0)
        [volumeDownButton, volumeUpButton, previousButton, playPauseButton, nextButton].forEach {
            $0.isEnabled = false
            $0.alpha = 0.45
        }
        updatePlayPauseButton()
    }

    func setVolume(_ volume: Int) {
        volumeLabel.text = "\(volume)"
    }

    func setPlaying(_ playing: Bool) {
        isPlaying = playing
        glassPanel.setGlowActive(playing)
        updatePlayPauseButton()
    }

    private func updatePlayPauseButton() {
        styleCircle(playPauseButton, title: isPlaying ? "⏸" : "▶", active: isPlaying)
    }

    private func styleCircle(_ button: UIButton, title: String, active: Bool = false) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.layer.cornerRadius = 20
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

    @objc private func volumeDownTapped() { onVolumeDown?() }
    @objc private func volumeUpTapped() { onVolumeUp?() }
    @objc private func previousTapped() { onPrevious?() }
    @objc private func playPauseTapped() { onPlayPause?() }
    @objc private func nextTapped() { onNext?() }
}
