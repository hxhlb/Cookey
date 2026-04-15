import AlertController
import ConfigurableKit
import UIKit
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let pushCoordinator = PushRegistrationCoordinator()
    let launchBackendReachabilityCoordinator = LaunchBackendReachabilityCoordinator()
    lazy var sessionModel = SessionUploadModel(pushCoordinator: pushCoordinator)
    private var isPresentingExitConfirmation = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil,
    ) -> Bool {
        _ = LogStore.shared
        Logger.app.infoFile("Application finished launching")
        UNUserNotificationCenter.current().delegate = self
        configureAlertController()
        launchBackendReachabilityCoordinator.warmUpIfNeeded()
        refreshPushTokenIfAuthorized(application)
        return true
    }

    private func refreshPushTokenIfAuthorized(_ application: UIApplication) {
        let allowed: Bool = ConfigurableKit.value(
            forKey: AppSettings.allowRefreshKey,
            defaultValue: false,
        )
        guard allowed else {
            Logger.push.debugFile("Skipping launch APNs refresh because refresh requests are disabled")
            return
        }
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .authorized else {
                Logger.push.debugFile("Skipping launch APNs refresh because authorization status is \(settings.authorizationStatus.rawValue)")
                return
            }
            Logger.push.infoFile("Refreshing APNs registration on launch")
            await MainActor.run { application.registerForRemoteNotifications() }
        }
    }

    private func configureAlertController() {
        AlertControllerConfiguration.accentColor = UIColor(named: "AccentColor") ?? .systemIndigo
        AppIconSettings.synchronizeStoredSelection()
    }

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions,
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = SceneDelegate.self
        }
        return configuration
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)

        #if targetEnvironment(macCatalyst)
            builder.replace(
                menu: .close,
                with: UIMenu(
                    title: "",
                    options: .displayInline,
                    children: [
                        UIKeyCommand(
                            title: String(localized: "Close"),
                            action: #selector(requestAppExitFromMenu(_:)),
                            input: "w",
                            modifierFlags: .command,
                        ),
                    ],
                ),
            )

            builder.replace(
                menu: .quit,
                with: UIMenu(
                    title: "",
                    options: .displayInline,
                    children: [
                        UIKeyCommand(
                            title: String(localized: "Exit"),
                            action: #selector(requestAppExitFromMenu(_:)),
                            input: "q",
                            modifierFlags: .command,
                        ),
                    ],
                ),
            )
        #endif
    }

    func application(
        _: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data,
    ) {
        Logger.push.infoFile("Received APNs device token callback with \(deviceToken.count) bytes")
        Task { await pushCoordinator.handleRegisteredDeviceToken(deviceToken) }
    }

    func application(
        _: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error,
    ) {
        Logger.push.errorFile("APNs registration failed: \(error.localizedDescription)")
        pushCoordinator.handleRegistrationFailure(error)
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void,
    ) {
        Logger.push.infoFile("Foreground push notification will be presented")
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void,
    ) {
        Logger.push.infoFile("User tapped push notification with keys: \(response.notification.request.content.userInfo.keys.map(String.init(describing:)).sorted())")
        pushCoordinator.handleNotificationUserInfo(response.notification.request.content.userInfo)
        completionHandler()
    }

    #if targetEnvironment(macCatalyst)
        @objc func terminate(_: Any?) {
            requestApplicationExit()
        }

        @objc override func performClose(_: Any?) {
            requestApplicationExit()
        }

        @objc private func requestAppExitFromMenu(_: Any?) {
            requestApplicationExit()
        }

        func requestApplicationExit() {
            requestProtectedTermination {
                terminateApplication()
            }
        }

        private func requestProtectedTermination(_ action: @escaping () -> Void) {
            guard sessionModel.hasExecutingFlow else {
                action()
                return
            }
            presentExitConfirmationIfNeeded(action: action)
        }

        private func presentExitConfirmationIfNeeded(action: @escaping () -> Void) {
            guard !isPresentingExitConfirmation else { return }
            guard let rootViewController = mainWindow?.rootViewController else {
                action()
                return
            }

            isPresentingExitConfirmation = true

            let alert = AlertViewController(
                title: String(localized: "Exit"),
                message: String(localized: "Exiting now will interrupt the current Cookey request."),
            ) { [weak self] context in
                context.addAction(title: String(localized: "Cancel")) {
                    self?.isPresentingExitConfirmation = false
                    context.dispose()
                }
                context.addAction(title: String(localized: "Exit"), attribute: .dangerous) {
                    self?.isPresentingExitConfirmation = false
                    context.dispose {
                        action()
                    }
                }
            }

            let presenter = topMostViewController(from: rootViewController) ?? rootViewController
            presenter.present(alert, animated: true)
        }
    #endif
}

private extension AppDelegate {
    /// DONT REMOVE
    static let localizationExtension: [String] = [
        String(localized: "apn_refresh_title"),
        String(localized: "apn_refresh_body"),
        String(localized: "apn_login_title"),
        String(localized: "apn_login_body"),
    ]

    var mainWindow: UIWindow? {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let windows = windowScenes.flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first
    }

    func topMostViewController(from viewController: UIViewController?) -> UIViewController? {
        guard let viewController else { return nil }

        if let presentedViewController = viewController.presentedViewController {
            return topMostViewController(from: presentedViewController)
        }

        if let navigationController = viewController as? UINavigationController {
            return topMostViewController(from: navigationController.visibleViewController)
        }

        if let tabBarController = viewController as? UITabBarController {
            return topMostViewController(from: tabBarController.selectedViewController)
        }

        return viewController
    }
}

func terminateApplication() -> Never {
    #if targetEnvironment(macCatalyst)
        exit(0)
    #else
        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        Task.detached {
            try await Task.sleep(for: .seconds(1))
            exit(0)
        }
        sleep(5)
        fatalError()
    #endif
}
