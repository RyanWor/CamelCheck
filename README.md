# CamelCheck — iOS App

An iOS Share Extension that lets you share any Amazon product link directly to CamelCamelCamel for instant price history lookup.

---

## Features

- **Share Extension** — appears in the iOS Share Sheet from Safari, Amazon app, or anywhere URLs are shared
- **ASIN Extraction** — intelligently parses Amazon product ASINs from all URL formats
- **Short URL Resolution** — handles `amzn.to` and `a.co` short links by following redirects
- **Manual URL Lookup** — paste any Amazon URL directly in the app
- **Zero tracking, zero ads** — pure utility

---

## Supported URL Formats

| Format | Example |
|--------|---------|
| Standard product page | `amazon.com/dp/B0XXXXXXXXX` |
| Product with title slug | `amazon.com/Some-Product-Title/dp/B0XXXXXXXXX` |
| GP product URL | `amazon.com/gp/product/B0XXXXXXXXX` |
| Legacy ASIN URL | `amazon.com/ASIN/B0XXXXXXXXX` |
| Short link | `amzn.to/3AbCdEf` |
| Amazon app share link | Resolved via redirect |
| International (`.co.uk`, `.de`, etc.) | Detected via host pattern |

---

## Project Structure

```
CamelChecker/
├── CamelChecker/                  # Main app target
│   ├── CamelCheckerApp.swift      # App entry point (@main)
│   ├── ContentView.swift          # SwiftUI main interface
│   ├── AmazonURLParser.swift      # ASIN extraction logic (shared)
│   └── Info.plist                 # App config + URL scheme
│
├── ShareExtension/                # Share Extension target
│   ├── ShareViewController.swift  # Extension UI + logic
│   └── Info.plist                 # Extension activation rules
│
└── CamelChecker.xcodeproj/
    └── project.pbxproj
```

---

## Setup in Xcode

### 1. Open the project
```
open CamelChecker.xcodeproj
```

### 2. Update Bundle Identifiers
Replace `com.yourname.camelchecker` with your own bundle ID in:
- `CamelChecker` target → General → Bundle Identifier
- `ShareExtension` target → General → Bundle Identifier (must be `<app-bundle-id>.ShareExtension`)

### 3. Set your Development Team
- Select each target → Signing & Capabilities → Team

### 4. Add AmazonURLParser to ShareExtension target
In Xcode, select `AmazonURLParser.swift` → File Inspector → Target Membership → check **both** CamelChecker and ShareExtension.

### 5. Add App Groups (optional, for shared state)
If you want the extension to pass data back to the main app:
- Add `App Groups` capability to both targets
- Use the same group ID (e.g., `group.com.yourname.camelchecker`)

### 6. Build & Run
Select the `CamelChecker` scheme, build to device (Share Extensions don't fully work in Simulator).

---

## How It Works

### Flow
```
User taps Share in Safari/Amazon app
    → iOS presents Share Sheet
    → User selects "CamelCheck"
    → ShareViewController receives the URL
    → AmazonURLParser extracts ASIN
        → If short URL: follow redirect first
        → If ASIN found: open camelcamelcamel.com/product/{ASIN}
        → If no ASIN: fall back to camelcamelcamel.com/search?sq={URL}
    → Extension dismisses, CamelCamelCamel opens in Safari
```

### ASIN Extraction
The `AmazonURLParser` uses regex patterns to find 10-character alphanumeric ASINs from known URL path positions (`/dp/`, `/gp/product/`, `/ASIN/`, etc.) and query parameters.

### Short URL Handling
`amzn.to` and `a.co` links are resolved by making a HEAD request and capturing the `Location` redirect header — no full page download needed.

---

## Customization

### Add more URL patterns
Edit `AmazonURLParser.swift`, add entries to `dpPatterns`:
```swift
let dpPatterns = [
    #"/dp/([A-Z0-9]{10})"#,
    // Add new patterns here
]
```

### Change the destination
To use a different price tracker, change the URL template in `ShareViewController.swift`:
```swift
let camelURLString = "https://camelcamelcamel.com/product/\(asin)"
// Could also use: "https://keepa.com/#!product/1-\(asin)"
```

---

## Requirements

- iOS 16.0+
- Xcode 15+
- Swift 5.9+
- Apple Developer account (for device testing)

---

## Notes

- CamelCamelCamel primarily tracks **US Amazon** products. For international ASINs, the lookup may not have data.
- This app is not affiliated with Amazon or CamelCamelCamel.
- Share Extensions cannot directly open URLs in iOS — the extension dismisses and the URL opens via the responder chain trick (standard workaround).
