@_spi(Testing) import ThorChainKit
import UIKit

final class EndpointsController: UIViewController {
    private let runtime: ExampleRuntime
    private let output = UIStackView()

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
        title = "Endpoint Policy"
        view.backgroundColor = .systemBackground

        let controls = UIStackView(arrangedSubviews: [
            button("Healthy", identifier: "endpoint-scenario-healthy", action: #selector(loadHealthy)),
            button("Mixed", identifier: "endpoint-scenario-mixed", action: #selector(loadMixed)),
            button("Catching Up", identifier: "endpoint-scenario-catching-up", action: #selector(loadCatchingUp)),
            button("Stale Cosmos", identifier: "endpoint-scenario-stale-cosmos", action: #selector(loadStaleCosmos)),
        ])
        controls.axis = .vertical
        controls.spacing = 8
        output.axis = .vertical
        output.spacing = 12

        let stack = UIStackView(arrangedSubviews: [controls, output])
        stack.axis = .vertical
        stack.spacing = 24
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

        load(.healthy)
    }

    private func button(
        _ title: String,
        identifier: String,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.accessibilityIdentifier = identifier
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func loadHealthy() { load(.healthy) }
    @objc private func loadMixed() { load(.mixedIdentity) }
    @objc private func loadCatchingUp() { load(.catchingUp) }
    @objc private func loadStaleCosmos() { load(.staleCosmos) }

    private func load(_ script: TestingEndpointPolicySession.Script) {
        Task { [weak self] in
            guard let self else { return }
            let snapshot = await runtime.endpointSnapshot(script: script)
            render([
                ("Selected", snapshot.selectedFamilyId ?? "nil", "endpoint-selected-family"),
                ("Expected Identity", snapshot.expectedChainId, "endpoint-expected-identity"),
                ("Identity", snapshot.identityClassification, "endpoint-identity"),
                ("Cosmos Origin", origin(snapshot.cosmosOrigin), "endpoint-cosmos-origin"),
                ("Comet Origin", origin(snapshot.cometOrigin), "endpoint-comet-origin"),
                ("Cosmos Height", snapshot.cosmosHeight.map(String.init) ?? "nil", "endpoint-cosmos-height"),
                ("Comet Height", snapshot.cometHeight.map(String.init) ?? "nil", "endpoint-comet-height"),
                ("Height Skew", snapshot.heightSkew.map(String.init) ?? "nil", "endpoint-height-skew"),
                ("Catching Up", String(snapshot.catchingUp), "endpoint-catching-up"),
                ("Rejection", snapshot.rejectionReason ?? "none", "endpoint-rejection"),
            ])
        }
    }

    private func render(_ rows: [(String, String, String)]) {
        output.arrangedSubviews.forEach {
            output.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rows.map { row($0.0, $0.1, $0.2) }.forEach(output.addArrangedSubview)
    }

    private func row(_ title: String, _ value: String, _ identifier: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .caption1)
        titleLabel.text = title.uppercased()
        titleLabel.textColor = .secondaryLabel
        let valueLabel = UILabel()
        valueLabel.accessibilityIdentifier = identifier
        valueLabel.font = .preferredFont(forTextStyle: .body)
        valueLabel.text = value
        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }

    private func origin(_ value: TestingEndpointPolicySnapshot.Origin) -> String {
        "\(value.scheme)://\(value.host)\(value.port.map { ":\($0)" } ?? "")"
    }
}
