import AlertController
import ConfigurableKit
import UIKit

enum AppIconSettings {
    static let appIconKey = "wiki.qaq.cookey.settings.app-icon"

    enum Option: String, CaseIterable {
        case `default` = ""
        case blue = "AppIcon_1"
        case silver = "AppIcon_2"

        var title: String.LocalizationValue {
            switch self {
            case .default:
                "Default"
            case .blue:
                "Blue"
            case .silver:
                "Silver"
            }
        }

        var explain: String.LocalizationValue {
            "Choose the icon shown on your Home Screen."
        }

        var assetName: String {
            switch self {
            case .default:
                "AlertAvatarDefault"
            case .blue:
                "AlertAvatarBlue"
            case .silver:
                "AlertAvatarSilver"
            }
        }

        var menuIcon: String {
            "#\(assetName)"
        }

        var alternateIconName: String? {
            rawValue.isEmpty ? nil : rawValue
        }
    }

    static let configurableObject = ConfigurableObject(
        icon: "app.badge",
        title: "App Icon",
        explain: Option.default.explain,
        key: appIconKey,
        defaultValue: Option.default.rawValue,
        annotation: .menu { menuOptions() },
    )
    .whenValueChange(type: String.self) { rawValue in
        Task { @MainActor in
            await applySelection(rawValue: rawValue)
        }
    }

    static func menuOptions() -> [MenuAnnotation.Option] {
        Option.allCases.map {
            .init(
                icon: $0.menuIcon,
                title: $0.title,
                rawValue: $0.rawValue,
            )
        }
    }

    @MainActor
    static func synchronizeStoredSelection() {
        let selection = currentSelection()
        let stored: String = ConfigurableKit.value(forKey: appIconKey, defaultValue: Option.default.rawValue)
        if stored != selection.rawValue {
            ConfigurableKit.set(value: selection.rawValue, forKey: appIconKey)
        }
        updateAlertImage(for: selection)
    }

    @MainActor
    static func applySelection(rawValue: String?) async {
        let requested = Option(rawValue: rawValue ?? "") ?? .default
        let current = currentSelection()

        guard UIApplication.shared.supportsAlternateIcons else {
            restoreSelection(current)
            return
        }

        guard requested != current else {
            updateAlertImage(for: requested)
            return
        }

        do {
            try await UIApplication.shared.cookey_setAlternateIconName(requested.alternateIconName)
            Logger.ui.infoFile("Updated app icon selection to \(requested.rawValue.isEmpty ? "default" : requested.rawValue)")
            updateAlertImage(for: requested)
        } catch {
            Logger.ui.errorFile("Failed to update app icon selection: \(error.localizedDescription)")
            restoreSelection(current)
        }
    }

    @MainActor
    static func updateAlertImage() {
        updateAlertImage(for: currentSelection())
    }

    @MainActor
    static func updateAlertImage(for option: Option) {
        AlertControllerConfiguration.alertImage = UIImage(named: option.assetName)
            ?? UIImage(named: Option.default.assetName)
    }

    @MainActor
    private static func restoreSelection(_ option: Option) {
        let stored: String = ConfigurableKit.value(forKey: appIconKey, defaultValue: Option.default.rawValue)
        if stored != option.rawValue {
            ConfigurableKit.set(value: option.rawValue, forKey: appIconKey)
        }
        updateAlertImage(for: option)
    }

    @MainActor
    private static func currentSelection() -> Option {
        let iconName = UIApplication.shared.alternateIconName ?? Option.default.rawValue
        return Option(rawValue: iconName) ?? .default
    }
}

private extension UIApplication {
    @MainActor
    func cookey_setAlternateIconName(_ iconName: String?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setAlternateIconName(iconName) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
