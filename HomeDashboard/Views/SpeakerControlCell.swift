import UIKit

final class SpeakerControlCell: UITableViewCell {

    static let reuseID = "SpeakerControlCell"

    var onVolumeChanged: ((Int) -> Void)?

    private let glassPanel = GlassPanelView()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let volumeLabel = UILabel()
    private let slider = UISlider()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        glassPanel.cornerRadius = 14
        glassPanel.panelTint = DashboardTheme.glassTeal

        nameLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        nameLabel.textColor = DashboardTheme.textPrimary

        detailLabel.font = UIFont.systemFont(ofSize: 13)
        detailLabel.textColor = DashboardTheme.textSecondary

        volumeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        volumeLabel.textColor = DashboardTheme.textPrimary
        volumeLabel.textAlignment = .right

        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.minimumTrackTintColor = DashboardTheme.accent
        slider.maximumTrackTintColor = UIColor(white: 1.0, alpha: 0.18)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        [glassPanel, nameLabel, detailLabel, volumeLabel, slider].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        contentView.addSubview(glassPanel)
        glassPanel.addSubview(nameLabel)
        glassPanel.addSubview(detailLabel)
        glassPanel.addSubview(volumeLabel)
        glassPanel.addSubview(slider)

        NSLayoutConstraint.activate([
            glassPanel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            glassPanel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            glassPanel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            glassPanel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            nameLabel.topAnchor.constraint(equalTo: glassPanel.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: glassPanel.leadingAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -14),

            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            volumeLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 10),
            volumeLabel.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -14),
            volumeLabel.widthAnchor.constraint(equalToConstant: 36),

            slider.centerYAnchor.constraint(equalTo: volumeLabel.centerYAnchor),
            slider.leadingAnchor.constraint(equalTo: glassPanel.leadingAnchor, constant: 14),
            slider.trailingAnchor.constraint(equalTo: volumeLabel.leadingAnchor, constant: -10),
            slider.bottomAnchor.constraint(equalTo: glassPanel.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with speaker: SmartDevice) {
        nameLabel.text = speaker.name
        if speaker.isReachable {
            let state = speaker.isOn ? "Playing" : "Idle"
            detailLabel.text = state
        } else {
            detailLabel.text = "Unreachable"
        }
        glassPanel.setGlowActive(speaker.isOn)
        updateVolumeDisplay(speaker.volume ?? 0)
        slider.isEnabled = speaker.isReachable
    }

    func setVolume(_ volume: Int) {
        updateVolumeDisplay(volume)
    }

    func configurePlaceholder() {
        nameLabel.text = "Configure Sonos in Settings"
        detailLabel.text = "Enter speaker IP addresses"
        glassPanel.setGlowActive(false)
        updateVolumeDisplay(0)
        slider.isEnabled = false
    }

    private func updateVolumeDisplay(_ volume: Int) {
        slider.value = Float(volume)
        volumeLabel.text = "\(volume)"
    }

    @objc private func sliderChanged() {
        let volume = Int(slider.value.rounded())
        updateVolumeDisplay(volume)
        onVolumeChanged?(volume)
    }
}
