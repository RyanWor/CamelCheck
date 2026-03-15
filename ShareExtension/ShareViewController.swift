import UIKit
import SafariServices
import UniformTypeIdentifiers
import OSLog

private let logger = Logger(subsystem: "com.yourname.camelchecker.ShareExtension", category: "ShareViewController")

class ShareViewController: UIViewController {

    private let accentOrange = UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1)
    private let cardView     = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel   = UILabel()
    private let statusLabel  = UILabel()
    private let spinner      = UIActivityIndicatorView(style: .large)
    private let cancelButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        processSharedItems()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        view.addGestureRecognizer(tap)

        cardView.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        cardView.layer.cornerRadius = 20
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.5
        cardView.layer.shadowRadius = 24
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.isUserInteractionEnabled = true
        view.addSubview(cardView)

        let bar = UIView()
        bar.backgroundColor = accentOrange
        bar.layer.cornerRadius = 2
        bar.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(bar)

        let cfg = UIImage.SymbolConfiguration(pointSize: 36, weight: .bold)
        iconImageView.image = UIImage(systemName: "chart.line.uptrend.xyaxis", withConfiguration: cfg)
        iconImageView.tintColor = accentOrange
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(iconImageView)

        titleLabel.text = "CamelCheck"
        titleLabel.font = UIFont(name: "Georgia-Bold", size: 22) ?? .boldSystemFont(ofSize: 22)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        statusLabel.text = "Looking up price history..."
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = UIColor(white: 0.6, alpha: 1)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 3
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(statusLabel)

        spinner.color = accentOrange
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(spinner)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(white: 0.4, alpha: 1), for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 300),

            bar.topAnchor.constraint(equalTo: cardView.topAnchor),
            bar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 30),
            bar.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -30),
            bar.heightAnchor.constraint(equalToConstant: 3),

            iconImageView.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 28),
            iconImageView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            spinner.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            spinner.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            cancelButton.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 20),
            cancelButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
        ])
    }

    private func processSharedItems() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            logger.error("No extension input items received")
            showError("No content received")
            return
        }

        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
                    if let error = error {
                        logger.error("Failed to load URL item: \(error.localizedDescription)")
                    }
                    DispatchQueue.main.async {
                        if let url = item as? URL { self?.handleURL(url) }
                        else if let str = item as? String, let url = URL(string: str) { self?.handleURL(url) }
                        else { self?.showError("Couldn't read the shared URL") }
                    }
                }
                return
            } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, error in
                    if let error = error {
                        logger.error("Failed to load text item: \(error.localizedDescription)")
                    }
                    DispatchQueue.main.async {
                        if let text = item as? String,
                           let url = (try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue))?
                               .matches(in: text, range: NSRange(text.startIndex..., in: text)).first?.url {
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
        // Validate before proceeding
        switch AmazonURLParser.validate(url.absoluteString) {
        case .failure(let error):
            logger.warning("URL validation failed: \(error.localizedDescription)")
            showError("Invalid URL: \(error.errorDescription ?? "Unknown")")
            return
        case .success:
            break
        }

        logger.info("Processing URL: \(url.absoluteString)")
        updateStatus("Analyzing URL...")

        if AmazonURLParser.isShortURL(url) {
            updateStatus("Resolving short link...")
            AmazonURLParser.resolveShortURL(url) { [weak self] resolvedURL in
                DispatchQueue.main.async {
                    if let resolved = resolvedURL {
                        self?.handleURL(resolved)
                    } else {
                        // Can't resolve — fall back to CCC search
                        if let searchURL = AmazonURLParser.camelSearchURL(for: url.absoluteString) {
                            self?.openInSafariVC(searchURL)
                        } else {
                            self?.showError("Couldn't resolve that short link.")
                        }
                    }
                }
            }
            return
        }

        if let asin = AmazonURLParser.extractASIN(from: url) {
            updateStatus("Found ASIN: \(asin)")
            if let camelURL = AmazonURLParser.camelURL(for: asin) {
                openInSafariVC(camelURL)
            }
        } else if AmazonURLParser.isAmazonURL(url) {
            updateStatus("Searching CamelCamelCamel...")
            if let searchURL = AmazonURLParser.camelSearchURL(for: url.absoluteString) {
                openInSafariVC(searchURL)
            }
        } else {
            logger.warning("Not an Amazon URL: \(url.host ?? url.absoluteString)")
            showError("This doesn't look like an Amazon product URL.\n\(url.host ?? url.absoluteString)")
        }
    }

    private func openInSafariVC(_ url: URL) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cardView.isHidden = true
            self.view.backgroundColor = .clear
            let safari = SFSafariViewController(url: url)
            safari.preferredControlTintColor = self.accentOrange
            safari.delegate = self
            self.present(safari, animated: true)
        }
    }

    private func updateStatus(_ msg: String) {
        DispatchQueue.main.async { self.statusLabel.text = msg }
    }

    private func showError(_ msg: String) {
        DispatchQueue.main.async { [weak self] in
            self?.spinner.stopAnimating()
            self?.statusLabel.text = msg
            self?.statusLabel.textColor = UIColor(red: 1, green: 0.27, blue: 0.27, alpha: 1)
        }
    }

    @objc private func cancelTapped() {
        extensionContext?.cancelRequest(withError: NSError(domain: "CamelChecker", code: 0))
    }
}

extension ShareViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
