import Foundation

// MARK: - SyntaxHighlightServiceProtocol

/// Protocol for syntax highlighting, enabling dependency injection
/// and test mocking.
protocol SyntaxHighlightServiceProtocol: AnyObject {

    /// Highlights source code and returns a list of highlighted ranges.
    ///
    /// Uses Neon (tree-sitter wrapper) under the hood. The result is
    /// a list of `HighlightedRange` values that map character ranges
    /// to token types (e.g., "keyword", "string", "comment").
    ///
    /// - Parameters:
    ///   - source: The source code to highlight.
    ///   - language: The programming language identifier.
    ///   - theme: The color theme to apply (light/dark).
    /// - Returns: An array of `HighlightedRange` values.
    func highlight(
        source: String,
        language: String,
        theme: SyntaxTheme
    ) -> [HighlightedRange]

    /// Returns the list of supported language identifiers.
    func supportedLanguages() -> [String]

    /// Detects the programming language from a file extension.
    ///
    /// - Parameter fileExtension: The file extension (without dot).
    /// - Returns: The language identifier, or `nil` if unknown.
    func detectLanguage(fileExtension: String) -> String?
}

// MARK: - HighlightedRange

/// A range of text within source code that should be rendered
/// with a specific syntax token type.
struct HighlightedRange: Codable, Equatable {

    /// The character range within the source text.
    let range: NSRange

    /// The syntax token type (e.g., "keyword", "string", "comment").
    let tokenType: String

    // MARK: - Codable support for NSRange

    enum CodingKeys: String, CodingKey {
        case location, length, tokenType
    }

    init(range: NSRange, tokenType: String) {
        self.range = range
        self.tokenType = tokenType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let location = try container.decode(Int.self, forKey: .location)
        let length = try container.decode(Int.self, forKey: .length)
        range = NSRange(location: location, length: length)
        tokenType = try container.decode(String.self, forKey: .tokenType)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(range.location, forKey: .location)
        try container.encode(range.length, forKey: .length)
        try container.encode(tokenType, forKey: .tokenType)
    }
}

// MARK: - SyntaxTheme

/// The color theme for syntax highlighting.
@frozen
enum SyntaxTheme: String, Codable, CaseIterable {
    case light
    case dark
}

// MARK: - SyntaxHighlightService

/// Provides syntax highlighting for source code using supported
/// tokenizers.
///
/// P0 implementation uses a simple keyword-based tokenizer for
/// common languages. P1 will integrate Neon (tree-sitter) for
/// full incremental highlighting.
final class SyntaxHighlightService: SyntaxHighlightServiceProtocol {

    // MARK: - Language Map

    /// Mapping from file extension to language identifier.
    private let extensionToLanguage: [String: String] = [
        "swift": "swift",
        "m": "objective-c",
        "h": "objective-c",
        "c": "c",
        "cpp": "cpp",
        "py": "python",
        "js": "javascript",
        "ts": "typescript",
        "tsx": "typescriptreact",
        "jsx": "javascriptreact",
        "html": "html",
        "css": "css",
        "scss": "scss",
        "json": "json",
        "xml": "xml",
        "yaml": "yaml",
        "yml": "yaml",
        "md": "markdown",
        "rb": "ruby",
        "go": "go",
        "rs": "rust",
        "java": "java",
        "kt": "kotlin",
        "sh": "shell",
        "zsh": "shell",
        "bash": "shell",
    ]

    // MARK: - Keyword Sets

    /// Swift keywords for P0 tokenizer.
    private let swiftKeywords: Set<String> = [
        "class", "struct", "enum", "protocol", "extension", "func", "var", "let",
        "if", "else", "switch", "case", "default", "for", "while", "repeat",
        "return", "break", "continue", "guard", "defer", "do", "catch", "try",
        "throw", "throws", "async", "await", "in", "where", "is", "as", "import",
        "public", "private", "internal", "fileprivate", "open", "final", "static",
        "mutating", "nonmutating", "override", "required", "convenience", "lazy",
        "weak", "unowned", "self", "Self", "super", "nil", "true", "false",
        "init", "deinit", "typealias", "associatedtype", "some", "any",
        "actor", "nonisolated", "isolated", "borrowing", "consuming",
    ]

    /// Python keywords for P0 tokenizer.
    private let pythonKeywords: Set<String> = [
        "def", "class", "import", "from", "if", "elif", "else", "for", "while",
        "return", "break", "continue", "try", "except", "finally", "raise",
        "with", "as", "pass", "yield", "lambda", "and", "or", "not", "in", "is",
        "True", "False", "None", "self", "global", "nonlocal", "async", "await",
    ]

    /// JavaScript/TypeScript keywords.
    private let jsKeywords: Set<String> = [
        "function", "class", "const", "let", "var", "if", "else", "for", "while",
        "return", "break", "continue", "switch", "case", "default", "import",
        "export", "from", "try", "catch", "finally", "throw", "new", "this",
        "super", "async", "await", "typeof", "instanceof", "extends", "null",
        "undefined", "true", "false", "interface", "type", "enum",
    ]

    // MARK: - Initialization

    init() {}

    // MARK: - SyntaxHighlightServiceProtocol

    func highlight(
        source: String,
        language: String,
        theme: SyntaxTheme
    ) -> [HighlightedRange] {
        // P0: Simple keyword + string + comment tokenizer.
        var ranges: [HighlightedRange] = []
        let keywords: Set<String>

        switch language.lowercased() {
        case "swift":
            keywords = swiftKeywords
        case "python":
            keywords = pythonKeywords
        case "javascript", "typescript", "javascriptreact", "typescriptreact":
            keywords = jsKeywords
        case "java", "kotlin", "go", "rust", "c", "cpp", "ruby":
            keywords = jsKeywords // Generic fallback.
        default:
            keywords = []
        }

        // Tokenize by scanning the source.
        let scanner = Scanner(string: source)
        scanner.charactersToBeSkipped = nil

        var currentIndex = 0

        while !scanner.isAtEnd {
            // Skip whitespace.
            if let whitespace = scanner.scanCharacters(from: .whitespaces) {
                currentIndex += whitespace.count
                continue
            }

            // Line comments (// ...).
            if source.dropFirst(currentIndex).hasPrefix("//") {
                var commentText = ""
                while !scanner.isAtEnd {
                    if let char = scanner.scanCharacter() {
                        if char == "\n" { break }
                        commentText.append(char)
                    }
                }
                ranges.append(HighlightedRange(
                    range: NSRange(location: currentIndex, length: commentText.count + 2),
                    tokenType: "comment"
                ))
                currentIndex += commentText.count + 2
                continue
            }

            // Block comments (/* ... */).
            if source.dropFirst(currentIndex).hasPrefix("/*") {
                var commentText = "/*"
                currentIndex += 2
                scanner.currentIndex = source.index(source.startIndex, offsetBy: currentIndex)
                while !scanner.isAtEnd {
                    if let char = scanner.scanCharacter() {
                        commentText.append(char)
                        currentIndex += 1
                        if commentText.hasSuffix("*/") { break }
                    }
                }
                ranges.append(HighlightedRange(
                    range: NSRange(location: currentIndex - commentText.count, length: commentText.count),
                    tokenType: "comment"
                ))
                continue
            }

            // Hash comments (# ...) for Python, Ruby, Shell.
            if source.dropFirst(currentIndex).hasPrefix("#") {
                var commentText = ""
                while !scanner.isAtEnd {
                    if let char = scanner.scanCharacter() {
                        if char == "\n" { break }
                        commentText.append(char)
                    }
                }
                ranges.append(HighlightedRange(
                    range: NSRange(location: currentIndex, length: commentText.count + 1),
                    tokenType: "comment"
                ))
                currentIndex += commentText.count + 1
                continue
            }

            // String literals (double-quoted).
            if let char = scanner.scanCharacter() {
                if char == "\"" {
                    var strText = "\""
                    while !scanner.isAtEnd {
                        if let c = scanner.scanCharacter() {
                            strText.append(c)
                            if c == "\\" {
                                // Escape: skip next char.
                                if let escaped = scanner.scanCharacter() {
                                    strText.append(escaped)
                                }
                            } else if c == "\"" {
                                break
                            }
                        }
                    }
                    ranges.append(HighlightedRange(
                        range: NSRange(location: currentIndex, length: strText.count),
                        tokenType: "string"
                    ))
                    currentIndex += strText.count
                    continue
                }

                // Numbers.
                if char.isNumber || (char == "." && currentIndex + 1 < source.count) {
                    var numText = String(char)
                    while !scanner.isAtEnd {
                        if let c = scanner.scanCharacter() {
                            if c.isNumber || c == "." || c == "x" || c == "o" || c == "b" || c == "_" {
                                numText.append(c)
                            } else {
                                // Put back.
                                scanner.currentIndex = source.index(scanner.currentIndex, offsetBy: -1)
                                break
                            }
                        }
                    }
                    ranges.append(HighlightedRange(
                        range: NSRange(location: currentIndex, length: numText.count),
                        tokenType: "number"
                    ))
                    currentIndex += numText.count
                    continue
                }

                // Identifiers / keywords.
                if char.isLetter || char == "_" || char == "@" {
                    var identifier = String(char)
                    while !scanner.isAtEnd {
                        if let c = scanner.scanCharacter() {
                            if c.isLetter || c.isNumber || c == "_" {
                                identifier.append(c)
                            } else {
                                scanner.currentIndex = source.index(scanner.currentIndex, offsetBy: -1)
                                break
                            }
                        }
                    }

                    if keywords.contains(identifier) {
                        ranges.append(HighlightedRange(
                            range: NSRange(location: currentIndex, length: identifier.count),
                            tokenType: "keyword"
                        ))
                    } else if identifier.first?.isUppercase == true {
                        ranges.append(HighlightedRange(
                            range: NSRange(location: currentIndex, length: identifier.count),
                            tokenType: "type"
                        ))
                    }

                    currentIndex += identifier.count
                    continue
                }

                // Other characters (operators, punctuation).
                currentIndex += 1
            }
        }

        return ranges
    }

    func supportedLanguages() -> [String] {
        Array(extensionToLanguage.values).sorted().unique()
    }

    func detectLanguage(fileExtension: String) -> String? {
        extensionToLanguage[fileExtension.lowercased()]
    }
}

// MARK: - Array Unique Extension

private extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
