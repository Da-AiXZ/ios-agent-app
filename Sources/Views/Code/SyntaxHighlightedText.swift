import SwiftUI

/// Renders source code with syntax-highlighted colors by mapping
/// highlighted ranges to token-type colors.
///
/// Displays line numbers on the left and colorized text on the
/// right. Each line is rendered as an individual `Text` element
/// for efficient incremental updates. Uses monospaced font
/// (SF Mono) for proper code alignment.
struct SyntaxHighlightedText: View {

    /// The source code to display.
    let source: String

    /// The language identifier for display purposes.
    var language: String?

    /// The highlighted ranges from the syntax service.
    var highlightedRanges: [HighlightedRange] = []

    // MARK: - Body

    var body: some View {
        let lines = source.components(separatedBy: .newlines)
        let lineCount = lines.count
        let gutterWidth = max(30, CGFloat(String(lineCount).count) * 10 + 16)

        ScrollView([.vertical, .horizontal]) {
            HStack(alignment: .top, spacing: 0) {
                // Line numbers gutter.
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(0..<lines.count, id: \.self) { index in
                        Text("\(index + 1)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: gutterWidth, alignment: .trailing)
                            .padding(.trailing, 8)
                            .padding(.vertical, 1)
                            .accessibilityLabel("Line \(index + 1)")
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))

                // Highlighted code.
                highlightedCodeView(lines: lines)
            }
        }
        .font(.system(.body, design: .monospaced))
        .dynamicTypeSize(.small ... .accessibility3)
    }

    // MARK: - Highlighted Code

    @ViewBuilder
    private func highlightedCodeView(lines: [String]) -> some View {
        if highlightedRanges.isEmpty {
            // No highlighting: plain text.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<lines.count, id: \.self) { index in
                    Text(lines[index].isEmpty ? " " : lines[index])
                        .padding(.vertical, 1)
                        .padding(.horizontal, 8)
                }
            }
        } else {
            // With highlighting: per-line token coloring.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<lines.count, id: \.self) { index in
                    highlightedLine(lines[index], lineIndex: index)
                        .padding(.vertical, 1)
                        .padding(.horizontal, 8)
                }
            }
        }
    }

    /// Renders a single line with token-based coloring.
    @ViewBuilder
    private func highlightedLine(_ line: String, lineIndex: Int) -> some View {
        let lineStart = source.distance(
            from: source.startIndex,
            to: source.components(separatedBy: .newlines).prefix(lineIndex).reduce(source.startIndex) { acc, _ in
                source.index(after: acc)
            }
        )
        let _ = lineStart // keep for potential range calculation

        if line.isEmpty {
            Text(" ")
        } else {
            // Simple approach: apply color to the entire line based on the
            // first token type found. For production, a character-by-character
            // approach would be more accurate.
            let lineRanges = highlightedRanges.filter { range in
                let lineNSRange = (source as NSString).lineRange(
                    for: NSRange(location: lineStart, length: 0)
                )
                return NSLocationInRange(range.range.location, lineNSRange)
            }

            if let firstRange = lineRanges.first {
                Text(line)
                    .foregroundColor(colorForToken(firstRange.tokenType))
            } else {
                Text(line)
                    .foregroundColor(.primary)
            }
        }
    }

    // MARK: - Token Colors

    /// Maps a syntax token type to a display color.
    private func colorForToken(_ tokenType: String) -> Color {
        switch tokenType {
        case "keyword":
            return Color(red: 0.69, green: 0.20, blue: 0.56) // Purple.
        case "string":
            return Color(red: 0.89, green: 0.36, blue: 0.20) // Orange-red.
        case "comment":
            return Color(red: 0.40, green: 0.55, blue: 0.40) // Green-gray.
        case "number":
            return Color(red: 0.20, green: 0.42, blue: 0.89) // Blue.
        case "type":
            return Color(red: 0.27, green: 0.62, blue: 0.69) // Teal.
        default:
            return .primary
        }
    }
}

// MARK: - Previews

#Preview {
    SyntaxHighlightedText(
        source: """
        import SwiftUI

        struct ContentView: View {
            var body: some View {
                Text("Hello, world!")
                    .padding()
            }
        }
        """,
        language: "swift",
        highlightedRanges: [
            HighlightedRange(range: NSRange(location: 0, length: 6), tokenType: "keyword"),
            HighlightedRange(range: NSRange(location: 29, length: 6), tokenType: "keyword"),
            HighlightedRange(range: NSRange(location: 55, length: 3), tokenType: "keyword"),
            HighlightedRange(range: NSRange(location: 78, length: 4), tokenType: "keyword"),
            HighlightedRange(range: NSRange(location: 89, length: 16), tokenType: "string"),
        ]
    )
    .frame(height: 200)
}
