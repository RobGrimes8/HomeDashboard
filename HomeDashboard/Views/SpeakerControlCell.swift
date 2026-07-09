import UIKit

final class SpeakerControlCell: UITableViewCell {

    static let reuseID = "SpeakerControlCell"

    var onVolumeChanged: ((Int) -> Void)?

    private let glassPanel = GlassPanelView()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
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

        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.minimumTrackTintColor = DashboardTheme.accent
        slider.maximumTrackTintColor = UIColor(white: 1.0, alpha: 0.18)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        [glassPanel, nameLabel, detailLabel, slider].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        contentView.addSubview(glassPanel)
        glassPanel.addSubview(nameLabel)
        glassPanel.addSubview(detailLabel)
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
            detailLabel.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -14),

            slider.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 10),
            slider.leadingAnchor.constraint(equalTo: glassPanel.leadingAnchor, constant: 14),
            slider.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -14),
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
            detailLabel.text = "\(state) · \(speaker.id)"
        } else {
            detailLabel.text = "Unreachable · \(speaker.id)"
        }
        glassPanel.setGlowActive(speaker.isOn)
        slider.value = Float(speaker.volume ?? 0)
        slider.isEnabled = speaker.isReachable
    }

    func configurePlaceholder() {
        nameLabel.text = "Configure Sonos in Settings"
        detailLabel.text = "Enter speaker IP addresses"
        glassPanel.setGlowActive(false)
        slider.value = 0
        slider.isEnabled = false
    }

    @objc private func sliderChanged() {
        onVolumeChanged?(Int(slider.value))
    }
}
