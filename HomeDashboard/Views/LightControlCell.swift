import UIKit

final class LightControlCell: UITableViewCell {

    static let reuseID = "LightControlCell"

    var onToggle: (() -> Void)?
    var onBrightnessChanged: ((Int) -> Void)?

    private let glassPanel = GlassPanelView()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let toggleSwitch = UISwitch()
    private let slider = UISlider()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        glassPanel.cornerRadius = 14
        glassPanel.panelTint = DashboardTheme.glassPurple

        nameLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        nameLabel.textColor = DashboardTheme.textPrimary

        detailLabel.font = UIFont.systemFont(ofSize: 13)
        detailLabel.textColor = DashboardTheme.textSecondary

        toggleSwitch.onTintColor = DashboardTheme.accent
        toggleSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)

        slider.minimumValue = 0
        slider.maximumValue = 254
        slider.minimumTrackTintColor = DashboardTheme.accent
        slider.maximumTrackTintColor = UIColor(white: 1.0, alpha: 0.18)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        [glassPanel, nameLabel, detailLabel, toggleSwitch, slider].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        contentView.addSubview(glassPanel)
        glassPanel.addSubview(nameLabel)
        glassPanel.addSubview(detailLabel)
        glassPanel.addSubview(toggleSwitch)
        glassPanel.addSubview(slider)

        NSLayoutConstraint.activate([
            glassPanel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            glassPanel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            glassPanel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            glassPanel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            nameLabel.topAnchor.constraint(equalTo: glassPanel.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: glassPanel.leadingAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -12),

            toggleSwitch.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            toggleSwitch.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -14),

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

    func configure(with light: SmartDevice) {
        nameLabel.text = light.name
        if light.kind == .lightGroup {
            detailLabel.text = light.room ?? "Light group"
        } else {
            detailLabel.text = light.isReachable ? "Local Hue light" : "Unreachable"
        }
        glassPanel.panelTint = DashboardTheme.roomTint(for: light.name)
        glassPanel.setGlowActive(light.isOn)
        toggleSwitch.isOn = light.isOn
        slider.value = Float(light.brightness ?? 0)
        slider.isEnabled = light.isReachable
        toggleSwitch.isEnabled = light.isReachable
    }

    func configurePlaceholder(title: String, detail: String) {
        nameLabel.text = title
        detailLabel.text = detail
        glassPanel.setGlowActive(false)
        toggleSwitch.isOn = false
        slider.value = 0
        slider.isEnabled = false
        toggleSwitch.isEnabled = false
    }

    func configurePlaceholder() {
        configurePlaceholder(
            title: "Configure Hue in Settings",
            detail: "Enter bridge IP and API username"
        )
    }

    @objc private func toggleChanged() {
        onToggle?()
    }

    func setToggle(isOn: Bool, animated: Bool = true) {
        toggleSwitch.setOn(isOn, animated: animated)
        glassPanel.setGlowActive(isOn)
    }

    @objc private func sliderChanged() {
        onBrightnessChanged?(Int(slider.value))
    }
}
