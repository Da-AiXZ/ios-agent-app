import SwiftUI

/// Displays a side-by-side or unified diff view comparing old and
/// new versions of a file.
///
/// Added lines are highlighted in green, removed lines in red, and
/// context lines in the default background. Accept and Reject buttons
/// allow the user to either apply or discard individual changes.
struct DiffView: View {

    /// The diff chunks to display.
    let chunks: [DiffChunk]

    /// The original file content (for context).
    var originalContent: String?

    /// Called when the user accepts a specific edit.
    var onAccept: ((oldString: String, newString: String) -> Void)?

    /// Called when the user rejects/discards changes.
    var onReject: (() -> Void)?

    /// The display mode for the diff.
    var mode: DiffDisplayMode = .unified

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar.
            HStack {
                Text("Diff View")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button(action: { onReject?() }) {
                    Label("Reject All", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityLabel("Reject all changes")

                Button(action: {
                    // Accept all: no individual old/new strings, so just call onReject differently.
                    // For simplicity, we callback with empty strings for "accept all".
                    onAccept?(("", ""))
                }) {
                    Label("Accept All", systemImage: "checkmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .accessibilityLabel("Accept all changes")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))

            Divider()

            // Diff content.
            if chunks.isEmpty {
                EmptyStateView(
                    icon: "equal.circle",
                    title: "No Changes",
                    subtitle: "The files are identical."
                )
            } else {
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(chunks) { chunk in
                            VStack(alignment: .leading, spacing: 0) {
                                // Chunk header.
                                chunkHeader(chunk)

                                // Chunk lines.
                                ForEach(Array(chunk.lines.enumerated()), id: \.offset) { _, line in
                                    diffLine(line)
                                }
                            }
                        }
                    }
                }
                .font(.system(.caption, design: .monospaced))
            }
        }
        .background(Color(UIColor.systemBackground))
        .dynamicTypeSize(.small ... .accessibility3)
    }

    // MARK: - Chunk Header

    private func chunkHeader(_ chunk: DiffChunk) -> some View {
        HStack {
            Text("@ @")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("-\(chunk.oldStartLine) +\(chunk.newStartLine)")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(UIColor.tertiarySystemBackground))
    }

    // MARK: - Diff Line

    @ViewBuilder
    private func diffLine(_ line: DiffLine) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Line number.
            Text(lineNumberDisplay(line))
                .frame(width: 36, alignment: .trailing)
                .foregroundColor(.secondary)
                .padding(.trailing, 4)

            // Change indicator.
            Text(lineTypePrefix(line.type))
                .frame(width: 16, alignment: .center)
                .foregroundColor(lineTypeColor(line.type))
                .fontWeight(.bold)

            // Content.
            Text(line.content.isEmpty ? " " : line.content)
                .foregroundColor(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(lineBackgroundColor(line.type))
        .accessibilityLabel("\(lineTypeLabel(line.type)): line \(line.oldLineNumber ?? line.newLineNumber ?? 0)")
    }

    // MARK: - Helpers

    private func lineNumberDisplay(_ line: DiffLine) -> String {
        if let old = line.oldLineNumber, let new = line.newLineNumber, old == new {
            return "\(old)"
        }
        let oldStr = line.oldLineNumber.map { "\($0)" } ?? ""
        let newStr = line.newLineNumber.map { "\($0)" } ?? ""
        return "\(oldStr) \(newStr)"
    }

    private func lineTypePrefix(_ type: DiffLineType) -> String {
        switch type {
        case .added: return "+"
        case .removed: return "-"
        case .unchanged: return " "
        }
    }

    private func lineTypeColor(_ type: DiffLineType) -> Color {
        switch type {
        case .added: return .green
        case .removed: return .red
        case .unchanged: return .secondary
        }
    }

    private func lineBackgroundColor(_ type: DiffLineType) -> Color {
        switch type {
        case .added: return Color.green.opacity(0.12)
        case .removed: return Color.red.opacity(0.12)
        case .unchanged: return Color.clear
        }
    }

    private func lineTypeLabel(_ type: DiffLineType) -> String {
        switch type {
        case .added: return "Added"
        case .removed: return "Removed"
        case .unchanged: return "Unchanged"
        }
    }
}

// MARK: - DiffDisplayMode

@frozen
enum DiffDisplayMode: String, CaseIterable {
    /// Unified diff (single column, +/- prefixes).
    case unified

    /// Side-by-side diff (two columns).
    case sideBySide
}

// MARK: - Previews

#Preview {
    DiffView(
        chunks: [
            DiffChunk(
                type: .context,
                lines: [
                    DiffLine(content: "import SwiftUI", type: .unchanged, oldLineNumber: 1, newLineNumber: 1),
                ],
                oldStartLine: 1,
                newStartLine: 1
            ),
            DiffChunk(
                type: .delete,
                lines: [
                    DiffLine(content: "    let x = 10", type: .removed, oldLineNumber: 2, newLineNumber: nil),
                ],
                oldStartLine: 2,
                newStartLine: 0
            ),
            DiffChunk(
                type: .add,
                lines: [
                    DiffLine(content: "    let x = 42", type: .added, oldLineNumber: nil, newLineNumber: 2),
                ],
                oldStartLine: 0,
                newStartLine: 2
            ),
            DiffChunk(
                type: .context,
                lines: [
                    DiffLine(content: "    return x", type: .unchanged, oldLineNumber: 3, newLineNumber: 3),
                ],
                oldStartLine: 3,
                newStartLine: 3
            ),
        ],
        onAccept: { _ in },
        onReject: {}
    )
}
