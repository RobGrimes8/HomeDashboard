import UIKit

/// TEMP DEBUG — full favorite dump for troubleshooting Sonos favorites parsing.
final class FavoriteDebugViewController: UIViewController {

    private let favorite: SonosFavorite
    private let index: Int
    private let speaker: SmartDevice
    private let service: DashboardService

    private let textView = UITextView()
    private let activityIndicator = UIActivityIndicatorView(style: .gray)

    init(
        favorite: SonosFavorite,
        index: Int,
        speaker: SmartDevice,
        service: DashboardService
    ) {
        self.favorite = favorite
        self.index = index
        self.speaker = speaker
        self.service = service
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Favorite #\(index)"
        view.backgroundColor = DashboardTheme.background

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Copy",
            style: .plain,
            target: self,
            action: #selector(copyTapped)
        )

        textView.font = UIFont(name: "Menlo-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11)
        textView.textColor = DashboardTheme.textPrimary
        textView.backgroundColor = UIColor(white: 1.0, alpha: 0.06)
        textView.isEditable = false
        textView.alwaysBounceVertical = true
        textView.text = favorite.debugSummary

        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()

        [textView, activityIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])

        loadBrowseDebug()
    }

    private func loadBrowseDebug() {
        let browseID = favorite.objectID ?? favorite.itemID
        guard !browseID.isEmpty else {
            appendBrowseSection("(no objectID/itemID to browse)")
            activityIndicator.stopAnimating()
            return
        }

        service.fetchSpeakerFavoriteBrowseDebug(speaker, browseID: browseID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.activityIndicator.stopAnimating()
                switch result {
                case .failure(let error):
                    self.appendBrowseSection("BROWSE FAILED: \(error.localizedDescription)")
                case .success(let xml):
                    self.appendBrowseSection(xml)
                }
            }
        }
    }

    private func appendBrowseSection(_ text: String) {
        textView.text = (textView.text ?? "") + "\n\n=== SONOS BROWSE (live) ===\n" + text
        let end = NSRange(location: (textView.text as NSString).length - 1, length: 1)
        textView.scrollRangeToVisible(end)
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = textView.text
        let alert = UIAlertController(title: "Copied", message: "Favorite debug text copied to clipboard.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
