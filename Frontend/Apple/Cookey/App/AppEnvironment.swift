import ConfigurableKit
import Foundation

enum AppEnvironment {
    nonisolated static var effectiveAPIBaseURL: URL {
        let domain: String = ConfigurableKit.value(
            forKey: AppSettings.defaultServerKey,
            defaultValue: "",
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
