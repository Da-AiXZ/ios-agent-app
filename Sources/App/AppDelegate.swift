import UIKit

/// The UIApplicationDelegate for the iOS AI Programming Agent application.
///
/// Handles UIKit-level lifecycle events and provides configuration
/// for UIKit views that are bridged into the SwiftUI hierarchy, such
/// as terminal text views and other UIKit interop components.
final class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureGlobalAppearance()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    // MARK: - Private Configuration

    /// Configures global UIKit appearance settings, including
    /// terminal-style text views used for agent output display.
    private func configureGlobalAppearance() {
        // Configure UITextView for terminal-style monospaced rendering
        UITextView.appearance().backgroundColor = .clear
        UITextView.appearance().isEditable = false
        UITextView.appearance().isSelectable = true
        UITextView.appearance().textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    }
}

// MARK: - SceneDelegate

/// Minimal SceneDelegate for UIKit scene lifecycle management.
/// Bridges UIKit scene events into the SwiftUI app lifecycle.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        window.makeKeyAndVisible()
    }
}
