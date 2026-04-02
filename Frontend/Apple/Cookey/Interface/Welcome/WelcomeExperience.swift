import Foundation

enum WelcomeExperience {
    private static let seenVersionKey = "WelcomeExperience.lastSeenVersion"

    private static var currentVersion: String {
        "0"
    }

    static var shouldPresent: Bool {
        UserDefaults.standard.string(forKey: seenVersionKey) != currentVersion
    }

    static func markPresented() {
        UserDefaults.standard.set(currentVersion, forKey: seenVersionKey)
    }
}
