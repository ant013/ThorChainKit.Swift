import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let runtime: ExampleRuntime
        do {
            runtime = try ExampleRuntime()
        } catch {
            fatalError("Unable to construct fixture runtime")
        }

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = MainController(runtime: runtime)
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
