import UIKit

final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    private var config = AppConfig.load()
    private var draftHueIP = ""
    private var draftHueUser = ""
    private var draftSonosIPs = ""
    private var draftRefresh = ""

    private enum Row: Int, CaseIterable {
        case hueIP
        case hueUser
        case sonosIPs
        case refresh
        case testHue
        case save
        case help
    }

    private let tableView = UITableView(frame: .zero, style: .grouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = UIColor(white: 0.06, alpha: 1.0)

        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.barTintColor = UIColor(white: 0.08, alpha: 1.0)
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]

        tableView.backgroundColor = UIColor(white: 0.06, alpha: 1.0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SettingsFieldCell.self, forCellReuseIdentifier: SettingsFieldCell.reuseID)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "action-cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        reloadDraftsFromConfig()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadDraftsFromConfig()
        tableView.reloadData()
    }

    private func reloadDraftsFromConfig() {
        config = AppConfig.load()
        draftHueIP = config.hueBridgeIP
        draftHueUser = config.hueUsername
        draftSonosIPs = config.sonosSpeakerIPs.joined(separator: ", ")
        draftRefresh = String(Int(config.refreshIntervalSeconds))
    }

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.allCases.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Local Network Devices"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if config.isHueConfigured {
            let suffix = String(config.hueUsername.suffix(4))
            return "Saved Hue user ends with …\(suffix). Use Test Hue Connection before saving if lights fail to load."
        }
        return "Enter your Hue bridge IP and API username, then tap Test Hue Connection."
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let row = Row(rawValue: indexPath.row) else { return 44 }
        switch row {
        case .hueIP, .hueUser, .sonosIPs, .refresh:
            return 88
        default:
            return 44
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let row = Row(rawValue: indexPath.row) else {
            return UITableViewCell()
        }

        switch row {
        case .hueIP, .hueUser, .sonosIPs, .refresh:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsFieldCell.reuseID, for: indexPath) as? SettingsFieldCell else {
                return UITableViewCell()
            }

            switch row {
            case .hueIP:
                cell.configure(
                    title: "Hue Bridge IP",
                    value: draftHueIP,
                    tag: 1,
                    keyboard: .decimalPad,
                    wide: false,
                    delegate: self
                )
            case .hueUser:
                cell.configure(
                    title: "Hue API Username",
                    value: draftHueUser,
                    tag: 2,
                    keyboard: .asciiCapable,
                    wide: true,
                    delegate: self
                )
            case .sonosIPs:
                cell.configure(
                    title: "Sonos IPs (comma-separated)",
                    value: draftSonosIPs,
                    tag: 3,
                    keyboard: .asciiCapable,
                    wide: true,
                    delegate: self
                )
            case .refresh:
                cell.configure(
                    title: "Refresh interval (seconds)",
                    value: draftRefresh,
                    tag: 4,
                    keyboard: .numberPad,
                    wide: false,
                    delegate: self
                )
            default:
                break
            }

            return cell

        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "action-cell", for: indexPath)
            cell.backgroundColor = UIColor(white: 0.10, alpha: 1.0)
            cell.textLabel?.textColor = .white
            cell.accessoryType = .none
            cell.accessoryView = nil
            cell.selectionStyle = .default

            switch row {
            case .testHue:
                cell.textLabel?.text = "Test Hue Connection"
                cell.textLabel?.textAlignment = .center
                cell.textLabel?.textColor = UIColor(red: 0.35, green: 0.80, blue: 0.45, alpha: 1.0)
            case .save:
                cell.textLabel?.text = "Save Settings"
                cell.textLabel?.textAlignment = .center
                cell.textLabel?.textColor = UIColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1.0)
            case .help:
                cell.textLabel?.text = "Setup Help"
                cell.textLabel?.textAlignment = .left
                cell.textLabel?.textColor = .white
                cell.accessoryType = .disclosureIndicator
            default:
                break
            }

            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = Row(rawValue: indexPath.row) else { return }

        view.endEditing(true)

        switch row {
        case .testHue:
            testHueConnection()
        case .save:
            saveSettings()
        case .help:
            showHelp()
        default:
            break
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        updateDraft(from: textField)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        updateDraft(from: textField)
        textField.resignFirstResponder()
        return true
    }

    private func updateDraft(from textField: UITextField) {
        switch textField.tag {
        case 1: draftHueIP = textField.text ?? ""
        case 2: draftHueUser = textField.text ?? ""
        case 3: draftSonosIPs = textField.text ?? ""
        case 4: draftRefresh = textField.text ?? ""
        default: break
        }
    }

    private func currentDraftConfig() -> AppConfig {
        let sonosIPs = draftSonosIPs
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return AppConfig(
            hueBridgeIP: draftHueIP,
            hueUsername: draftHueUser,
            sonosSpeakerIPs: sonosIPs,
            refreshIntervalSeconds: TimeInterval(draftRefresh) ?? config.refreshIntervalSeconds,
            requestTimeoutSeconds: config.requestTimeoutSeconds
        ).sanitized()
    }

    private func testHueConnection() {
        let draft = currentDraftConfig()
        guard draft.isHueConfigured else {
            presentAlert(title: "Hue Not Configured", message: "Enter bridge IP and API username first.")
            return
        }

        let client = LocalHTTPClient(timeout: draft.requestTimeoutSeconds)
        let service = LightsService(client: client, config: draft)

        service.fetchLights { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let lights):
                    self?.presentAlert(
                        title: "Hue Connected",
                        message: "Found \(lights.count) light(s). Tap Save Settings, then open the Lights tab."
                    )
                case .failure(let error):
                    self?.presentAlert(
                        title: "Hue Connection Failed",
                        message: "\(error.localizedDescription)\n\nUsername length: \(draft.hueUsername.count) characters."
                    )
                }
            }
        }
    }

    private func saveSettings() {
        let draft = currentDraftConfig()

        guard !draft.hueBridgeIP.isEmpty, !draft.hueUsername.isEmpty else {
            presentAlert(title: "Missing Values", message: "Fill in Hue bridge IP and API username before saving.")
            return
        }

        config = draft

        guard config.saveToDocuments() else {
            presentAlert(title: "Save Failed", message: "Could not write Config.json to Documents.")
            return
        }

        let reloaded = AppConfig.load()
        let suffix = String(reloaded.hueUsername.suffix(4))
        presentAlert(
            title: "Saved",
            message: "Hue user ends with …\(suffix). Open the Lights tab and tap refresh."
        )
        reloadDraftsFromConfig()
    }

    private func showHelp() {
        let message = """
        Hue Bridge:
        1. Find bridge IP in your router or Hue app.
        2. Create an API username by POSTing to http://<bridge-ip>/api with body {"devicetype":"HomeDashboard#iPad"}.
        3. Press the bridge button when prompted, then copy the username.

        Sonos:
        1. Find each speaker IP in your router admin page.
        2. Enter comma-separated IPs (e.g. 192.168.1.101, 192.168.1.102).

        Free Apple Developer account:
        Re-sign the app in Xcode every 7 days (Product → Run on your iPad).
        """
        presentAlert(title: "Setup Help", message: message)
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

private final class SettingsFieldCell: UITableViewCell, UITextFieldDelegate {

    static let reuseID = "SettingsFieldCell"

    private let titleLabel = UILabel()
    private let valueField = UITextField()
    private weak var externalDelegate: UITextFieldDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(white: 0.10, alpha: 1.0)
        selectionStyle = .none

        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        valueField.textAlignment = .right
        valueField.textColor = .white
        valueField.delegate = self
        valueField.keyboardAppearance = .dark
        valueField.autocorrectionType = .no
        valueField.autocapitalizationType = .none
        valueField.returnKeyType = .done
        valueField.clearButtonMode = .whileEditing

        [titleLabel, valueField].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            valueField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            valueField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            valueField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            valueField.heightAnchor.constraint(greaterThanOrEqualToConstant: 34)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        title: String,
        value: String,
        tag: Int,
        keyboard: UIKeyboardType,
        wide: Bool,
        delegate: UITextFieldDelegate
    ) {
        titleLabel.text = title
        valueField.text = value
        valueField.tag = tag
        valueField.keyboardType = keyboard
        valueField.font = UIFont.systemFont(ofSize: wide ? 13 : 16, weight: .regular)
        externalDelegate = delegate
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        externalDelegate?.textFieldDidEndEditing?(textField)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return externalDelegate?.textFieldShouldReturn?(textField) ?? true
    }
}
