import Combine
import ConfigurableKit
import CryptoBox
import Foundation

@MainActor
final class SessionUploadModel: ObservableObject {
    enum LoadingState: Equatable {
        case checkingRequest(host: String)
        case loadingSeed(host: String)
    }

    enum Phase: Equatable {
        case idle
        case scanning
        case validating(DeepLink)
        case browsing(DeepLink)
        case uploading
        case done
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var seedSession: CapturedSession?
    @Published var loadingState: LoadingState?
    @Published var shouldPresentPushExplanation = false

    private let pushCoordinator: PushRegistrationCoordinator?
    private let relayClientFactory: (URL) -> RelayClient
    private var pushExplanationContinuation: CheckedContinuation<Bool, Never>?

    init(pushCoordinator: PushRegistrationCoordinator?) {
        self.pushCoordinator = pushCoordinator
        relayClientFactory = { RelayClient(baseURL: $0) }
    }

    init(
        pushCoordinator: PushRegistrationCoordinator?,
        relayClientFactory: @escaping (URL) -> RelayClient
    ) {
        self.pushCoordinator = pushCoordinator
        self.relayClientFactory = relayClientFactory
    }

    func startScan() {
        Logger.ui.infoFile("Starting QR scan flow")
        phase = .scanning
    }

    func handleURL(_ url: URL) {
        guard let deepLink = DeepLink(url: url) else {
            Logger.model.errorFile("Rejected invalid Cookey URL: \(url.absoluteString)")
            phase = .failed("Invalid Cookey login link.")
            return
        }

        Logger.model.infoFile("Handling deep link rid=\(deepLink.rid) requestType=\(deepLink.requestType.rawValue) target=\(deepLink.targetURL.host() ?? deepLink.targetURL.absoluteString)")
        phase = .validating(deepLink)
        Task { await validateAndProceed(deepLink) }
    }

    func captureAndUpload(
        from browser: BrowserCaptureModel,
        deepLink: DeepLink
    ) async {
        do {
            Logger.browser.infoFile("Capturing browser session for rid \(deepLink.rid)")
            let plaintext = try await browser.captureSessionPayloadData()
            await uploadCapturedSessionData(plaintext, deepLink: deepLink)
        } catch {
            Logger.browser.errorFile("Browser capture failed for rid \(deepLink.rid): \(error.localizedDescription)")
            phase = .failed(error.localizedDescription)
        }
    }

    func uploadCapturedSessionData(
        _ plaintext: Data,
        deepLink: DeepLink
    ) async {
        phase = .uploading

        do {
            guard let recipientPublicKey = Data(base64Encoded: deepLink.recipientPublicKeyBase64) else {
                throw UploadError.invalidRecipientPublicKey
            }

            try Self.validateCapturedSessionData(plaintext)
            Logger.crypto.infoFile("Validated captured session for rid \(deepLink.rid): \(Self.sessionSummary(from: plaintext))")

            let sealed = try XSalsa20Poly1305Box.seal(
                plaintext: plaintext,
                recipientPublicKey: recipientPublicKey
            )
            Logger.crypto.infoFile("Encrypted session for rid \(deepLink.rid); ciphertext size \(sealed.ciphertext.count) bytes")

            let envelope = EncryptedSessionEnvelope(
                version: 1,
                algorithm: "x25519-xsalsa20poly1305",
                ephemeralPublicKey: sealed.ephemeralPublicKey.base64EncodedString(),
                nonce: sealed.nonce.base64EncodedString(),
                ciphertext: sealed.ciphertext.base64EncodedString(),
                capturedAt: Date()
            )

            try await relayClientFactory(deepLink.serverURL).uploadSession(
                rid: deepLink.rid,
                envelope: envelope
            )
            Logger.network.infoFile("Session upload finished for rid \(deepLink.rid)")
            phase = .done
        } catch {
            Logger.crypto.errorFile("Session upload failed for rid \(deepLink.rid): \(error.localizedDescription)")
            phase = .failed(error.localizedDescription)
        }
    }

    func respondToPushExplanation(allow: Bool) {
        Logger.push.infoFile("User responded to push explanation with allow=\(allow)")
        shouldPresentPushExplanation = false
        pushExplanationContinuation?.resume(returning: allow)
        pushExplanationContinuation = nil
    }

    func resetToIdle() {
        Logger.ui.infoFile("Resetting session model to idle")
        seedSession = nil
        loadingState = nil
        shouldPresentPushExplanation = false
        phase = .idle
    }

    private func validateAndProceed(_ deepLink: DeepLink) async {
        let host = deepLink.serverURL.host() ?? deepLink.serverURL.absoluteString
        Logger.model.infoFile("Validating request rid=\(deepLink.rid) requestType=\(deepLink.requestType.rawValue) host=\(host)")

        do {
            loadingState = .checkingRequest(host: host)
            let status = try await relayClientFactory(deepLink.serverURL)
                .fetchRequestStatus(rid: deepLink.rid)
            Logger.model.infoFile("Fetched request status for rid \(deepLink.rid): expired=\(status.isExpired)")

            if status.isExpired {
                Logger.model.errorFile("Request rid \(deepLink.rid) is expired")
                phase = .failed(String(localized: "This login request has expired."))
                return
            }

            if deepLink.requestType == .refresh {
                loadingState = .loadingSeed(host: host)
                Logger.model.infoFile("Loading seed session for refresh rid \(deepLink.rid)")
                await loadSeed(for: deepLink)
                guard phase == .validating(deepLink) else { return }
            }

            try await preparePushSupport(for: deepLink)

            try? await Task.sleep(for: .seconds(1))
            loadingState = nil
            Logger.ui.infoFile("Opening browser for rid \(deepLink.rid)")
            phase = .browsing(deepLink)
        } catch {
            loadingState = nil
            let nsError = error as NSError
            if nsError.domain == "Cookey.RelayClient", nsError.code == 404 || nsError.code == 410 {
                Logger.network.errorFile("Request rid \(deepLink.rid) is missing or expired on relay")
                phase = .failed(String(localized: "This login request has expired or does not exist."))
            } else {
                Logger.model.errorFile("Validation failed for rid \(deepLink.rid): \(error.localizedDescription)")
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func loadSeed(for deepLink: DeepLink) async {
        do {
            guard let encrypted = try await relayClientFactory(deepLink.serverURL)
                .fetchSeedSession(rid: deepLink.rid)
            else {
                Logger.model.infoFile("No seed session available for rid \(deepLink.rid)")
                return
            }
            Logger.crypto.infoFile("Fetched encrypted seed session for rid \(deepLink.rid); envelope ciphertext chars \(encrypted.ciphertext.count)")

            let deviceSecretKey = try DeviceKeyManager.secretKey()
            guard
                let ephemeralPublicKey = Data(base64Encoded: encrypted.ephemeralPublicKey),
                let nonce = Data(base64Encoded: encrypted.nonce),
                let ciphertext = Data(base64Encoded: encrypted.ciphertext)
            else {
                Logger.crypto.errorFile("Seed session envelope for rid \(deepLink.rid) contains invalid base64 fields")
                throw UploadError.invalidSessionPayload
            }
            Logger.crypto.debugFile("Decoded seed envelope for rid \(deepLink.rid); ephemeral=\(ephemeralPublicKey.count) nonce=\(nonce.count) ciphertext=\(ciphertext.count)")

            let plaintext = try XSalsa20Poly1305Box.open(
                ciphertext: ciphertext,
                nonce: nonce,
                ephemeralPublicKey: ephemeralPublicKey,
                recipientSecretKey: deviceSecretKey
            )
            Logger.crypto.infoFile("Decrypted seed session for rid \(deepLink.rid): \(Self.sessionSummary(from: plaintext))")

            seedSession = try JSONDecoder().decode(CapturedSession.self, from: plaintext)
            Logger.model.infoFile("Loaded seed session for rid \(deepLink.rid) with \(seedSession?.cookies.count ?? 0) cookies and \(seedSession?.origins.count ?? 0) origins")
        } catch {
            Logger.crypto.errorFile("Failed to load seed session for rid \(deepLink.rid): \(error.localizedDescription)")
            phase = .failed("Failed to load seed session: \(error.localizedDescription)")
        }
    }

    private func preparePushSupport(for deepLink: DeepLink) async throws {
        guard PushRegistrationCoordinator.isSupported, let pushCoordinator else {
            Logger.push.debugFile("Push support unavailable; continuing without APNs registration")
            return
        }

        let allowRefresh: Bool = ConfigurableKit.value(
            forKey: SettingsViewController.allowRefreshKey,
            defaultValue: false
        )
        Logger.push.infoFile("Preparing push support for rid \(deepLink.rid); allowRefresh=\(allowRefresh)")

        if allowRefresh {
            try await pushCoordinator.ensurePushToken(
                serverURL: deepLink.serverURL,
                deviceID: deepLink.deviceID,
                requestAuthorizationIfNeeded: false
            )
            return
        }

        let wantsPush = await requestPushExplanation()
        Logger.push.infoFile("Push explanation result for rid \(deepLink.rid): wantsPush=\(wantsPush)")
        guard wantsPush else { return }

        try await pushCoordinator.ensurePushToken(
            serverURL: deepLink.serverURL,
            deviceID: deepLink.deviceID,
            requestAuthorizationIfNeeded: true
        )

        ConfigurableKit.set(value: true, forKey: SettingsViewController.allowRefreshKey)
    }

    private func requestPushExplanation() async -> Bool {
        await withCheckedContinuation { continuation in
            Logger.push.debugFile("Requesting push explanation dialog")
            pushExplanationContinuation = continuation
            shouldPresentPushExplanation = true
        }
    }

    static func validateCapturedSessionData(_ sessionData: Data) throws {
        guard !sessionData.isEmpty else {
            throw UploadError.emptySessionPayload
        }

        guard
            let object = try JSONSerialization.jsonObject(with: sessionData) as? [String: Any],
            object["cookies"] != nil,
            object["origins"] != nil
        else {
            throw UploadError.invalidSessionPayload
        }
    }

    static func encodeCapturedSession(_ session: CapturedSession) throws -> Data {
        let data = try JSONEncoder().encode(session)
        try validateCapturedSessionData(data)
        return data
    }

    private static func sessionSummary(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return "bytes=\(data.count), topLevel=non-json"
        }
        return sessionSummary(for: object, bytes: data.count)
    }

    private static func sessionSummary(for object: Any, bytes: Int) -> String {
        if let dictionary = object as? [String: Any] {
            let keys = dictionary.keys.sorted().joined(separator: ",")
            var parts = ["bytes=\(bytes)", "keys=[\(keys)]"]
            if let cookies = dictionary["cookies"] as? [Any] {
                parts.append("cookies=\(cookies.count)")
            }
            if let origins = dictionary["origins"] as? [Any] {
                parts.append("origins=\(origins.count)")
            }
            if let payload = dictionary["payload"] {
                parts.append("payload=\(nestedSummary(for: payload))")
            }
            if let session = dictionary["session"] {
                parts.append("session=\(nestedSummary(for: session))")
            }
            if let storageState = dictionary["storageState"] {
                parts.append("storageState=\(nestedSummary(for: storageState))")
            }
            if let storageState = dictionary["storage_state"] {
                parts.append("storage_state=\(nestedSummary(for: storageState))")
            }
            return parts.joined(separator: ", ")
        }

        if let array = object as? [Any] {
            return "bytes=\(bytes), topLevel=array(count=\(array.count))"
        }

        return "bytes=\(bytes), topLevel=\(String(describing: type(of: object)))"
    }

    private static func nestedSummary(for object: Any) -> String {
        if let dictionary = object as? [String: Any] {
            return "dict(keys=[\(dictionary.keys.sorted().joined(separator: ","))])"
        }
        if let array = object as? [Any] {
            return "array(count=\(array.count))"
        }
        if let string = object as? String {
            return "string(chars=\(string.count))"
        }
        return String(describing: type(of: object))
    }
}
