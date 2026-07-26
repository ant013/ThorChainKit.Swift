import SwiftUI

@main
struct ThorChainExampleApp: App {
    private let diagnostics: DiagnosticsViewModel?
    private let unavailableMessage: String?

    init() {
        do {
            let runtime = try ExampleRuntime()
            diagnostics = DiagnosticsViewModel(runtime: runtime)
            unavailableMessage = nil
        } catch {
            diagnostics = nil
            unavailableMessage = "Unavailable — configure the approved local live input to continue."
        }
    }

    var body: some Scene {
        WindowGroup {
            if let diagnostics {
                NavigationView {
                    DiagnosticsView(model: diagnostics)
                }
            } else {
                Text(unavailableMessage ?? "Unavailable")
                    .accessibilityIdentifier("example.unavailable")
            }
        }
    }
}
