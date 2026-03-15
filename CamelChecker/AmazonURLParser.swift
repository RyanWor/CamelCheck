import Foundation

/// Extracts Amazon ASIN codes from various URL formats
/// Works with amazon.com, amazon.co.uk, amzn.to short links, a.co and more
enum AmazonURLParser {

    static func isAmazonURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("amazon.") || host.contains("amzn.") || host == "a.co"
    }

    static func isShortURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "amzn.to" || host == "amzn.com" || host == "a.co"
    }

    /// Attempts to extract an ASIN from an Amazon URL string.
    static func extractASIN(from urlString: String) -> String? {
        let cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: cleaned) else { return nil }
        return extractASIN(from: url)
    }

    static func extractASIN(from url: URL) -> String? {
        // Short links can't be parsed without resolving
        if isShortURL(url) { return nil }

        let urlString = url.absoluteString

        // 1. Path-based patterns: /dp/ASIN, /gp/product/ASIN, etc.
        let dpPatterns = [
            #"/dp/([A-Z0-9]{10})"#,
            #"/gp/product/([A-Z0-9]{10})"#,
            #"/ASIN/([A-Z0-9]{10})"#,
            #"/product/([A-Z0-9]{10})"#,
            #"/exec/obidos/ASIN/([A-Z0-9]{10})"#,
        ]

        for pattern in dpPatterns {
            if let asin = matchFirst(pattern: pattern, in: urlString) {
                return asin
            }
        }

        // 2. Query parameter: ?asin=XXXXXXXXXX
        if let components = URLComponents(string: urlString),
           let asinParam = components.queryItems?.first(where: { $0.name.lowercased() == "asin" }),
           let value = asinParam.value,
           isValidASIN(value) {
            return value
        }

        return nil
    }

    static func isValidASIN(_ string: String) -> Bool {
        let asinRegex = try? NSRegularExpression(pattern: #"^[A-Z0-9]{10}$"#)
        let range = NSRange(string.startIndex..., in: string)
        return asinRegex?.firstMatch(in: string, range: range) != nil
    }

    private static func matchFirst(pattern: String, in string: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let nsString = string as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: string, range: range),
              match.numberOfRanges > 1 else { return nil }
        let captureRange = match.range(at: 1)
        guard captureRange.location != NSNotFound else { return nil }
        let candidate = nsString.substring(with: captureRange).uppercased()
        return isValidASIN(candidate) ? candidate : nil
    }

    /// Resolve a shortened Amazon URL (amzn.to, a.co) by following the redirect
    static func resolveShortURL(_ url: URL, completion: @escaping (URL?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8

        let delegate = RedirectCaptureDelegate { redirectURL in
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

    init(handler: @escaping (URL?) -> Void) {
        self.handler = handler
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        guard !handled else { completionHandler(nil); return }
        handled = true
        handler(request.url)
        completionHandler(nil) // Stop redirect chain
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !handled else { return }
        handled = true
        handler(nil)
    }
}
