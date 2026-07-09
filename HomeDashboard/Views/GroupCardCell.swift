import UIKit

final class GroupCardCell: UICollectionViewCell {

    static let reuseID = "GroupCardCell"

    var onTurnOn: (() -> Void)?
    var onTurnOff: (() -> Void)?

    private let shadowView = UIView()
    private let cardView = UIView()
    private let headerView = UIView()
    private let iconLabel = UILabel()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let onButton = UIButton(type: .system)
    private let offButton = UIButton(type: .system)
    private var deviceIsOn = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear

        shadowView.backgroundColor = .clear
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.22
        shadowView.layer.shadowRadius = 10
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 4)

        cardView.backgroundColor = DashboardTheme.cardBottom
        cardView.layer.cornerRadius = 18
        cardView.layer.masksToBounds = true

        headerView.clipsToBounds = true

        iconLabel.font = UIFont.systemFont(ofSize: 40)
        iconLabel.textAlignment = .center

        nameLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        nameLabel.textColor = DashboardTheme.cardTitle
        nameLabel.numberOfLines = 2

        detailLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = DashboardTheme.cardSubtitle

        onButton.addTarget(self, action: #selector(onTapped), for: .touchUpInside)
        offButton.addTarget(self, action: #selector(offTapped), for: .touchUpInside)

        [shadowView, cardView, headerView, iconLabel, nameLabel, detailLabel, onButton, offButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        contentView.addSubview(shadowView)
        shadowView.addSubview(cardView)
        cardView.addSubview(headerView)
        headerView.addSubview(iconLabel)
        cardView.addSubview(nameLabel)
        cardView.addSubview(detailLabel)
        cardView.addSubview(onButton)
        cardView.addSubview(offButton)

        NSLayoutConstraint.activate([
            shadowView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            shadowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            shadowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            shadowView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            cardView.topAnchor.constraint(equalTo: shadowView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor),

            headerView.topAnchor.constraint(equalTo: cardView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 100),

            iconLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),

            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            onButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            onButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),
            onButton.heightAnchor.constraint(equalToConstant: 44),

            offButton.leadingAnchor.constraint(equalTo: onButton.trailingAnchor, constant: 10),
            offButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            offButton.bottomAnchor.constraint(equalTo: onButton.bottomAnchor),
            offButton.heightAnchor.constraint(equalTo: onButton.heightAnchor),
            offButton.widthAnchor.constraint(equalTo: onButton.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shadowView.layer.shadowPath = UIBezierPath(roundedRect: shadowView.bounds, cornerRadius: 18).cgPath
        DashboardTheme.applyGradient(to: headerView)
    }

    func configure(with device: SmartDevice) {
        deviceIsOn = device.isOn
        nameLabel.text = device.name
        detailLabel.text = device.room ?? "Light group"
        iconLabel.text = DashboardTheme.roomIcon(for: device.name)
        updateButtons()
        onButton.isEnabled = device.isReachable
        offButton.isEnabled = device.isReachable
    }

    func configurePlaceholder() {
        deviceIsOn = false
        nameLabel.text = "No groups"
        detailLabel.text = "Add rooms in Hue or Settings"
        iconLabel.text = "🏠"
        updateButtons()
        onButton.isEnabled = false
        offButton.isEnabled = false
    }

    func setPoweredOn(_ isOn: Bool) {
        deviceIsOn = isOn
        updateButtons()
    }

    private func updateButtons() {
        style(button: onButton, title: "ON", active: deviceIsOn)
        style(button: offButton, title: "OFF", active: !deviceIsOn)
    }

    private func style(button: UIButton, title: String, active: Bool) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true

        if active {
            button.backgroundColor = title == "ON" ? DashboardTheme.onButton : DashboardTheme.offButton
            button.setTitleColor(.white, for: .normal)
        } else {
            button.backgroundColor = UIColor(white: 0.90, alpha: 1.0)
            button.setTitleColor(DashboardTheme.cardSubtitle, for: .normal)
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
