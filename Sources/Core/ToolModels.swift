import Foundation

// MARK: - PermissionRequest

/// A pending permission request that requires user approval.
///
/// When `PermissionManager` determines that a tool invocation needs
/// explicit user consent, it creates a `PermissionRequest` and publishes
/// it for the UI layer to display an approval dialog.
struct PermissionRequest: Identifiable {

    /// Unique identifier for this permission request.
    let id: UUID

    /// The ID of the tool call that triggered this request.
    let toolCallId: String

    /// The name of the tool being invoked.
    let toolName: String

    /// A human-readable description of what the tool will do.
    let description: String

    /// The file path affected by this tool, if applicable.
    /// `nil` for tools that don't operate on files.
    let path: String?

    /// Closure called when the user approves the request.
    let onApprove: () -> Void

    /// Closure called when the user denies the request.
    let onDeny: () -> Void
}

// MARK: - PermissionDecision

/// The outcome of a permission check.
@frozen
enum PermissionDecision {
    /// The operation is automatically approved (read-only or trusted path).
    case approved

    /// The operation is automatically denied (blocked path or policy).
    case denied

    /// The operation requires explicit user approval via the UI.
    case askUser(PermissionRequest)
}
