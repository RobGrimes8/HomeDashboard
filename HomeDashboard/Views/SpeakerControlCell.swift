import UIKit

final class SpeakerControlCell: UITableViewCell {

    static let reuseID = "SpeakerControlCell"

    var onVolumeChanged: ((Int) -> Void)?

    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let slider = UISlider()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(white: 0.10, alpha: 1.0)
        selectionStyle = .none

        nameLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        nameLabel.textColor = .white

        detailLabel.font = UIFont.systemFont(ofSize: 13)
        detailLabel.textColor = UIColor(white: 0.65, alpha: 1.0)

        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        [nameLabel, detailLabel, slider].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            slider.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 10),
            slider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
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
        slider.value = Float(speaker.volume ?? 0)
        slider.isEnabled = speaker.isReachable
    }

    func configurePlaceholder() {
        nameLabel.text = "Configure Sonos in Settings"
        detailLabel.text = "Enter speaker IP addresses"
        slider.value = 0
        slider.isEnabled = false
    }

    @objc private func sliderChanged() {
        onVolumeChanged?(Int(slider.value))
    }
}
