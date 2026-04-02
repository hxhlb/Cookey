import AlertController
import Combine
import UIKit

@MainActor
final class FlowCoordinator {
    private let navigationController: UINavigationController
    private let sessionModel: SessionUploadModel
    private var cancellables = Set<AnyCancellable>()
    private var isPushing = false

    init(navigationController: UINavigationController, sessionModel: SessionUploadModel) {
        self.navigationController = navigationController
        self.sessionModel = sessionModel
        bind()
    }

    private func bind() {
        sessionModel.$phase
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in self?.handle(phase) }
            .store(in: &cancellables)
    }

    private func handle(_ phase: SessionUploadModel.Phase) {
        guard !isPushing else { return }
        isPushing = true
        defer { isPushing = false }
        Logger.ui.infoFile("FlowCoordinator handling phase \(phase.logDescription)")

        switch phase {
        case .idle:
            navigationController.popToRootViewController(animated: true)

        case .scanning:
            let vc = ScannerViewController(sessionModel: sessionModel)
            pushAndTrimStack(vc)

        case let .resolvingPairKey(serverHost):
            let vc = PairKeyLoadingViewController(serverHost: serverHost)
            pushAndTrimStack(vc)

        case let .validating(deepLink):
            let vc = SeedLoadingViewController(deepLink: deepLink, sessionModel: sessionModel)
            pushAndTrimStack(vc)

        case let .browsing(deepLink):
            let vc = BrowserViewController(deepLink: deepLink, sessionModel: sessionModel)
            pushAndTrimStack(vc)

        case .uploading:
            let vc = UploadProgressViewController(sessionModel: sessionModel)
            pushAndTrimStack(vc)

        case .done:
            // UploadProgressVC handles this state via its own $phase subscription
            break

        case .failed:
            // If we're already on UploadProgressVC, it handles the error display.
            // Otherwise (e.g. invalid deep link from idle), show an alert on the visible VC.
            let topVC = navigationController.topViewController
            if topVC is UploadProgressViewController { break }
            let message = if case let .failed(msg) = phase { msg } else { String(localized: "An unknown error occurred.") }
            let alert = AlertViewController(title: String(localized: "Error"), message: message) { [weak self] context in
                context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                    context.dispose {
                        Logger.ui.infoFile("Dismissed flow error alert and resetting to idle")
                        self?.sessionModel.resetToIdle()
                    }
                }
            }
            topVC?.present(alert, animated: true)
        }
    }

    /// Push the new VC with animation, then trim the stack to [root, vc] so
    /// intermediate screens are removed without a visible flicker.
    private func pushAndTrimStack(_ vc: UIViewController) {
        Logger.ui.debugFile("Pushing \(String(describing: type(of: vc))) and trimming navigation stack")
        navigationController.pushViewController(vc, animated: true)
        if let root = navigationController.viewControllers.first, root !== vc {
            navigationController.viewControllers = [root, vc]
        }
    }
}

private extension SessionUploadModel.Phase {
    var logDescription: String {
        switch self {
        case .idle:
            "idle"
        case .scanning:
            "scanning"
        case let .resolvingPairKey(serverHost):
            "resolvingPairKey(\(serverHost))"
        case let .validating(deepLink):
            "validating(\(deepLink.rid), \(deepLink.requestType.rawValue))"
        case let .browsing(deepLink):
            "browsing(\(deepLink.rid), \(deepLink.requestType.rawValue))"
        case .uploading:
            "uploading"
        case .done:
            "done"
        case let .failed(message):
            "failed(\(message))"
        }
    }
}
