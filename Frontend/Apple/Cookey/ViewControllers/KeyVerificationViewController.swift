import SnapKit
import Then
import UIKit

final class KeyVerificationViewController: UIViewController {
    private let verificationState: KeyVerificationState
    private let onResponse: (Bool) -> Void

    private let iconView = UIImageView().then {
        $0.contentMode = .scaleAspectFit
        $0.tintColor = .label
    }

    private let titleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 22, weight: .bold)
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    private let messageLabel = UILabel().then {
        $0.font = .preferredFont(forTextStyle: .subheadline)
        $0.textColor = .secondaryLabel
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    private let fingerprintContainer = UIView().then {
        $0.backgroundColor = .secondarySystemBackground
        $0.layer.cornerRadius = 12
    }

    private let fingerprintLabel = UILabel().then {
        $0.font = .monospacedSystemFont(ofSize: 16, weight: .medium)
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    private let oldFingerprintLabel = UILabel().then {
        $0.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        $0.textAlignment = .center
        $0.numberOfLines = 0
        $0.textColor = .secondaryLabel
    }

    private let oldFingerprintHeader = UILabel().then {
        $0.font = .preferredFont(forTextStyle: .caption1)
        $0.textColor = .tertiaryLabel
        $0.textAlignment = .center
        $0.text = String(localized: "Previous fingerprint")
    }

    private let newFingerprintHeader = UILabel().then {
        $0.font = .preferredFont(forTextStyle: .caption1)
        $0.textColor = .tertiaryLabel
        $0.textAlignment = .center
        $0.text = String(localized: "New fingerprint")
    }

    private lazy var trustButton = UIButton(configuration: .filled()).then {
        $0.addTarget(self, action: #selector(trustTapped), for: .touchUpInside)
    }

    private lazy var rejectButton = UIButton(configuration: .plain()).then {
        $0.setTitle(String(localized: "Reject"), for: .normal)
        $0.setTitleColor(.systemRed, for: .normal)
        $0.addTarget(self, action: #selector(rejectTapped), for: .touchUpInside)
    }

    init(verificationState: KeyVerificationState, onResponse: @escaping (Bool) -> Void) {
        self.verificationState = verificationState
        self.onResponse = onResponse
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        isModalInPresentation = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureForState()
        layoutUI()
    }

    private func configureForState() {
        switch verificationState {
        case let .firstTime(fingerprint):
            iconView.image = UIImage(systemName: "desktopcomputer")
            titleLabel.text = String(localized: "New Computer")
            messageLabel.text = String(localized: "Verify this fingerprint matches what your terminal shows.")
            fingerprintLabel.text = fingerprint
            trustButton.setTitle(String(localized: "Trust"), for: .normal)

        case let .keyChanged(oldFingerprint, newFingerprint):
            iconView.image = UIImage(systemName: "exclamationmark.shield.fill")
            iconView.tintColor = .systemOrange
            titleLabel.text = String(localized: "Security Warning")
            titleLabel.textColor = .systemOrange
            messageLabel.text = String(localized: "The identity of this computer has changed since you last connected. This could indicate a security issue, or the command-line tool may have been reinstalled.")
            fingerprintLabel.text = newFingerprint
            oldFingerprintLabel.text = oldFingerprint
            trustButton.setTitle(String(localized: "Trust New Key"), for: .normal)

        case let .knownKeyNewDevice(fingerprint):
            iconView.image = UIImage(systemName: "arrow.triangle.2.circlepath")
            titleLabel.text = String(localized: "Known Key, New Device")
            messageLabel.text = String(localized: "This key was previously trusted under a different device identifier. This may indicate the command-line tool was migrated or reinstalled.")
            fingerprintLabel.text = fingerprint
            trustButton.setTitle(String(localized: "Trust"), for: .normal)

        case .trusted:
            break
        }
    }

    private func layoutUI() {
        let isKeyChanged = {
            if case .keyChanged = verificationState { return true }
            return false
        }()

        var arrangedSubviews: [UIView] = [iconView, titleLabel, messageLabel]

        if isKeyChanged {
            let oldStack = UIStackView(arrangedSubviews: [oldFingerprintHeader, oldFingerprintLabel]).then {
                $0.axis = .vertical
                $0.spacing = 4
                $0.alignment = .center
            }

            let newStack = UIStackView(arrangedSubviews: [newFingerprintHeader, fingerprintLabel]).then {
                $0.axis = .vertical
                $0.spacing = 4
                $0.alignment = .center
            }

            let separator = UIView().then {
                $0.backgroundColor = .separator
            }
            separator.snp.makeConstraints { $0.height.equalTo(1) }

            let comparisonStack = UIStackView(arrangedSubviews: [oldStack, separator, newStack]).then {
                $0.axis = .vertical
                $0.spacing = 12
                $0.alignment = .fill
            }

            fingerprintContainer.addSubview(comparisonStack)
            comparisonStack.snp.makeConstraints {
                $0.edges.equalToSuperview().inset(16)
            }
            arrangedSubviews.append(fingerprintContainer)
        } else {
            fingerprintContainer.addSubview(fingerprintLabel)
            fingerprintLabel.snp.makeConstraints {
                $0.edges.equalToSuperview().inset(16)
            }
            arrangedSubviews.append(fingerprintContainer)
        }

        let buttonStack = UIStackView(arrangedSubviews: [trustButton, rejectButton]).then {
            $0.axis = .vertical
            $0.spacing = 8
            $0.alignment = .fill
        }
        arrangedSubviews.append(buttonStack)

        let mainStack = UIStackView(arrangedSubviews: arrangedSubviews).then {
            $0.axis = .vertical
            $0.alignment = .center
            $0.spacing = 20
        }

        view.addSubview(mainStack)
        mainStack.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(32)
        }

        iconView.snp.makeConstraints { $0.width.height.equalTo(48) }
        fingerprintContainer.snp.makeConstraints { $0.leading.trailing.equalToSuperview() }
        buttonStack.snp.makeConstraints { $0.leading.trailing.equalToSuperview() }
        trustButton.snp.makeConstraints { $0.height.equalTo(50) }
        rejectButton.snp.makeConstraints { $0.height.equalTo(44) }
    }

    @objc private func trustTapped() {
        Logger.ui.infoFile("User tapped Trust on CLI verification")
        dismiss(animated: true) { [onResponse] in
            onResponse(true)
        }
    }

    @objc private func rejectTapped() {
        Logger.ui.infoFile("User tapped Reject on CLI verification")
        dismiss(animated: true) { [onResponse] in
            onResponse(false)
        }
    }
}
