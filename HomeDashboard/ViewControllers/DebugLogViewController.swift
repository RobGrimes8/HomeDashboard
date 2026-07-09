import UIKit

final class DebugLogViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private var entries: [String] = []
    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Debug Log"
        view.backgroundColor = UIColor(white: 0.06, alpha: 1.0)

        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.barTintColor = UIColor(white: 0.08, alpha: 1.0)
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Clear",
            style: .plain,
            target: self,
            action: #selector(clearTapped)
        )

        tableView.backgroundColor = UIColor(white: 0.06, alpha: 1.0)
        tableView.separatorColor = UIColor(white: 0.18, alpha: 1.0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "log-cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        reloadEntries()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadEntries),
            name: .debugLogDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func clearTapped() {
        DebugLog.shared.clear()
        reloadEntries()
    }

    @objc private func reloadEntries() {
        entries = DebugLog.shared.allEntries()
        if entries.isEmpty {
            entries = ["No debug messages yet. Enable logging in Settings and use the app."]
        }
        tableView.reloadData()
        scrollToBottom()
    }

    private func scrollToBottom() {
        guard entries.count > 0 else { return }
        let indexPath = IndexPath(row: entries.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "log-cell", for: indexPath)
        cell.backgroundColor = UIColor(white: 0.10, alpha: 1.0)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = UIFont(name: "Menlo-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11)
        cell.textLabel?.textColor = entries[indexPath.row].contains("ERROR")
            ? UIColor(red: 1.0, green: 0.45, blue: 0.35, alpha: 1.0)
            : UIColor(white: 0.82, alpha: 1.0)
        cell.textLabel?.text = entries[indexPath.row]
        cell.selectionStyle = .none
        return cell
    }
}
