import ConfigurableKit
import Foundation

enum AppEnvironment {
    static let apiBaseURL = URL(string: "https://api.cookey.sh")!

    static var effectiveAPIBaseURL: URL {
        let domain: String = ConfigurableKit.value(
            forKey: SettingsViewController.defaultServerKey,
            defaultValue: ""
        )
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: "https://\(trimmed)"),
              url.host() != nil
        else {
            return apiBaseURL
        }
        return url
    }
}
