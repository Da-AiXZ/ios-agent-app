import Foundation

// MARK: - DiffChunkType

/// The type of change represented by a diff chunk.
@frozen
enum DiffChunkType: String, Codable, CaseIterable {
    /// Lines added in the new version of the file.
    case add

    /// Lines deleted from the old version of the file.
    case delete

    /// Unchanged context lines surrounding the changes.
    case context
}

// MARK: - DiffLineType

/// The type of an individual line within a diff chunk.
@frozen
enum DiffLineType: String, Codable, CaseIterable {
    /// A line that was added (prefixed with `+` in unified diff).
    case added

    /// A line that was removed (prefixed with `-` in unified diff).
    case removed

    /// An unchanged context line (prefixed with space in unified diff).
    case unchanged
}

// MARK: - DiffLine

/// A single line within a diff chunk, tracking its content, type,
/// and original/new line numbers.
struct DiffLine: Codable, Equatable {

    // MARK: - Properties

    /// The textual content of this diff line (without the leading
    /// `+`/`-`/space prefix).
    let content: String

    /// Whether this line was added, removed, or is unchanged.
    let type: DiffLineType

    /// The line number in the original (old) file.
    /// `nil` for added lines that have no old counterpart.
    var oldLineNumber: Int?

    /// The line number in the new (modified) file.
    /// `nil` for removed lines that have no new counterpart.
    var newLineNumber: Int?

    // MARK: - Initialization

    init(
        content: String,
        type: DiffLineType,
        oldLineNumber: Int? = nil,
        newLineNumber: Int? = nil
    ) {
        self.content = content
        self.type = type
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
    }
}

// MARK: - DiffChunk

/// A contiguous block of changes within a diff, consisting of
/// one or more `DiffLine` values grouped by change type.
struct DiffChunk: Codable, Identifiable, Equatable {

    // MARK: - Properties

    /// Unique identifier for this diff chunk.
    let id: UUID

    /// The type of change this chunk represents.
    let type: DiffChunkType

    /// The ordered list of lines within this chunk.
    var lines: [DiffLine]

    /// The starting line number in the original (old) file for
    /// this chunk. For `.add` chunks, this is the line after
    /// which the addition occurs.
    var oldStartLine: Int

    /// The starting line number in the new file for this chunk.
    var newStartLine: Int

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        type: DiffChunkType,
        lines: [DiffLine] = [],
        oldStartLine: Int = 0,
        newStartLine: Int = 0
    ) {
        self.id = id
        self.type = type
        self.lines = lines
        self.oldStartLine = oldStartLine
        self.newStartLine = newStartLine
    }

    // MARK: - Computed Properties

    /// The number of lines in this chunk.
    var lineCount: Int {
        lines.count
    }

    /// Returns only the added or removed lines (excluding context).
    var changedLines: [DiffLine] {
        lines.filter { $0.type != .unchanged }
    }
}
