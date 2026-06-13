import SwiftUI

/// Displays a single tool invocation as a collapsible card showing
/// the tool name, status, icon, and optional output.
///
/// Maps each of the 12 tool names to a representative emoji and
/// uses status-dependent colors to indicate execution progress.
struct ToolCallCard: View {

    /// The tool call state to display.
    let toolCall: ToolCallState

    /// Called when the user approves this tool.
    var onApprove: (() -> Void)?

    /// Called when the user denies this tool.
    var onDeny: (() -> Void)?

    // MARK: - State

    @State private var isExpanded: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header: icon + name + status badge.
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Text(iconForTool(toolCall.name))
                        .font(.body)
                        .accessibilityHidden(true)

                    Text(toolCall.description.isEmpty ? toolCall.name : toolCall.description)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .accessibilityLabel("Tool: \(toolCall.name)")

                    Spacer()

                    statusBadge
                        .accessibilityLabel("Status: \(toolCall.status.rawValue)")

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tool call: \(toolCall.name)")

            // Expanded details.
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()

                    // Output or error.
                    if let output = toolCall.output, !output.isEmpty {
                        Text(output)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .accessibilityLabel("Tool output: \(output)")
                    }

                    if let error = toolCall.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .accessibilityLabel("Tool error: \(error)")
                    }

                    // Permission buttons.
                    if toolCall.status == .waitingPermission {
                        HStack(spacing: 12) {
                            Button(action: { onDeny?() }) {
                                Label("Deny", systemImage: "xmark.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .accessibilityLabel("Deny tool execution")

                            Button(action: { onApprove?() }) {
                                Label("Approve", systemImage: "checkmark.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .accessibilityLabel("Approve tool execution")
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .background(statusBackgroundColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusBorderColor.opacity(0.3), lineWidth: 1)
        )
        .dynamicTypeSize(.small ... .accessibility3)
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        switch toolCall.status {
        case .pending:
            Text("Pending")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .clipShape(Capsule())

        case .waitingPermission:
            HStack(spacing: 4) {
                Circle().fill(Color.orange).frame(width: 6, height: 6)
                Text("Approval")
                    .font(.caption2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .clipShape(Capsule())

        case .executing:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Running")
                    .font(.caption2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.15))
            .clipShape(Capsule())

        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                Text("Done")
                    .font(.caption2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.15))
            .clipShape(Capsule())

        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                Text("Failed")
                    .font(.caption2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red.opacity(0.15))
            .clipShape(Capsule())

        case .denied:
            HStack(spacing: 4) {
                Image(systemName: "slash.circle.fill")
                    .font(.caption2)
                Text("Denied")
                    .font(.caption2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.15))
            .clipShape(Capsule())
        }
    }

    // MARK: - Tool Icon Mapping

    /// Returns the emoji icon for the given tool name.
    private func iconForTool(_ name: String) -> String {
        switch name.lowercased() {
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

    // MARK: - Status Colors

    private var statusBackgroundColor: Color {
        switch toolCall.status {
        case .pending: return .secondary
        case .waitingPermission: return .orange
        case .executing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .denied: return .gray
        }
    }

    private var statusBorderColor: Color {
        statusBackgroundColor
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 12) {
        ToolCallCard(toolCall: ToolCallState(
            id: "1", name: "read_file", description: "Read src/main.swift",
            status: .completed, output: "import SwiftUI\n\nstruct MainView {}"
        ))
        ToolCallCard(toolCall: ToolCallState(
            id: "2", name: "execute_shell", description: "Run swift build",
            status: .executing
        ))
        ToolCallCard(toolCall: ToolCallState(
            id: "3", name: "write_file", description: "Write to config.json",
            status: .waitingPermission
        ), onApprove: {}, onDeny: {})
        ToolCallCard(toolCall: ToolCallState(
            id: "4", name: "git_diff", description: "Show staged changes",
            status: .failed, errorMessage: "Not a git repository"
        ))
    }
    .padding()
}
