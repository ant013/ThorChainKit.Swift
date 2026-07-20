import SwiftUI

@main
struct ThorChainExampleApp: App {
    @StateObject private var diagnostics: DiagnosticsViewModel

    init() {
        do {
            let runtime = try ExampleRuntime()
            _diagnostics = StateObject(
                wrappedValue: DiagnosticsViewModel(runtime: runtime)
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
