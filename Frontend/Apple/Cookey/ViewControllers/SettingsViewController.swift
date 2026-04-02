import ConfigurableKit
import UIKit
import UserNotifications

final class SettingsViewController: ConfigurableViewController {
    static let allowRefreshKey = "wiki.qaq.cookey.settings.allow-refresh"
    static let feedbackURL = URL(string: "https://feedback.qaq.wiki/")!

    static let object = ConfigurableObject(
        icon: "arrow.trianglehead.2.clockwise",
        title: "Allow Refresh Requests",
        explain: "When enabled, the relay server can send push notifications to this device for session refresh requests. This requires system notification permissions.",
        key: allowRefreshKey,
        defaultValue: false,
        annotation: .toggle
    )
    .whenValueChange(type: Bool.self, to: whenValueChanged)

    static let feedbackObject = ConfigurableObject(
        icon: "ellipsis.bubble",
        title: "Submit Feedback",
        explain: "Report bugs, request features, or share your thoughts about Cookey.",
        ephemeralAnnotation: .action(handler: openFeedback)
    )

    init() {
        let manifest = ConfigurableManifest(
            title: "Settings",
            list: [Self.object, Self.feedbackObject]
        )
        super.init(manifest: manifest)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    @MainActor
    private static func openFeedback(_: UIViewController) async {
        await UIApplication.shared.open(feedbackURL)
    }

    nonisolated static func whenValueChanged(_ newValue: Bool?) -> Bool? {
        let enabled = newValue == true
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            case .notDetermined:
                do {
                    let granted = try await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound, .badge])
                    await MainActor.run {
                        if granted {
                            UIApplication.shared.registerForRemoteNotifications()
                        } else if enabled {
                            ConfigurableKit.set(value: false, forKey: allowRefreshKey)
                        }
                    }
                } catch {
                    if enabled {
                        await MainActor.run {
                            ConfigurableKit.set(value: false, forKey: allowRefreshKey)
                        }
                    }
                }
            default:
                if enabled {
                    await MainActor.run {
                        ConfigurableKit.set(value: false, forKey: allowRefreshKey)
                    }
                }
            }
        }
        return newValue
    }
}
