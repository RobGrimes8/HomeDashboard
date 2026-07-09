import UIKit

final class GroupCardCell: UICollectionViewCell {

    static let reuseID = "GroupCardCell"

    var onTurnOn: (() -> Void)?
    var onTurnOff: (() -> Void)?

    private let glassPanel = GlassPanelView()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let iconLabel = UILabel()
    private let onButton = UIButton(type: .system)
    private let offButton = UIButton(type: .system)
    private var deviceIsOn = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear

        glassPanel.cornerRadius = 16

        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        nameLabel.textColor = DashboardTheme.textPrimary
        nameLabel.numberOfLines = 2

        detailLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        detailLabel.textColor = DashboardTheme.textSecondary

        iconLabel.font = UIFont.systemFont(ofSize: 44)
        iconLabel.textAlignment = .center

        onButton.addTarget(self, action: #selector(onTapped), for: .touchUpInside)
        offButton.addTarget(self, action: #selector(offTapped), for: .touchUpInside)

        [glassPanel, nameLabel, detailLabel, iconLabel, onButton, offButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        contentView.addSubview(glassPanel)
        glassPanel.addSubview(nameLabel)
        glassPanel.addSubview(detailLabel)
        glassPanel.addSubview(iconLabel)
        glassPanel.addSubview(onButton)
        glassPanel.addSubview(offButton)

        NSLayoutConstraint.activate([
            glassPanel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            glassPanel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            glassPanel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            glassPanel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            nameLabel.topAnchor.constraint(equalTo: glassPanel.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: glassPanel.leadingAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(equalTo: onButton.leadingAnchor, constant: -10),

            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            onButton.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -12),
            onButton.topAnchor.constraint(equalTo: glassPanel.topAnchor, constant: 36),
            onButton.widthAnchor.constraint(equalToConstant: 44),
            onButton.heightAnchor.constraint(equalToConstant: 44),

            offButton.trailingAnchor.constraint(equalTo: onButton.trailingAnchor),
            offButton.topAnchor.constraint(equalTo: onButton.bottomAnchor, constant: 10),
            offButton.widthAnchor.constraint(equalToConstant: 44),
            offButton.heightAnchor.constraint(equalToConstant: 44),

            iconLabel.leadingAnchor.constraint(equalTo: glassPanel.leadingAnchor, constant: 18),
            iconLabel.bottomAnchor.constraint(equalTo: glassPanel.bottomAnchor, constant: -18)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with device: SmartDevice) {
        deviceIsOn = device.isOn
        nameLabel.text = device.name
        detailLabel.text = statusText(for: device)
        iconLabel.text = DashboardTheme.roomIcon(for: device.name)
        glassPanel.panelTint = DashboardTheme.roomTint(for: device.name)
        glassPanel.setGlowActive(device.isOn)
        updateButtons()
        onButton.isEnabled = device.isReachable
        offButton.isEnabled = device.isReachable
    }

    func configurePlaceholder() {
        deviceIsOn = false
        nameLabel.text = "No rooms"
        detailLabel.text = "Add rooms in Hue or Settings"
        iconLabel.text = "🏠"
        glassPanel.panelTint = DashboardTheme.glassPurple
        glassPanel.setGlowActive(false)
        updateButtons()
        onButton.isEnabled = false
        offButton.isEnabled = false
    }

    func setPoweredOn(_ isOn: Bool) {
        deviceIsOn = isOn
        glassPanel.setGlowActive(isOn)
        updateButtons()
    }

    private func statusText(for device: SmartDevice) -> String {
        let state = device.isOn ? "On" : "Off"
        if let brightness = device.brightness, device.isOn {
            let percent = Int((Double(brightness) / 254.0) * 100.0)
            return "\(state) · \(percent)%"
        }
        return state
    }

    private func updateButtons() {
        styleCircle(button: onButton, symbol: "💡", active: deviceIsOn)
        styleCircle(button: offButton, symbol: "🌙", active: !deviceIsOn)
    }

    private func styleCircle(button: UIButton, symbol: String, active: Bool) {
        button.setTitle(symbol, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        button.layer.cornerRadius = 22
        button.layer.masksToBounds = true
        button.layer.borderWidth = 1

        if active {
            button.backgroundColor = DashboardTheme.accent.withAlphaComponent(0.55)
            button.layer.borderColor = DashboardTheme.onGlow.withAlphaComponent(0.6).cgColor
            button.alpha = 1.0
        } else {
            button.backgroundColor = UIColor(white: 1.0, alpha: 0.08)
            button.layer.borderColor = DashboardTheme.glassBorder.cgColor
            button.alpha = 0.75
        }
    }

    @objc private func onTapped() {
        guard !deviceIsOn else { return }
        onTurnOn?()
    }

    @objc private func offTapped() {
        guard deviceIsOn else { return }
        onTurnOff?()
    }
}
