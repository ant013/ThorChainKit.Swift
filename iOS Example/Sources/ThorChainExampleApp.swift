import SwiftUI

@main
struct ThorChainExampleApp: App {
    @StateObject private var diagnostics: DiagnosticsViewModel

    init() {
        do {
            _diagnostics = StateObject(
                wrappedValue: DiagnosticsViewModel(runtime: try ExampleRuntime())
            )
        } catch {
            fatalError("Unable to construct fixture runtime")
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationView {
                DiagnosticsView(model: diagnostics)
            }
        }
    }
}
