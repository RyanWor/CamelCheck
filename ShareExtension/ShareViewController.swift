import UIKit
import SafariServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    // MARK: - UI
    private let cardView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let cancelButton = UIButton(type: .system)

    private let accentOrange = UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        processSharedItems()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)

        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        view.addGestureRecognizer(tap)

        // Card
        cardView.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        cardView.layer.cornerRadius = 18
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.5
        cardView.layer.shadowRadius = 20
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        // Orange top bar
        let bar = UIView()
        bar.backgroundColor = accentOrange
        bar.layer.cornerRadius = 2
        bar.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(bar)

        // Icon
        let cfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        iconImageView.image = UIImage(systemName: "chart.line.uptrend.xyaxis", withConfiguration: cfg)
        iconImageView.tintColor = accentOrange
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(iconImageView)

        // Title
        titleLabel.text = "CamelCheck"
        titleLabel.font = UIFont(name: "Georgia-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        // Status
        statusLabel.text = "Analyzing link..."
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = UIColor(white: 0.55, alpha: 1)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 3
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(statusLabel)

        // Spinner
        spinner.color = accentOrange
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(spinner)

        // Cancel
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(white: 0.4, alpha: 1), for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 280),

            bar.topAnchor.constraint(equalTo: cardView.topAnchor),
            bar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 40),
            bar.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -40),
            bar.heightAnchor.constraint(equalToConstant: 3),

            iconImageView.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 24),
            iconImageView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            spinner.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            spinner.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            cancelButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            cancelButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - Processing

    private func processSharedItems() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            showError("No content received")
            return
        }

        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier

        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(urlType) {
                attachment.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] item, _ in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            self?.handleURL(url)
                        } else if let str = item as? String, let url = URL(string: str) {
                            self?.handleURL(url)
                        } else {
                            self?.showError("Couldn't read the shared URL")
                        }
                    }
                }
                return
            } else if attachment.hasItemConformingToTypeIdentifier(textType) {
                attachment.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] item, _ in
                    DispatchQueue.main.async {
                        if let text = item as? String, let url = self?.firstAmazonURL(in: text) {
                            self?.handleURL(url)
                        } else {
                            self?.showError("No Amazon URL found in shared text")
                        }
                    }
                }
                return
            }
        }
        showError("Unsupported content type")
    }

    private func handleURL(_ url: URL) {
        updateStatus("Analyzing URL...")

        if AmazonURLParser.isShortURL(url) {
            updateStatus("Resolving short link...")
            AmazonURLParser.resolveShortURL(url) { [weak self] resolved in
                DispatchQueue.main.async {
                    if let resolved = resolved {
                        self?.handleURL(resolved)
                    } else {
                        // Can't resolve — search by original URL string
                        let q = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        self?.openInSafariVC(urlString: "https://camelcamelcamel.com/search?sq=\(q)")
                    }
                }
            }
            return
        }

        if let asin = AmazonURLParser.extractASIN(from: url) {
            updateStatus("Found ASIN: \(asin)")
            openInSafariVC(urlString: "https://camelcamelcamel.com/product/\(asin)")
        } else if AmazonURLParser.isAmazonURL(url) {
            updateStatus("Searching CamelCamelCamel...")
            let q = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            openInSafariVC(urlString: "https://camelcamelcamel.com/search?sq=\(q)")
        } else {
            showError("Doesn't look like an Amazon product URL.\n\(url.host ?? url.absoluteString)")
        }
    }

    // MARK: - Open in SFSafariViewController (works from any app, no freeze)

    private func openInSafariVC(urlString: String) {
        guard let url = URL(string: urlString) else {
            showError("Couldn't build CamelCamelCamel URL")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Hide the loading card
            self.cardView.isHidden = true
            self.view.backgroundColor = .clear

            let safari = SFSafariViewController(url: url)
            safari.preferredControlTintColor = UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1)
            safari.delegate = self

            // Present safari over the extension's view controller
            self.present(safari, animated: true)
        }
    }

    // MARK: - Helpers

    private func firstAmazonURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector?.matches(in: text, range: range) ?? []
        for match in matches {
            if let url = match.url, AmazonURLParser.isAmazonURL(url) { return url }
        }
        return matches.first?.url
    }

    private func updateStatus(_ msg: String) {
        DispatchQueue.main.async { self.statusLabel.text = msg }
    }

    private func showError(_ msg: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            self.statusLabel.text = msg
            self.statusLabel.textColor = UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1)
        }
    }

    @objc private func cancelTapped() {
        extensionContext?.cancelRequest(withError: NSError(domain: "CamelChecker", code: 0))
    }

    @objc private func backgroundTapped() {
        cancelTapped()
    }
}

// MARK: - SFSafariViewControllerDelegate
extension ShareViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // User tapped Done — dismiss the extension cleanly
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
