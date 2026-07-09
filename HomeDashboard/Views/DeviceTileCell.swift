import UIKit

final class DeviceTileCell: UICollectionViewCell {

    static let reuseID = "DeviceTileCell"

    private let glassPanel = GlassPanelView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let statusView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear

        glassPanel.cornerRadius = 14
        glassPanel.panelTint = DashboardTheme.glassBlue

        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = DashboardTheme.textPrimary
        titleLabel.numberOfLines = 2

        subtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = DashboardTheme.textSecondary
        subtitleLabel.numberOfLines = 2

        statusView.layer.cornerRadius = 5

        [glassPanel, titleLabel, subtitleLabel, statusView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        contentView.addSubview(glassPanel)
        glassPanel.addSubview(statusView)
        glassPanel.addSubview(titleLabel)
        glassPanel.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            glassPanel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            glassPanel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            glassPanel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            glassPanel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),

            statusView.topAnchor.constraint(equalTo: glassPanel.topAnchor, constant: 14),
            statusView.leadingAnchor.constraint(equalTo: glassPanel.leadingAnchor, constant: 14),
            statusView.widthAnchor.constraint(equalToConstant: 10),
            statusView.heightAnchor.constraint(equalToConstant: 10),

            titleLabel.topAnchor.constraint(equalTo: glassPanel.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: glassPanel.leadingAnchor, constant: 14),
            subtitleLabel.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with device: SmartDevice) {
        titleLabel.text = device.name
        subtitleLabel.text = subtitle(for: device)
        glassPanel.panelTint = tint(for: device)
        glassPanel.setGlowActive(device.isOn)
        statusView.backgroundColor = device.isReachable
            ? (device.isOn ? DashboardTheme.onGlow : DashboardTheme.offMuted)
            : UIColor(red: 0.95, green: 0.35, blue: 0.30, alpha: 1.0)
    }

    func configurePlaceholder() {
        titleLabel.text = "No devices yet"
        subtitleLabel.text = "Add your Hue bridge and Sonos IPs in Settings, then pull to refresh."
        glassPanel.panelTint = DashboardTheme.glassPurple
        glassPanel.setGlowActive(false)
        statusView.backgroundColor = DashboardTheme.offMuted
    }

    private func tint(for device: SmartDevice) -> UIColor {
        switch device.kind {
        case .light, .lightGroup:
            return DashboardTheme.roomTint(for: device.name)
        case .speaker:
            return DashboardTheme.glassTeal
        default:
            return DashboardTheme.glassBlue
        }
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
