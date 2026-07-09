import UIKit

final class DeviceTileCell: UICollectionViewCell {

    static let reuseID = "DeviceTileCell"

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let statusView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        contentView.layer.cornerRadius = 14
        contentView.layer.masksToBounds = true

        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        subtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = UIColor(white: 0.65, alpha: 1.0)
        subtitleLabel.numberOfLines = 2

        statusView.layer.cornerRadius = 5

        [titleLabel, subtitleLabel, statusView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            statusView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            statusView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            statusView.widthAnchor.constraint(equalToConstant: 10),
            statusView.heightAnchor.constraint(equalToConstant: 10),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with device: SmartDevice) {
        titleLabel.text = device.name
        subtitleLabel.text = subtitle(for: device)
        statusView.backgroundColor = device.isReachable
            ? (device.isOn ? UIColor(red: 0.25, green: 0.85, blue: 0.45, alpha: 1.0) : UIColor(white: 0.35, alpha: 1.0))
            : UIColor(red: 0.95, green: 0.35, blue: 0.30, alpha: 1.0)
    }

    func configurePlaceholder() {
        titleLabel.text = "No devices yet"
        subtitleLabel.text = "Add your Hue bridge and Sonos IPs in Settings, then pull to refresh."
        statusView.backgroundColor = UIColor(white: 0.35, alpha: 1.0)
    }

    private func subtitle(for device: SmartDevice) -> String {
        switch device.kind {
        case .light, .lightGroup:
            let label = device.kind == .lightGroup ? "Group" : ""
            let state = device.isOn ? "On" : "Off"
            if let brightness = device.brightness {
                let percent = Int((Double(brightness) / 254.0) * 100.0)
                return label.isEmpty ? "\(state) · \(percent)% brightness" : "\(label) · \(state) · \(percent)%"
            }
            return label.isEmpty ? state : "\(label) · \(state)"
        case .speaker:
            let state = device.isOn ? "Playing" : "Idle"
            if let volume = device.volume {
                return "\(state) · Volume \(volume)"
            }
            return state
        default:
            return device.isOn ? "On" : "Off"
        }
    }
}
