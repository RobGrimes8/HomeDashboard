import UIKit

final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    private var config = AppConfig.load()
    private var sonosIPsText = AppConfig.load().sonosSpeakerIPs.joined(separator: ", ")

    private enum Row: Int, CaseIterable {
        case hueIP
        case hueUser
        case sonosIPs
        case refresh
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
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.allCases.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Local Network Devices"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "This app never talks to the cloud. Enter the LAN IP addresses of your Hue bridge and Sonos speakers. Settings are saved on this iPad only."
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = UIColor(white: 0.10, alpha: 1.0)
        cell.textLabel?.textColor = .white
        cell.selectionStyle = .none

        guard let row = Row(rawValue: indexPath.row) else { return cell }

        switch row {
        case .hueIP:
            cell.textLabel?.text = "Hue Bridge IP"
            cell.accessoryView = makeField(text: config.hueBridgeIP, tag: 1, keyboard: .decimalPad)
        case .hueUser:
            cell.textLabel?.text = "Hue API Username"
            cell.accessoryView = makeField(text: config.hueUsername, tag: 2, keyboard: .asciiCapable)
        case .sonosIPs:
            cell.textLabel?.text = "Sonos IPs (comma-separated)"
            cell.accessoryView = makeField(text: sonosIPsText, tag: 3, keyboard: .asciiCapable)
        case .refresh:
            cell.textLabel?.text = "Refresh interval (seconds)"
            cell.accessoryView = makeField(text: String(Int(config.refreshIntervalSeconds)), tag: 4, keyboard: .numberPad)
        case .save:
            cell.textLabel?.text = "Save Settings"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = UIColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1.0)
            cell.accessoryView = nil
            cell.selectionStyle = .default
        case .help:
            cell.textLabel?.text = "Setup Help"
            cell.textLabel?.textAlignment = .left
            cell.textLabel?.textColor = .white
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = Row(rawValue: indexPath.row) else { return }

        switch row {
        case .save:
            saveSettings()
        case .help:
            showHelp()
        default:
            break
        }
    }

    private func makeField(text: String, tag: Int, keyboard: UIKeyboardType) -> UITextField {
        let field = UITextField(frame: CGRect(x: 0, y: 0, width: 180, height: 34))
        field.text = text
        field.textAlignment = .right
        field.textColor = .white
        field.tag = tag
        field.delegate = self
        field.keyboardAppearance = .dark
        field.keyboardType = keyboard
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .done
        return field
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func saveSettings() {
        view.endEditing(true)

        guard
            let hueIP = value(forTag: 1), !hueIP.isEmpty,
            let hueUser = value(forTag: 2), !hueUser.isEmpty,
            let sonosRaw = value(forTag: 3),
            let refreshRaw = value(forTag: 4), let refresh = TimeInterval(refreshRaw)
        else {
            presentAlert(title: "Missing Values", message: "Fill in all fields before saving.")
            return
        }

        let sonosIPs = sonosRaw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        config = AppConfig(
            hueBridgeIP: hueIP,
            hueUsername: hueUser,
            sonosSpeakerIPs: sonosIPs,
            refreshIntervalSeconds: refresh,
            requestTimeoutSeconds: config.requestTimeoutSeconds
        )

        if config.saveToDocuments() {
            presentAlert(title: "Saved", message: "Settings stored on this iPad.")
        } else {
            presentAlert(title: "Save Failed", message: "Could not write Config.json to Documents.")
        }
    }

    private func value(forTag tag: Int) -> String? {
        for cell in tableView.visibleCells {
            if let field = cell.accessoryView as? UITextField, field.tag == tag {
                return field.text
            }
        }
        return nil
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
