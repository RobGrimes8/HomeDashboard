import UIKit

final class LightControlCell: UITableViewCell {

    static let reuseID = "LightControlCell"

    var onToggle: (() -> Void)?
    var onBrightnessChanged: ((Int) -> Void)?

    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let toggleSwitch = UISwitch()
    private let slider = UISlider()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(white: 0.10, alpha: 1.0)
        selectionStyle = .none

        nameLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        nameLabel.textColor = .white

        detailLabel.font = UIFont.systemFont(ofSize: 13)
        detailLabel.textColor = UIColor(white: 0.65, alpha: 1.0)

        toggleSwitch.onTintColor = UIColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1.0)
        toggleSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)

        slider.minimumValue = 0
        slider.maximumValue = 254
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        [nameLabel, detailLabel, toggleSwitch, slider].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -12),

            toggleSwitch.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            toggleSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

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

    func configure(with light: SmartDevice) {
        nameLabel.text = light.name
        if light.kind == .lightGroup {
            detailLabel.text = light.room ?? "Light group"
        } else {
            detailLabel.text = light.isReachable ? "Local Hue light" : "Unreachable"
        }
        toggleSwitch.isOn = light.isOn
        slider.value = Float(light.brightness ?? 0)
        slider.isEnabled = light.isReachable
        toggleSwitch.isEnabled = light.isReachable
    }

    func configurePlaceholder(title: String, detail: String) {
        nameLabel.text = title
        detailLabel.text = detail
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
    }

    @objc private func sliderChanged() {
        onBrightnessChanged?(Int(slider.value))
    }
}
