import AVFoundation
import UIKit

final class ScannerContainerView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()
    private let messageLabel = UILabel()
    private let settingsButton = UIButton(type: .system)
    var onOpenSettings: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black

        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.isHidden = true
        addSubview(messageLabel)

        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.setTitle(String(localized: "Open Settings"), for: .normal)
        settingsButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        settingsButton.isHidden = true
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        addSubview(settingsButton)

        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            settingsButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 16),
            settingsButton.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }

    @objc private func settingsButtonTapped() {
        onOpenSettings?()
    }

    func showMessage(_ message: String, showSettingsButton: Bool = false) {
        messageLabel.text = message
        messageLabel.isHidden = false
        settingsButton.isHidden = !showSettingsButton
    }
}
