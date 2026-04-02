import UIKit

extension WelcomePageViewController {
    struct Configuration {
        var title: String.LocalizationValue
        var highlightedTitle: String.LocalizationValue
        var subtitle: String.LocalizationValue
        var buttonTitle: String.LocalizationValue
        var accentColor: UIColor
        var icon: UIImage
        var features: [Feature]
    }

    struct Feature {
        var icon: UIImage
        var title: String.LocalizationValue
        var detail: String.LocalizationValue
    }
}

extension WelcomePageViewController.Configuration {
    static var `default`: Self {
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Cookey"

        return .init(
            title: "Welcome to",
            highlightedTitle: "\(displayName)",
            subtitle: "Scan a QR code on your phone, log in on mobile, and your session lands encrypted in your terminal — ready for automation.",
            buttonTitle: "Get Started",
            accentColor: .accent,
            icon: .avatar,
            features: [
                .init(
                    icon: UIImage(systemName: "qrcode.viewfinder")!,
                    title: "Scan & Login",
                    detail: "Scan a QR code from your terminal, log in on your phone, done."
                ),
                .init(
                    icon: UIImage(systemName: "lock.shield.fill")!,
                    title: "End-to-end Encrypted",
                    detail: "Session data is encrypted on-device before leaving your phone. The relay never sees plaintext."
                ),
                .init(
                    icon: UIImage(systemName: "key.fill")!,
                    title: "Zero Registration",
                    detail: "No accounts or enrollment. The CLI generates its own key pair on first run."
                ),
                .init(
                    icon: UIImage(systemName: "shippingbox.fill")!,
                    title: "Self-Hostable",
                    detail: "Single Docker image, memory-only storage, auto-expiring sessions."
                ),
                .init(
                    icon: UIImage(systemName: "terminal.fill")!,
                    title: "Built for Automation",
                    detail: "Outputs Playwright-compatible storageState JSON. Pipe into any browser automation tool."
                ),
                .init(
                    icon: UIImage(systemName: "chevron.left.forwardslash.chevron.right")!,
                    title: "Open Source",
                    detail: "Every component — CLI, app, relay — is open source and auditable."
                ),
            ]
        )
    }
}
