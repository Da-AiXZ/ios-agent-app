import Foundation

// MARK: - DiffServiceProtocol

/// Protocol for diff computation, enabling dependency injection
/// and test mocking.
protocol DiffServiceProtocol: AnyObject {

    /// Computes the difference between two strings at line level.
    ///
    /// Uses Myers' diff algorithm (Longest Common Subsequence)
    /// to produce a list of `DiffChunk` values with add, delete,
    /// and context sections.
    ///
    /// - Parameters:
    ///   - oldText: The original text.
    ///   - newText: The modified text.
    ///   - contextLines: Number of unchanged context lines to
    ///     include around changes (default: 3).
    /// - Returns: An array of `DiffChunk` values.
    func diff(
        old: String,
        new: String,
        contextLines: Int
    ) -> [DiffChunk]

    /// Applies a patch to the original text and returns the result.
    ///
    /// - Parameters:
    ///   - original: The original text.
    ///   - chunks: The diff chunks to apply.
    /// - Returns: The patched text.
    func applyPatch(original: String, chunks: [DiffChunk]) -> String
}

// MARK: - DiffService

/// Computes line-level diffs between two strings.
///
/// Implements the Longest Common Subsequence (LCS) algorithm, a
/// simplified version of Myers' diff, to identify added, removed,
/// and unchanged lines. Output is grouped into `DiffChunk` values
/// with configurable context for readability.
final class DiffService: DiffServiceProtocol {

    // MARK: - Initialization

    init() {}

    // MARK: - DiffServiceProtocol

    func diff(
        old: String,
        new: String,
        contextLines: Int = 3
    ) -> [DiffChunk] {
        let oldLines = old.components(separatedBy: .newlines)
        let newLines = new.components(separatedBy: .newlines)

        // Compute LCS edit script.
        let edits = computeEdits(oldLines: oldLines, newLines: newLines)

        // Group edits into chunks with context.
        return chunkEdits(
            edits: edits,
            oldLines: oldLines,
            newLines: newLines,
            contextLines: contextLines
        )
    }

    func applyPatch(original: String, chunks: [DiffChunk]) -> String {
        var lines = original.components(separatedBy: .newlines)
        var offset: Int = 0

        for chunk in chunks {
            switch chunk.type {
            case .delete:
                let start = chunk.oldStartLine + offset - 1
                let count = chunk.lines.count
                if start >= 0 && start + count <= lines.count {
                    lines.removeSubrange(start..<start + count)
                    offset -= count
                }
            case .add:
                let insertAt = chunk.newStartLine + offset - 1
                let newContent = chunk.lines.map(\.content)
                if insertAt >= 0 && insertAt <= lines.count {
                    lines.insert(contentsOf: newContent, at: insertAt)
                    offset += newContent.count
                }
            case .context:
                // No change needed for context chunks.
                break
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Private: LCS-based Diff

    /// An edit operation in the diff.
    private enum Edit: Equatable {
        case equal(oldIndex: Int, newIndex: Int)
        case delete(oldIndex: Int)
        case insert(newIndex: Int)
    }

    /// Computes the edit script between two arrays of lines using LCS.
    private func computeEdits(oldLines: [String], newLines: [String]) -> [Edit] {
        let m = oldLines.count
        let n = newLines.count

        // Compute LCS table.
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                if oldLines[i - 1] == newLines[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        // Backtrack to produce edit script.
        var edits: [Edit] = []
        var i = m
        var j = n

        while i > 0 || j > 0 {
            if i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1] {
                edits.append(.equal(oldIndex: i - 1, newIndex: j - 1))
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
                edits.append(.insert(newIndex: j - 1))
                j -= 1
            } else {
                edits.append(.delete(oldIndex: i - 1))
                i -= 1
            }
        }

        return edits.reversed()
    }

    /// Groups edit operations into DiffChunks with context lines.
    private func chunkEdits(
        edits: [Edit],
        oldLines: [String],
        newLines: [String],
        contextLines: Int
    ) -> [DiffChunk] {
        var chunks: [DiffChunk] = []
        var currentLines: [DiffLine] = []
        var currentType: DiffChunkType = .context
        var oldLineNum: Int = 1
        var newLineNum: Int = 1
        var chunkOldStart: Int = 0
        var chunkNewStart: Int = 0

        // First pass: collect all line changes with context.
        var changeIndices = Set<Int>()
        var editIndex = 0

        // Identify changed line ranges.
        for (idx, edit) in edits.enumerated() {
            switch edit {
            case .delete(let oldIdx), .equal(let oldIdx, _):
                // Map old index to line number.
                break
            case .insert:
                break
            }
        }

        // Second pass: build chunks directly from edits.
        var i: Int = 0
        while i < edits.count {
            let edit = edits[i]

            switch edit {
            case .equal(let oldIdx, let newIdx):
                let content = oldLines[oldIdx]
                // Check if we should include this as context.
                let isNearChange = isNearChange(
                    editIndex: i,
                    edits: edits,
                    contextLines: contextLines
                )

                if isNearChange || currentType == .context {
                    if currentType != .context && !currentLines.isEmpty {
                        // Flush before adding context.
                        chunks.append(DiffChunk(
                            type: currentType,
                            lines: currentLines,
                            oldStartLine: chunkOldStart,
                            newStartLine: chunkNewStart
                        ))
                        currentLines = []
                    }

                    currentType = .context
                    if currentLines.isEmpty {
                        chunkOldStart = oldLineNum
                        chunkNewStart = newLineNum
                    }
                    currentLines.append(DiffLine(
                        content: content,
                        type: .unchanged,
                        oldLineNumber: oldLineNum,
                        newLineNumber: newLineNum
                    ))
                } else if !currentLines.isEmpty {
                    // Flush existing chunk.
                    chunks.append(DiffChunk(
                        type: currentType,
                        lines: currentLines,
                        oldStartLine: chunkOldStart,
                        newStartLine: chunkNewStart
                    ))
                    currentLines = []
                }

                oldLineNum += 1
                newLineNum += 1

            case .delete(let oldIdx):
                if currentType != .delete && !currentLines.isEmpty {
                    chunks.append(DiffChunk(
                        type: currentType,
                        lines: currentLines,
                        oldStartLine: chunkOldStart,
                        newStartLine: chunkNewStart
                    ))
                    currentLines = []
                }

                currentType = .delete
                if currentLines.isEmpty {
                    chunkOldStart = oldLineNum
                    chunkNewStart = newLineNum
                }
                currentLines.append(DiffLine(
                    content: oldLines[oldIdx],
                    type: .removed,
                    oldLineNumber: oldLineNum,
                    newLineNumber: nil
                ))
                oldLineNum += 1

            case .insert(let newIdx):
                if currentType != .add && !currentLines.isEmpty {
                    chunks.append(DiffChunk(
                        type: currentType,
                        lines: currentLines,
                        oldStartLine: chunkOldStart,
                        newStartLine: chunkNewStart
                    ))
                    currentLines = []
                }

                currentType = .add
                if currentLines.isEmpty {
                    chunkOldStart = oldLineNum
                    chunkNewStart = newLineNum
                }
                currentLines.append(DiffLine(
                    content: newLines[newIdx],
                    type: .added,
                    oldLineNumber: nil,
                    newLineNumber: newLineNum
                ))
                newLineNum += 1
            }

            i += 1
        }

        // Flush final chunk.
        if !currentLines.isEmpty {
            chunks.append(DiffChunk(
                type: currentType,
                lines: currentLines,
                oldStartLine: chunkOldStart,
                newStartLine: chunkNewStart
            ))
        }

        return chunks
    }

    /// Checks whether the edit at the given index is near a change
    /// within the specified context window.
    private func isNearChange(
        editIndex: Int,
        edits: [Edit],
        contextLines: Int
    ) -> Bool {
        let start = max(0, editIndex - contextLines)
        let end = min(edits.count, editIndex + contextLines + 1)

        for i in start..<end {
            if i == editIndex { continue }
            switch edits[i] {
            case .delete, .insert:
                return true
            case .equal:
                continue
            }
        }
        return false
    }
}
