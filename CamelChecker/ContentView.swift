import SwiftUI

struct ContentView: View {
    @State private var amazonURL: String = ""
    @State private var isLoading = false
    @State private var asin: String? = nil
    @State private var errorMessage: String? = nil
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            // Background
            Color(hex: "#0D0D0D")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "#FF6B35"))
                        Text("CamelCheck")
                            .font(.custom("Georgia-Bold", size: 28))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 60)

                    Text("Amazon Price History Lookup")
                        .font(.custom("Georgia", size: 13))
                        .foregroundColor(Color(hex: "#888888"))
                        .tracking(1.2)
                        .textCase(.uppercase)
                }
                .padding(.bottom, 40)

                // Instructions Card
                VStack(alignment: .leading, spacing: 16) {
                    Label("How to use", systemImage: "info.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#FF6B35"))
                        .textCase(.uppercase)
                        .tracking(1)

                    VStack(alignment: .leading, spacing: 10) {
                        InstructionRow(number: "1", text: "Open any Amazon product in Safari or the Amazon app")
                        InstructionRow(number: "2", text: "Tap Share → CamelCheck")
                        InstructionRow(number: "3", text: "Get redirected instantly to CamelCamelCamel price history")
                    }
                }
                .padding(20)
                .background(Color(hex: "#1A1A1A"))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#2A2A2A"), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                Spacer().frame(height: 30)

                // Manual URL Input
                VStack(alignment: .leading, spacing: 10) {
                    Text("Or paste an Amazon URL")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#666666"))
                        .textCase(.uppercase)
                        .tracking(1)
                        .padding(.horizontal, 24)

                    HStack(spacing: 0) {
                        TextField("https://www.amazon.com/dp/...", text: $amazonURL)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .focused($fieldFocused)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                        Button(action: lookupURL) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                                    .frame(width: 52, height: 52)
                            } else {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 52, height: 52)
                            }
                        }
                        .background(Color(hex: "#FF6B35"))
                        .disabled(amazonURL.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    }
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(fieldFocused ? Color(hex: "#FF6B35").opacity(0.6) : Color(hex: "#2A2A2A"), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                }

                // Error / ASIN display
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(Color(hex: "#FF4444"))
                    .padding(.top, 14)
                    .padding(.horizontal, 24)
                }

                if let asin = asin {
                    VStack(spacing: 6) {
                        Text("ASIN Detected")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#666666"))
                            .textCase(.uppercase)
                            .tracking(1)
                        Text(asin)
                            .font(.custom("Menlo", size: 16))
                            .foregroundColor(Color(hex: "#FF6B35"))
                            .bold()
                    }
                    .padding(.top, 16)
                }

                Spacer()

                // Footer
                VStack(spacing: 4) {
                    Text("Powered by CamelCamelCamel")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#444444"))
                    Text("Not affiliated with Amazon or CamelCamelCamel")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#333333"))
                }
                .padding(.bottom, 30)
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }

    func lookupURL() {
        fieldFocused = false
        errorMessage = nil
        asin = nil
        isLoading = true

        let trimmed = amazonURL.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed) else {
            isLoading = false
            errorMessage = "That doesn't look like a valid URL."
            return
        }

        // If it's a short link, resolve it first
        if AmazonURLParser.isShortURL(url) {
            AmazonURLParser.resolveShortURL(url) { [self] resolvedURL in
                DispatchQueue.main.async {
                    if let resolved = resolvedURL {
                        self.processResolvedURL(resolved)
                    } else {
                        // Can't resolve — just open CCC search as fallback
                        self.isLoading = false
                        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let searchURL = URL(string: "https://camelcamelcamel.com/search?sq=\(encoded)") {
                            UIApplication.shared.open(searchURL)
                        } else {
                            self.errorMessage = "Couldn't resolve that short link."
                        }
                    }
                }
            }
        } else {
            processResolvedURL(url)
        }
    }

    private func processResolvedURL(_ url: URL) {
        isLoading = false
        if let detectedASIN = AmazonURLParser.extractASIN(from: url) {
            asin = detectedASIN
            let camelURL = URL(string: "https://camelcamelcamel.com/product/\(detectedASIN)")!
            UIApplication.shared.open(camelURL)
        } else if AmazonURLParser.isAmazonURL(url) {
            // Amazon URL but no ASIN — fall back to CCC search
            let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let searchURL = URL(string: "https://camelcamelcamel.com/search?sq=\(encoded)") {
                UIApplication.shared.open(searchURL)
            }
        } else {
            errorMessage = "Couldn't find an ASIN in that URL. Make sure it's a valid Amazon product link."
        }
    }

    func handleIncomingURL(_ url: URL) {
        // Handle deep link from share extension: camelcheck://asin/XXXXXXXXXX
        if url.scheme == "camelcheck", url.host == "asin" {
            let detectedASIN = url.lastPathComponent
            guard !detectedASIN.isEmpty else { return }
            asin = detectedASIN
            let camelURL = URL(string: "https://camelcamelcamel.com/product/\(detectedASIN)")!
            UIApplication.shared.open(camelURL)
        }
    }
}

struct InstructionRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#FF6B35"))
                .frame(width: 20, height: 20)
                .background(Color(hex: "#FF6B35").opacity(0.12))
                .cornerRadius(4)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#AAAAAA"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
}
