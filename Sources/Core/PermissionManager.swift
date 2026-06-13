import Foundation
import Combine

// MARK: - PermissionManagerProtocol

/// Protocol for the permission manager, enabling dependency injection
/// and test mocking.
protocol PermissionManagerProtocol: AnyObject {

    /// Requests permission to execute a tool operation.
    ///
    /// The decision logic considers:
    /// - Whether the tool is read-only (auto-approve).
    /// - Whether the target path is in the trusted paths list.
    /// - User preferences for automatic approvals.
    ///
    /// - Parameters:
    ///   - toolName: The name of the tool requesting permission.
    ///   - description: A human-readable description of the operation.
    ///   - path: The file path affected by the operation, if applicable.
    /// - Returns: A `PermissionDecision` indicating the outcome.
    func requestPermission(
        toolName: String,
        description: String,
        path: String?
    ) async -> PermissionDecision

    /// Checks whether a given path is within the trusted paths set.
    ///
    /// - Parameter path: The absolute file path to check.
    /// - Returns: `true` if the path is trusted.
    func isPathTrusted(_ path: String) -> Bool

    /// Updates the auto-approve read-only setting.
    ///
    /// - Parameter enabled: Whether to auto-approve read-only operations.
    func setAutoApproveReadOnly(_ enabled: Bool)

    /// Updates the list of trusted paths.
    ///
    /// - Parameter paths: The new list of trusted directory paths.
    func setTrustedPaths(_ paths: [String])
}

// MARK: - PermissionManager

/// Manages tool execution permissions, determining whether a tool
/// invocation should be auto-approved, auto-denied, or require
/// explicit user consent.
///
/// Publishes pending permission requests via `@Published` for the
/// UI layer to display approval dialogs.
final class PermissionManager: ObservableObject, PermissionManagerProtocol {

    // MARK: - Published State

    /// A pending permission request that requires user action.
    /// The UI layer observes this to display approval sheets.
    @Published var pendingRequest: PermissionRequest?

    // MARK: - Private State

    /// Whether read-only tool operations are automatically approved.
    private var autoApproveReadOnly: Bool = false

    /// The set of directory paths that are trusted for all operations.
    private var trustedPaths: [String] = []

    /// Tools that are considered read-only and safe.
    private let readOnlyTools: Set<String> = [
        "read_file",
        "list_directory",
        "search_content",
        "search_files",
        "git_status",
        "git_diff",
        "web_search",
    ]

    // MARK: - Initialization

    init(
        autoApproveReadOnly: Bool = false,
        trustedPaths: [String] = []
    ) {
        self.autoApproveReadOnly = autoApproveReadOnly
        self.trustedPaths = trustedPaths
    }

    // MARK: - PermissionManagerProtocol

    func requestPermission(
        toolName: String,
        description: String,
        path: String?
    ) async -> PermissionDecision {
        // Check if read-only tool should be auto-approved.
        if autoApproveReadOnly && readOnlyTools.contains(toolName) {
            Logger.info("Auto-approved read-only tool: \(toolName)")
            return .approved
        }

        // Check if path is in trusted paths.
        if let path = path, isPathTrusted(path) {
            Logger.info("Auto-approved trusted path operation: \(toolName) at \(path)")
            return .approved
        }

        // Return a request for user approval.
        Logger.info("Requesting user permission for: \(toolName)")

        return await withCheckedContinuation { continuation in
            let request = PermissionRequest(
                id: UUID(),
                toolCallId: UUID().uuidString,
                toolName: toolName,
                description: description,
                path: path,
                onApprove: { [weak self] in
                    self?.pendingRequest = nil
                    continuation.resume(returning: .approved)
                },
                onDeny: { [weak self] in
                    self?.pendingRequest = nil
                    continuation.resume(returning: .denied)
                }
            )

            DispatchQueue.main.async { [weak self] in
                self?.pendingRequest = request
            }
        }
    }

    func isPathTrusted(_ path: String) -> Bool {
        for trustedPath in trustedPaths {
            if path.hasPrefix(trustedPath) {
                return true
            }
        }
        return false
    }

    func setAutoApproveReadOnly(_ enabled: Bool) {
        autoApproveReadOnly = enabled
    }

    func setTrustedPaths(_ paths: [String]) {
        trustedPaths = paths
    }
}
