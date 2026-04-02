import ConfigurableKit
import Foundation

enum AppEnvironment {
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
            return defaultServerEndpoint
        }
        return url
    }
}
