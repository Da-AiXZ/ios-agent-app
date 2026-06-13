import Foundation

extension Notification.Name {
    /// Posted when settings are saved, so that the dependency container
    /// and root view can rewire the APIClient and AgentRuntime with
    /// the latest credentials.
    static let settingsDidChange = Notification.Name("com.ios-agent-app.settingsDidChange")
}
