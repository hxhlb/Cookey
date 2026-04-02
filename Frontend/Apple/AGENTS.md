# Frontend/Apple

SwiftUI iOS app for Cookey. Scans QR codes, opens target sites in an in-app browser, captures cookies and localStorage, encrypts the session, and uploads it to the relay server.

## Dependencies

- `CryptoBox` (local: `../../Packages/CryptoBox`) — XSalsa20-Poly1305 encryption

## Source Layout

```
Cookey/
├── App/
│   ├── AppDelegate.swift                  # UIApplicationDelegate (push notifications, deep links)
│   ├── AppEnvironment.swift               # API endpoint config
│   ├── FlowCoordinator.swift              # UIKit navigation state machine
│   └── SceneDelegate.swift                # UIWindowScene lifecycle and deep link handling
├── Interface/
│   ├── Browser/
│   │   ├── BrowserCaptureModel.swift      # WKWebView cookie/localStorage capture model
│   │   └── BrowserCaptureModel+Navigation.swift  # Navigation delegate extension
│   └── Scanner/
│       └── ScannerContainerView@iOS.swift # AVCaptureSession QR scanner (UIViewRepresentable)
├── Models/
│   ├── CapturedCookie.swift               # Single captured cookie
│   ├── CapturedOrigin.swift               # Origin with cookies and storage items
│   ├── CapturedSession.swift              # Full session with origins array
│   ├── CapturedStorageItem.swift          # Single localStorage key-value pair
│   ├── DeepLink.swift                     # cookey:// URL scheme parsing (login + refresh types)
│   ├── EncryptedSessionEnvelope.swift     # Encrypted session wire format
│   └── HealthCheckResult.swift            # Server health check response
├── Networking/
│   └── RelayClient.swift                  # URLSession HTTP client (health, upload, seed, APNs)
├── Services/
│   ├── DeviceKeyManager.swift             # Ed25519/X25519 device key persistence and derivation
│   ├── HealthCheckModel.swift             # Server health polling
│   ├── NotificationPromptResponse.swift   # Push consent enum
│   ├── NotificationPromptStore.swift      # Persisted push consent state
│   ├── PushRegistrationCoordinator@iOS.swift  # APNs device token handling
│   ├── PushTokenStore.swift               # Persistent APNs token storage
│   ├── SessionUploadModel.swift           # Upload state machine
│   └── SessionUploadModel+UploadError.swift   # Upload error types
├── ViewControllers/
│   ├── BrowserViewController.swift        # In-app browser (WKWebView)
│   ├── HomeViewController.swift           # Home/idle screen
│   ├── NotificationConsentViewController.swift  # Push permission prompt
│   ├── ScannerViewController.swift        # QR scanner screen
│   ├── SeedLoadingViewController.swift    # Seed session download for refresh flows
│   └── UploadProgressViewController.swift # Upload status display
├── main.swift                             # App entry point
└── Resources/
CookeyTests/
├── BrowserCaptureModelTests.swift
├── CapturedSessionCodingTests.swift
├── CookeyTests.swift
├── CryptoBoxOpenTests.swift
├── DeepLinkTests.swift
└── DeviceKeyManagerTests.swift
```

## Key Concepts

- **ViewControllers**: UIKit-based screens managed by `FlowCoordinator`, which drives navigation between home, scanner, seed loading, browser, upload progress, and notification consent
- **State machine**: `SessionUploadModel` drives the upload flow; `FlowCoordinator` drives overall app navigation
- **Pair-key deep link**: `cookey://SM8ND67N?host=api.cookey.sh` (host only, HTTPS implied, no custom path)
- **Authenticated request deep link**: `cookey://login?rid=...&server=...&target=...&pubkey=...&device_id=...&request_type=login|refresh`
- **Session refresh**: for `request_type=refresh`, the app downloads a seed session from the relay via `SeedLoadingViewController`, pre-populates the browser, then captures the refreshed session
- **DeviceKeyManager**: manages Ed25519/X25519 device keypair persistence in the Keychain for session decryption
- **PushTokenStore**: persists the APNs device token across launches for re-registration
- **Capture**: WKWebView JavaScript evaluation extracts cookies and localStorage after user logs in
- **Encryption**: captured session encrypted with CLI's X25519 public key via CryptoBox before upload

## Build Configuration

- **Targets**: iOS 26.2+, macOS 26.2+ (Catalyst), visionOS
- **Bundle ID**: `wiki.qaq.cookey.app`
- **Entitlements**: App Sandbox, Hardened Runtime, camera access
- **API**: `https://api.cookey.sh` (override with `COOKEY_API_URL` env var)

## Swift Conventions

- 4-space indentation, opening braces on same line
- @Observable macro (not ObservableObject/@Published)
- async/await, @MainActor for UI state
- Early returns, guard statements
- PascalCase types, camelCase properties/methods
- Small focused files, `+Extension.swift` for extensions
- Dependency injection over singletons
- Value types over reference types
