import SwiftUI

/// The main entry point for the iOS AI Programming Agent application.
///
/// Creates the dependency injection container and injects both the
/// container and the shared app state into the SwiftUI environment
/// for access by all child views. The root view is `AppRootView`.
@main
struct AppMain: App {

    // MARK: - State Objects

    /// The global dependency injection container holding all
    /// service, core engine, and ViewModel factory singletons.
    @StateObject private var container = DependencyContainer()

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(container)
                .environmentObject(container.appState)
        }
    }
}
