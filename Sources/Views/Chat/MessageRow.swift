import SwiftUI

/// Renders a single message row in the chat list.
///
/// User messages appear right-aligned in blue bubbles, assistant
/// messages left-aligned in gray bubbles with Markdown content,
/// and tool messages display as inline `ToolCallCard` components.
struct MessageRow: View {

    /// The message to render.
    let message: Message

    /// Associated tool call states for this message's tool calls.
    var toolCallStates: [ToolCallState] = []

    /// Called when the user approves a specific tool.
    var onApproveTool: ((String) -> Void)?

    /// Called when the user denies a specific tool.
    var onDenyTool: ((String) -> Void)?

    // MARK: - Body

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantBubble
        case .tool:
            toolResultRow
        case .system:
            systemMessage
        }
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 60)

            VStack(alignment: .trailing, spacing: 2) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .accessibilityLabel("You said: \(message.content)")

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Sent at \(message.timestamp.formatted())")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Assistant Bubble

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text("🤖")
                    .font(.title3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    if !message.content.isEmpty {
                        MarkdownRenderer(text: message.content)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .accessibilityLabel("Assistant: \(message.content)")
                    }

                    // Tool call cards.
                    if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                        ForEach(toolCalls, id: \.id) { tc in
                            if let state = toolCallStates.first(where: { $0.id == tc.id }) {
                                ToolCallCard(
                                    toolCall: state,
                                    onApprove: { onApproveTool?(tc.id) },
                                    onDeny: { onDenyTool?(tc.id) }
                                )
                            } else {
                                ToolCallCard(
                                    toolCall: ToolCallState(
                                        id: tc.id,
                                        name: tc.name,
                                        description: tc.name,
                                        status: .pending
                                    )
                                )
                            }
                        }
                    }
                }

                Spacer(minLength: 40)
            }

            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 40)
                .accessibilityLabel("Received at \(message.timestamp.formatted())")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Tool Result Row

    private var toolResultRow: some View {
        HStack {
            Spacer(minLength: 40)
            Text("🔧 Tool result: \(message.content.prefix(100))")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Tool result: \(message.content)")
            Spacer(minLength: 40)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    // MARK: - System Message

    private var systemMessage: some View {
        HStack {
            Spacer()
            Text(message.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .accessibilityLabel("System: \(message.content)")
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Previews

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            MessageRow(message: Message(
                role: .user,
                content: "Can you read main.swift and fix the compilation error?",
                timestamp: Date()
            ))
            MessageRow(message: Message(
                role: .assistant,
                content: "I'll read the file and identify the issue.",
                toolCalls: [ToolCall(id: "1", name: "read_file", arguments: "{\"path\":\"src/main.swift\"}")],
                timestamp: Date()
            ), toolCallStates: [
                ToolCallState(id: "1", name: "read_file", description: "Read src/main.swift", status: .completed, output: "File contents here...")
            ])
            MessageRow(message: Message(
                role: .tool,
                content: "import SwiftUI\n\nstruct MainView: View {\n    var body: some View {\n        Text(\"Hello\")\n    }\n}",
                timestamp: Date()
            ))
        }
    }
    .background(Color(UIColor.systemBackground))
}
