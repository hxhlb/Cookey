import ConfigurableKit
import SnapKit
import Then
import UIKit
import UserNotifications

final class SettingsViewController: StackScrollController {
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

    static let logsObject = ConfigurableObject(
        icon: "doc.text.magnifyingglass",
        title: "View Logs",
        explain: "Inspect recent application logs for troubleshooting.",
        ephemeralAnnotation: .action { controller in
            controller.navigationController?.pushViewController(LogViewerController(), animated: true)
        }
    )

    init() {
        super.init(nibName: nil, bundle: nil)
        title = String(localized: "Settings")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: nil,
            action: nil
        ).then {
            $0.menu = UIMenu(children: [
                UIAction(
                    title: String(localized: "What's New"),
                    image: UIImage(systemName: "sparkles")
                ) { [weak self] _ in
                    self?.presentWhatsNew()
                },
                UIMenu(options: .displayInline, children: [
                    UIAction(
                        title: String(localized: "Privacy Policy"),
                        image: UIImage(systemName: "lock.shield")
                    ) { [weak self] _ in
                        self?.openPrivacyPolicy()
                    },
                    UIAction(
                        title: String(localized: "Open Source Licenses"),
                        image: UIImage(systemName: "flag.filled.and.flag.crossed")
                    ) { [weak self] _ in
                        self?.openOpenSourceLicenses()
                    },
                ]),
            ])
        }
    }

    override func setupContentViews() {
        super.setupContentViews()

        // MARK: - General

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView().with(header: String(localized: "General"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())
        stackView.addArrangedSubviewWithMargin(Self.object.createView())
        stackView.addArrangedSubview(SeparatorView())

        // MARK: - Contact Us

        stackView.addArrangedSubviewWithMargin(
            ConfigurableSectionHeaderView().with(header: String(localized: "Contact Us"))
        ) { $0.bottom /= 2 }
        stackView.addArrangedSubview(SeparatorView())
        for object in [Self.logsObject, Self.feedbackObject] {
            stackView.addArrangedSubviewWithMargin(object.createView())
            stackView.addArrangedSubview(SeparatorView())
        }

        buildBuildInfoFooter()
    }

    // MARK: - Menu Actions

    private func presentWhatsNew() {
        let controller = WelcomePageViewController.makePresentedController()
        present(controller, animated: true)
    }

    private func openPrivacyPolicy() {
        var text = String(localized: "Resource not found, please check your installation.")
        if let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "txt"),
           let content = try? String(contentsOf: url)
        { text = content }
        let vc = TextViewerController(title: String(localized: "Privacy Policy"), text: text)
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openOpenSourceLicenses() {
        var text = String(localized: "Resource not found, please check your installation.")
        if let url = Bundle.main.url(forResource: "OpenSourceLicenses", withExtension: "md"),
           let content = try? String(contentsOf: url)
        { text = content }
        let vc = TextViewerController(title: String(localized: "Open Source Licenses"), text: text)
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Build Info Footer

    private func buildBuildInfoFooter() {
        let version: String = {
            let info = Bundle.main.infoDictionary
            let marketing = info?["CFBundleShortVersionString"] as? String ?? "?"
            let build = info?["CFBundleVersion"] as? String ?? "?"
            return "Version \(marketing) (\(build))"
        }()

        let label = UILabel().then {
            $0.text = [version, BuildInfo.buildTime, String(BuildInfo.commitID.prefix(7))]
                .joined(separator: "\n")
            $0.font = .monospacedSystemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .caption2).pointSize,
                weight: .regular
            )
            $0.textColor = .tertiaryLabel
            $0.textAlignment = .center
            $0.numberOfLines = 0
        }

        let container = UIView().then {
            $0.addSubview(label)
            label.snp.makeConstraints {
                $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16))
            }
        }

        stackView.addArrangedSubview(container)
    }

    // MARK: - Notification Toggle

    @MainActor
    private static func openFeedback(_: UIViewController) async {
        Logger.ui.infoFile("Opening feedback URL from settings")
        await UIApplication.shared.open(feedbackURL)
    }

    nonisolated static func whenValueChanged(_ newValue: Bool?) -> Bool? {
        let enabled = newValue == true
        Logger.ui.infoFile("Allow Refresh Requests toggled to \(enabled)")
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                Logger.push.infoFile("Notification permission already granted; registering for remote notifications")
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            case .notDetermined:
                do {
                    Logger.push.infoFile("Notification permission not determined; requesting authorization")
                    let granted = try await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound, .badge])
                    await MainActor.run {
                        if granted {
                            Logger.push.infoFile("Notification permission granted from settings flow")
                            UIApplication.shared.registerForRemoteNotifications()
                        } else if enabled {
                            Logger.push.errorFile("Notification permission denied from settings flow; resetting toggle")
                            ConfigurableKit.set(value: false, forKey: allowRefreshKey)
                        }
                    }
                } catch {
                    if enabled {
                        Logger.push.errorFile("Notification authorization request failed: \(error.localizedDescription)")
                        await MainActor.run {
                            ConfigurableKit.set(value: false, forKey: allowRefreshKey)
                        }
                    }
                }
            default:
                if enabled {
                    Logger.push.errorFile("Notifications unavailable for Cookey; resetting refresh toggle")
                    await MainActor.run {
                        ConfigurableKit.set(value: false, forKey: allowRefreshKey)
                    }
                }
            }
        }
        return newValue
    }
}
