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
│   ├── AppSettings.swift                  # User-facing settings model
│   ├── FlowCoordinator.swift              # UIKit navigation state machine
│   └── SceneDelegate.swift                # UIWindowScene lifecycle and deep link handling
├── Interface/                             # All screens, grouped by feature
│   ├── Browser/
│   │   ├── BrowserViewController.swift    # In-app browser (WKWebView)
│   │   ├── BrowserCaptureModel.swift      # WKWebView cookie/localStorage capture model
│   │   ├── BrowserCaptureModel+Navigation.swift  # Navigation delegate extension
│   │   └── BrowserCaptureModel+UIDelegate.swift  # UI delegate extension
│   ├── Home/
│   │   └── HomeViewController.swift       # Home/idle screen
│   ├── KeyVerification/
│   │   └── KeyVerificationViewController.swift  # Public key fingerprint verification
│   ├── NotificationConsent/
│   │   └── NotificationConsentViewController.swift  # Push permission prompt
│   ├── PairKeyLoading/
│   │   └── PairKeyLoadingViewController.swift  # Pair key resolution from server
│   ├── Scanner/
│   │   ├── ScannerViewController.swift    # QR scanner screen
│   │   └── ScannerContainerView@iOS.swift # AVCaptureSession QR scanner (UIViewRepresentable)
│   ├── SeedLoading/
│   │   └── SeedLoadingViewController.swift  # Seed session download for refresh flows
│   ├── Settings/
│   │   ├── SettingsViewController.swift   # App settings screen
│   │   ├── LogViewerController.swift      # Log viewer sub-screen
│   │   ├── TextViewerController.swift     # Generic text viewer
│   │   └── TrustedPublicKeysViewController.swift  # Trusted keys management
│   ├── Shared/
│   │   └── ConfigurableInfoView.swift     # Reusable info display component
│   ├── Upload/
│   │   └── UploadProgressViewController.swift  # Upload status display
│   └── Welcome/
│       ├── WelcomePageViewController.swift  # Welcome/onboarding flow
│       ├── WelcomeExperience.swift        # Welcome experience model
│       └── SetupStepView.swift            # Setup step SwiftUI view
├── Logging/
│   ├── Logger+FileLogging.swift           # File logging extension
│   ├── Logger+Subsystem.swift             # Subsystem constants
│   ├── LogLevel.swift                     # Log level enum
│   └── LogStore.swift                     # In-memory log storage
├── Models/
│   ├── CapturedCookie.swift               # Single captured cookie
│   ├── CapturedOrigin.swift               # Origin with cookies and storage items
│   ├── CapturedSession.swift              # Full session with origins array
│   ├── CapturedStorageItem.swift          # Single localStorage key-value pair
│   ├── DeepLink.swift                     # cookey:// URL scheme parsing (login + refresh types)
│   ├── EncryptedSessionEnvelope.swift     # Encrypted session wire format
│   ├── HealthCheckResult.swift            # Server health check response
│   ├── PairKeyResolveResponse.swift       # Pair key resolution response
│   ├── RequestStatusResponse.swift        # Request status response
│   └── SeedSessionPayload.swift           # Seed session payload
├── Networking/
│   └── RelayClient.swift                  # URLSession HTTP client (health, upload, seed, APNs)
├── Services/
│   ├── AppIconSettings.swift              # App icon selection
│   ├── DeviceKeyManager.swift             # Ed25519/X25519 device key persistence and derivation
│   ├── HealthCheckModel.swift             # Server health polling
│   ├── KeyFingerprint.swift               # Public key fingerprint generation
│   ├── LaunchBackendReachabilityCoordinator.swift  # Backend reachability on launch
│   ├── NotificationPromptResponse.swift   # Push consent enum
│   ├── NotificationPromptStore.swift      # Persisted push consent state
│   ├── PushRegistrationCoordinator@iOS.swift  # APNs device token handling
│   ├── PushTokenStore.swift               # Persistent APNs token storage
│   ├── RequestAuthenticator.swift         # Request signing
│   ├── SessionUploadModel.swift           # Upload state machine
│   ├── SessionUploadModel+UploadError.swift   # Upload error types
│   ├── TrustedKeyListDataSource.swift     # Trusted key list data source
│   └── TrustedKeyStore.swift              # Trusted public key persistence
├── main.swift                             # App entry point
└── Resources/
CookeyTests/
├── BrowserCaptureModelTests.swift
├── CapturedSessionCodingTests.swift
├── CookeyTests.swift
├── CryptoBoxOpenTests.swift
├── DeepLinkTests.swift
├── DeviceKeyManagerTests.swift
├── KeyFingerprintTests.swift
├── LaunchBackendReachabilityCoordinatorTests.swift
└── LogStoreTests.swift
```

## Key Concepts

- **Interface**: UIKit-based screens grouped by feature under `Interface/`, managed by `FlowCoordinator` which drives navigation between home, scanner, seed loading, browser, upload progress, and notification consent
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

## Copy & Terminology

- Never use the abbreviation "CLI" in user-facing strings — always spell out "command-line" or "command line" instead
- Internal code comments, variable names, and documentation may use "CLI" freely
- iOS app localization (zh-Hans): Keep tone friendly, natural, and Apple-like ("果味"). Avoid overly formal/stiff phrases like "是否...". Instead, use conversational expressions like "你要...吗" or "要...吗".

## Swift Conventions

- 4-space indentation, opening braces on same line
- @Observable macro (not ObservableObject/@Published)
- async/await, @MainActor for UI state
- Early returns, guard statements
- PascalCase types, camelCase properties/methods
- Small focused files, `+Extension.swift` for extensions
- Dependency injection over singletons
- Value types over reference types
