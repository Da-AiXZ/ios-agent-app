import SwiftUI

/// A modal permission confirmation dialog shown when a tool requires
/// explicit user approval before execution.
///
/// Displays the tool name, a description of what it will do, and
/// Approve/Deny buttons that dispatch the corresponding intents
/// to the ChatViewModel.
struct PermissionDialogView: View {

    /// The tool call state requiring permission.
    let toolCall: ToolCallState

    /// Called when the user approves the tool execution.
    var onApprove: () -> Void

    /// Called when the user denies the tool execution.
    var onDeny: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header.
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                    .accessibilityHidden(true)

                Text("Permission Required")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .accessibilityAddTraits(.isHeader)

                Text("Allow \"\(toolCall.name)\" to execute?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Allow \(toolCall.name) to execute?")
            }
            .padding(20)

            Divider()

            // Description.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(toolIcon)
                        .font(.title3)
                        .accessibilityHidden(true)
                    Text(toolCall.description.isEmpty ? toolCall.name : toolCall.description)
                        .font(.body)
                        .foregroundColor(.primary)
                        .accessibilityLabel("Operation: \(toolCall.description)")
                }

                if let output = toolCall.output, !output.isEmpty {
                    Text(output)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .accessibilityLabel("Details: \(output)")
                }
            }
            .padding(16)

            Divider()

            // Actions.
            HStack(spacing: 16) {
                Button(action: onDeny) {
                    Label("Deny", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
                .accessibilityLabel("Deny permission for \(toolCall.name)")

                Button(action: onApprove) {
                    Label("Approve", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .accessibilityLabel("Approve permission for \(toolCall.name)")
            }
            .padding(16)
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 24)
        .dynamicTypeSize(.small ... .accessibility3)
    }

    // MARK: - Tool Icon

    private var toolIcon: String {
        switch toolCall.name.lowercased() {
        case "read_file": return "📄"
        case "write_file": return "✏️"
        case "edit_file": return "✂️"
        case "list_directory": return "📁"
        case "search_content": return "🔍"
        case "search_files": return "🔎"
        case "execute_shell": return "⚡"
        case "git_diff": return "📊"
        case "git_status": return "📋"
        case "git_commit": return "📝"
        case "delete_file": return "🗑️"
        case "web_search": return "🌐"
        default: return "🔧"
        }
    }
}

// MARK: - View Modifier

extension View {

    /// Shows a permission dialog overlay when a tool call requires approval.
    func permissionDialog(
        toolCall: ToolCallState?,
        onApprove: @escaping () -> Void,
        onDeny: @escaping () -> Void
    ) -> some View {
        ZStack {
            self

            if let toolCall = toolCall {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .accessibilityHidden(true)

                PermissionDialogView(
                    toolCall: toolCall,
                    onApprove: onApprove,
                    onDeny: onDeny
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: toolCall != nil)
    }
}

// MARK: - Previews

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        PermissionDialogView(
            toolCall: ToolCallState(
                id: "1",
                name: "write_file",
                description: "Write to src/Config.swift",
                status: .waitingPermission,
                output: "Path: /project/src/Config.swift\nSize: 2.3 KB"
            ),
            onApprove: {},
            onDeny: {}
        )
    }
}
