import Combine
import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushRegistrationCoordinator: ObservableObject {
    typealias RelayClientFactory = (URL) -> RelayClient

    enum RegistrationError: LocalizedError {
        case notificationPermissionDenied
        case notificationsUnavailable
        case timedOut

        var errorDescription: String? {
            switch self {
            case .notificationPermissionDenied:
                String(localized: "Notification permission was denied.")
            case .notificationsUnavailable:
                String(localized: "Notifications are disabled for Cookey on this device.")
            case .timedOut:
                String(localized: "Timed out waiting for push notification registration.")
            }
        }
    }

    enum State: Equatable {
        case idle
        case requestingPermission
        case waitingForToken(serverURL: URL, deviceID: String)
        case uploadingToken
        case failed(String)
    }

    static let isSupported = true

    @Published var state: State = .idle
    @Published private(set) var pendingNotificationURL: URL?

    private weak var model: SessionUploadModel?
    private var tokenContinuation: CheckedContinuation<Void, Error>?

    init() {}

    func ensurePushToken(
        serverURL: URL,
        deviceID: String,
        requestAuthorizationIfNeeded: Bool
    ) async throws {
        Logger.push.infoFile("Ensuring push token for host \(serverURL.host() ?? serverURL.absoluteString), device \(deviceID), requestAuthorizationIfNeeded=\(requestAuthorizationIfNeeded)")
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            Logger.push.debugFile("Notification authorization already available with status \(settings.authorizationStatus.rawValue)")
        case .notDetermined:
            guard requestAuthorizationIfNeeded else {
                Logger.push.errorFile("Notification authorization required but prompting is disabled")
                throw RegistrationError.notificationPermissionDenied
            }
            state = .requestingPermission
            Logger.push.infoFile("Requesting notification authorization")
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                Logger.push.errorFile("Notification authorization request was denied")
                throw RegistrationError.notificationPermissionDenied
            }
            Logger.push.infoFile("Notification authorization granted")
        default:
            Logger.push.errorFile("Notifications unavailable with status \(settings.authorizationStatus.rawValue)")
            throw RegistrationError.notificationsUnavailable
        }

        if let token = PushTokenStore.currentToken,
           let environment = PushTokenStore.currentEnvironment
        {
            Logger.push.infoFile("Using cached APNs token (\(token.count) chars) in \(environment) environment")
            state = .idle
            return
        }

        try await waitForTokenCallback(serverURL: serverURL, deviceID: deviceID)
    }

    func handleRegisteredDeviceToken(_ token: Data) async {
        let tokenHex = token.map { String(format: "%02x", $0) }.joined()
        PushTokenStore.currentToken = tokenHex
        PushTokenStore.currentEnvironment = currentPushEnvironment
        Logger.push.infoFile("Stored APNs token (\(tokenHex.count) chars) for \(currentPushEnvironment) environment")

        guard case .waitingForToken = state else {
            Logger.push.debugFile("APNs token callback received while not waiting for token")
            return
        }

        state = .idle
        tokenContinuation?.resume()
        tokenContinuation = nil
    }

    func handleRegistrationFailure(_ error: Error) {
        Logger.push.errorFile("Push registration failure: \(error.localizedDescription)")
        state = .failed(error.localizedDescription)
        tokenContinuation?.resume(throwing: error)
        tokenContinuation = nil
    }

    func handleNotificationUserInfo(_ userInfo: [AnyHashable: Any]) {
        guard let url = deepLinkURL(from: userInfo) else {
            Logger.push.errorFile("Failed to build deep link from push userInfo keys: \(userInfo.keys.map(String.init(describing:)).sorted())")
            return
        }

        let requestType = (userInfo["request_type"] as? String) ?? "login"
        let rid = (userInfo["rid"] as? String) ?? "<missing>"
        Logger.push.infoFile("Received push payload for rid \(rid) with request type \(requestType)")

        if model?.phase == .idle {
            Logger.push.infoFile("App is idle; opening push deep link immediately")
            model?.handleURL(url)
        } else {
            Logger.push.infoFile("App is busy; queueing pending push deep link")
            pendingNotificationURL = url
        }
    }

    func consumePendingNotification() -> URL? {
        guard let url = pendingNotificationURL else { return nil }
        pendingNotificationURL = nil
        Logger.push.infoFile("Consuming queued push deep link")
        return url
    }

    func attach(to model: SessionUploadModel) async {
        self.model = model
        Logger.push.debugFile("Attached push coordinator to session model")
    }

    private func waitForTokenCallback(serverURL: URL, deviceID: String) async throws {
        Logger.push.infoFile("Waiting for APNs token callback for host \(serverURL.host() ?? serverURL.absoluteString), device \(deviceID)")
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                try await withCheckedThrowingContinuation { continuation in
                    self.state = .waitingForToken(serverURL: serverURL, deviceID: deviceID)
                    self.tokenContinuation = continuation
                    Logger.push.debugFile("Calling registerForRemoteNotifications()")
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(15))
                throw RegistrationError.timedOut
            }

            try await group.next()
            group.cancelAll()
        }
        Logger.push.infoFile("APNs token callback flow finished")
    }

    private var currentPushEnvironment: String {
        #if DEBUG
            "sandbox"
        #else
            "production"
        #endif
    }

    private func deepLinkURL(from userInfo: [AnyHashable: Any]) -> URL? {
        guard
            let rid = userInfo["rid"] as? String,
            let targetURL = userInfo["target_url"] as? String,
            let publicKey = userInfo["pubkey"] as? String,
            let deviceID = userInfo["device_id"] as? String
        else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "cookey"
        components.host = "login"
        components.queryItems = [
            URLQueryItem(name: "rid", value: rid),
            URLQueryItem(name: "target", value: targetURL),
            URLQueryItem(name: "pubkey", value: publicKey),
            URLQueryItem(name: "device_id", value: deviceID),
        ]
        if let serverURL = userInfo["server_url"] as? String {
            components.queryItems?.append(URLQueryItem(name: "server", value: serverURL))
        }
        if let requestType = userInfo["request_type"] as? String {
            components.queryItems?.append(URLQueryItem(name: "request_type", value: requestType))
        }
        return components.url
    }
}
