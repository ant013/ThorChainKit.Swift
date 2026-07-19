import UIKit

final class MainController: UINavigationController {
    init(runtime: ExampleRuntime) {
        super.init(rootViewController: DiagnosticsController(runtime: runtime))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}
