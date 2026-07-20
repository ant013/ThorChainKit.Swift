import ThorChainKit
import UIKit

final class DiagnosticsController: UIViewController {
    private let runtime: ExampleRuntime

    init(runtime: ExampleRuntime) {
        self.runtime = runtime
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "THORChainKit"
        view.backgroundColor = .systemBackground
        let endpoints = UIBarButtonItem(
            title: "Endpoints",
            style: .plain,
            target: self,
            action: #selector(showEndpoints)
        )
        endpoints.accessibilityIdentifier = "endpoint-policy-open"
        navigationItem.rightBarButtonItem = endpoints

        let kit = runtime.kit
        let rows = [
            row("Data Source", value: "FIXTURE", identifier: "data-source"),
            row(
                "Network",
                value: "\(kit.network.environment.rawValue) · \(kit.network.expectedChainId)",
                identifier: "network"
            ),
            row("Address", value: kit.address.raw, identifier: "address"),
            row("Sync State", value: syncDescription(kit.syncState), identifier: "sync-state"),
            row(
                "Last Block",
                value: kit.lastBlockHeight.map(String.init) ?? "nil",
                identifier: "last-block"
            ),
            row("RUNE Balance", value: kit.runeBalance.description, identifier: "rune-balance"),
            row("Account Exists", value: String(kit.accountExists), identifier: "account-exists"),
            row(
                "Account State",
                value: kit.accountState == nil ? "nil" : "present",
                identifier: "account-state"
            ),
        ]
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])
    }

    @objc private func showEndpoints() {
        navigationController?.pushViewController(
            EndpointsController(runtime: runtime),
            animated: true
        )
    }

    private func row(_ title: String, value: String, identifier: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .caption1)
        titleLabel.text = title.uppercased()
        titleLabel.textColor = .secondaryLabel

        let valueLabel = UILabel()
        valueLabel.accessibilityIdentifier = identifier
        valueLabel.font = .preferredFont(forTextStyle: .body)
        valueLabel.numberOfLines = 0
        valueLabel.text = value

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }

    private func syncDescription(_ state: SyncState) -> String {
        switch state {
        case let .idle(cached):
            return "idle(cached: \(cached))"
        case let .syncing(previous):
            return "syncing(previous: \(previous == nil ? "nil" : "present"))"
        case .synced:
            return "synced"
        case let .notSynced(error, cached):
            return "notSynced(\(error), cached: \(cached == nil ? "nil" : "present"))"
        }
    }
}
