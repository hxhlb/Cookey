import SnapKit
import Then
import UIKit

final class PairKeyLoadingViewController: UIViewController {
    private let serverHost: String

    private let activityIndicator = UIActivityIndicatorView(style: .large).then {
        $0.startAnimating()
    }

    private let titleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 20, weight: .semibold)
        $0.textAlignment = .center
        $0.text = String(localized: "Resolving pair key…")
    }

    private let subtitleLabel = UILabel().then {
        $0.font = .preferredFont(forTextStyle: .footnote)
        $0.textColor = .secondaryLabel
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    init(serverHost: String) {
        self.serverHost = serverHost
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.ui.infoFile("PairKeyLoadingViewController loaded for host \(serverHost)")
        view.backgroundColor = .systemBackground
        navigationItem.hidesBackButton = true

        subtitleLabel.text = String(localized: "Communicating with \(serverHost)…")

        let stack = UIStackView(arrangedSubviews: [activityIndicator, titleLabel, subtitleLabel]).then {
            $0.axis = .vertical
            $0.alignment = .center
            $0.spacing = 12
        }

        view.addSubview(stack)
        stack.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(32)
        }
    }
}
