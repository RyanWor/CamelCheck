import Foundation
import OSLog

private let logger = Logger(subsystem: "com.yourname.camelchecker", category: "AmazonURLParser")

// MARK: - External URL constants
// If CamelCamelCamel changes their URL structure, update here only
enum ExternalURLs {
    static let camelProduct = "https://camelcamelcamel.com/product/"
    static let camelSearch  = "https://camelcamelcamel.com/search?sq="
}

/// Validation errors for URL checking
enum URLValidationError: LocalizedError {
    case empty
    case malformed
    case invalidScheme
    case missingHost

    var errorDescription: String? {
        switch self {
        case .empty:         return "URL is empty"
        case .malformed:     return "Not a valid URL"
        case .invalidScheme: return "URL must start with http:// or https://"
        case .missingHost:   return "URL has no host"
        }
    }
}

/// Extracts Amazon ASIN codes from various URL formats
enum AmazonURLParser {

    static func isAmazonURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("amazon.") || host.contains("amzn.") || host == "a.co"
    }

    static func isShortURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "amzn.to" || host == "amzn.com" || host == "a.co"
    }

    /// Validates that a URL string has a proper scheme and host
    static func validate(_ urlString: String) -> Result<URL, URLValidationError> {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard let url = URL(string: trimmed) else { return .failure(.malformed) }
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return .failure(.invalidScheme)
        }
        guard let host = url.host, !host.isEmpty else { return .failure(.missingHost) }
        return .success(url)
    }

    /// Builds the CamelCamelCamel product URL for a given ASIN
    static func camelURL(for asin: String) -> URL? {
        URL(string: "\(ExternalURLs.camelProduct)\(asin)")
    }

    /// Builds the CamelCamelCamel search URL for a given query string
    static func camelSearchURL(for query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "\(ExternalURLs.camelSearch)\(encoded)")
    }

    /// Attempts to extract an ASIN from an Amazon URL string
    static func extractASIN(from urlString: String) -> String? {
        let cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: cleaned) else { return nil }
        return extractASIN(from: url)
    }

    static func extractASIN(from url: URL) -> String? {
        if isShortURL(url) { return nil }

        let urlString = url.absoluteString
        let dpPatterns = [
            #"/dp/([A-Z0-9]{10})"#,
            #"/gp/product/([A-Z0-9]{10})"#,
            #"/ASIN/([A-Z0-9]{10})"#,
            #"/product/([A-Z0-9]{10})"#,
            #"/exec/obidos/ASIN/([A-Z0-9]{10})"#,
        ]

        for pattern in dpPatterns {
            if let asin = matchFirst(pattern: pattern, in: urlString) {
                logger.info("Extracted ASIN \(asin) from URL")
                return asin
            }
        }

        if let components = URLComponents(string: urlString),
           let asinParam = components.queryItems?.first(where: { $0.name.lowercased() == "asin" }),
           let value = asinParam.value,
           isValidASIN(value) {
            logger.info("Extracted ASIN \(value) from query param")
            return value
        }

        logger.warning("No ASIN found in URL: \(urlString)")
        return nil
    }

    static func isValidASIN(_ string: String) -> Bool {
        let asinRegex = try? NSRegularExpression(pattern: #"^[A-Z0-9]{10}$"#)
        let range = NSRange(string.startIndex..., in: string)
        return asinRegex?.firstMatch(in: string, range: range) != nil
    }

    private static func matchFirst(pattern: String, in string: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let nsString = string as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: string, range: range),
              match.numberOfRanges > 1 else { return nil }
        let captureRange = match.range(at: 1)
        guard captureRange.location != NSNotFound else { return nil }
        let candidate = nsString.substring(with: captureRange).uppercased()
        return isValidASIN(candidate) ? candidate : nil
    }

    /// Resolve a shortened Amazon URL by following the redirect
    static func resolveShortURL(_ url: URL, completion: @escaping (URL?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8

        let delegate = RedirectCaptureDelegate { redirectURL in
            if let redirectURL = redirectURL {
                logger.info("Resolved short URL to: \(redirectURL.absoluteString)")
            } else {
                logger.warning("Failed to resolve short URL: \(url.absoluteString)")
            }
            completion(redirectURL)
        }
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: .main)
        session.dataTask(with: request).resume()
    }
}

// MARK: - Redirect capture delegate
private class RedirectCaptureDelegate: NSObject, URLSessionTaskDelegate {
    let handler: (URL?) -> Void
    private var handled = false

    init(handler: @escaping (URL?) -> Void) { self.handler = handler }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        guard !handled else { completionHandler(nil); return }
        handled = true
        handler(request.url)
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !handled else { return }
        handled = true
        if let error = error {
            logger.error("Short URL resolution error: \(error.localizedDescription)")
        }
        handler(nil)
    }
}
