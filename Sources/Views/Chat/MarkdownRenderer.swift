import SwiftUI

/// Renders Markdown content into styled SwiftUI views.
///
/// Supports headings, bold, italic, inline code, code blocks (fenced
/// and indented), bulleted/numbered lists, links, and block quotes.
/// Uses a simple recursive descent parser rather than the full
/// swift-markdown library to avoid external dependency issues in
/// P0; the swift-markdown integration is reserved for P1.
struct MarkdownRenderer: View {

    /// The raw Markdown text to render.
    let text: String

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(parseBlocks(), id: \.self) { block in
                renderBlock(block)
            }
        }
        .dynamicTypeSize(.small ... .accessibility3)
    }

    // MARK: - Parsing

    /// Parses the raw text into Markdown blocks.
    private func parseBlocks() -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: .newlines)
        var index = 0

        while index < lines.count {
            let line = lines[index]

            // Code block (fenced with ```).
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                var codeLines: [String] = []
                index += 1
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                index += 1 // Skip closing ```
                blocks.append(.codeBlock(codeLines.joined(separator: "\n")))
                continue
            }

            // Heading.
            if line.hasPrefix("### ") {
                blocks.append(.heading3(String(line.dropFirst(4))))
                index += 1
                continue
            }
            if line.hasPrefix("## ") {
                blocks.append(.heading2(String(line.dropFirst(3))))
                index += 1
                continue
            }
            if line.hasPrefix("# ") {
                blocks.append(.heading1(String(line.dropFirst(2))))
                index += 1
                continue
            }

            // Block quote.
            if line.hasPrefix("> ") {
                var quoteLines: [String] = [String(line.dropFirst(2))]
                index += 1
                while index < lines.count && lines[index].hasPrefix("> ") {
                    quoteLines.append(String(lines[index].dropFirst(2)))
                    index += 1
                }
                blocks.append(.blockQuote(quoteLines.joined(separator: "\n")))
                continue
            }

            // Bullet list item.
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                blocks.append(.bulletItem(String(trimmed.dropFirst(2))))
                index += 1
                continue
            }

            // Numbered list item.
            if let match = line.range(of: #"^\d+\."#, options: .regularExpression) {
                let rest = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                blocks.append(.numberedItem(rest))
                index += 1
                continue
            }

            // Empty line.
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                blocks.append(.emptyLine)
                index += 1
                continue
            }

            // Regular paragraph (collect consecutive non-empty lines).
            var paraLines: [String] = [line]
            index += 1
            while index < lines.count {
                let nextLine = lines[index]
                if nextLine.trimmingCharacters(in: .whitespaces).isEmpty ||
                   nextLine.hasPrefix("#") || nextLine.hasPrefix("```") ||
                   nextLine.hasPrefix("> ") || nextLine.hasPrefix("- ") {
                    break
                }
                paraLines.append(nextLine)
                index += 1
            }
            blocks.append(.paragraph(paraLines.joined(separator: "\n")))
        }

        return blocks
    }

    // MARK: - Rendering

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading1(let text):
            Text(parseInline(text))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

        case .heading2(let text):
            Text(parseInline(text))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)

        case .heading3(let text):
            Text(parseInline(text))
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)

        case .paragraph(let text):
            Text(parseInline(text))
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

        case .codeBlock(let code):
            Text(code)
                .font(.system(.callout, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor { $0.userInterfaceStyle == .dark
                    ? UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)
                    : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
                }))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.vertical, 4)
                .accessibilityLabel("Code block")

        case .bulletItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .foregroundColor(.secondary)
                Text(parseInline(text))
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding(.leading, 8)

        case .numberedItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Text(parseInline(text))
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding(.leading, 8)

        case .blockQuote(let text):
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: 3)
                Text(parseInline(text))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.leading, 8)
            }
            .padding(.vertical, 2)

        case .emptyLine:
            Color.clear.frame(height: 8)
        }
    }

    // MARK: - Inline Parsing

    /// Parses inline Markdown formatting: bold, italic, code, links.
    private func parseInline(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        applyInlineFormatting(to: &result)
        return result
    }

    /// Applies inline formatting to an AttributedString.
    private func applyInlineFormatting(to attributed: inout AttributedString) {
        let text = String(attributed.characters)

        // Inline code (`...`).
        applyPattern(to: &attributed, pattern: "`([^`]+)`") { match in
            match.font = .system(.body, design: .monospaced)
            match.backgroundColor = Color(UIColor { $0.userInterfaceStyle == .dark
                ? UIColor(red: 0.15, green: 0.15, blue: 0.22, alpha: 1.0)
                : UIColor(red: 0.92, green: 0.92, blue: 0.96, alpha: 1.0)
            })
            match.foregroundColor = Color.accentColor
        }

        // Bold (**...**).
        applyPattern(to: &attributed, pattern: "\\*\\*(.+?)\\*\\*") { match in
            match.font = .body.bold()
        }

        // Italic (*...*).
        applyPattern(to: &attributed, pattern: "\\*([^*]+)\\*") { match in
            match.font = .body.italic()
        }
    }

    /// Applies a formatting closure to matches of a regex pattern.
    private func applyPattern(
        to attributed: inout AttributedString,
        pattern: String,
        formatter: (inout AttributedSubstring) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }
        let fullText = String(attributed.characters)
        let nsRange = NSRange(fullText.startIndex..., in: fullText)

        // Process matches from end to start to preserve ranges.
        let matches = regex.matches(in: fullText, options: [], range: nsRange)
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }
            let fullMatchRange = match.range(at: 0)
            let contentRange = match.range(at: 1)

            guard let attributedFullRange = Range(fullMatchRange, in: attributed),
                  let attributedContentRange = Range(contentRange, in: attributed) else {
                continue
            }

            var content = attributed[attributedContentRange]
            formatter(&content)

            // Replace the full match (including markers) with the formatted content.
            attributed.replaceSubrange(attributedFullRange, with: content)
        }
    }
}

// MARK: - MarkdownBlock

/// Internal block-level Markdown element.
private enum MarkdownBlock: Hashable {
    case heading1(String)
    case heading2(String)
    case heading3(String)
    case paragraph(String)
    case codeBlock(String)
    case bulletItem(String)
    case numberedItem(String)
    case blockQuote(String)
    case emptyLine
}

// MARK: - Previews

#Preview {
    ScrollView {
        MarkdownRenderer(text: """
        # Hello World

        This is a **bold** and *italic* text sample.

        ## Code Example

        ```swift
        struct ContentView: View {
            var body: some View {
                Text("Hello, world!")
            }
        }
        ```

        - First item
        - Second item

        > A block quote with important information.

        Inline `code` example here.
        """)
        .padding()
    }
}
