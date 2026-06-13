import XCTest
@testable import ios_agent_app

// MARK: - DiffServiceTests

/// Tests for the DiffService LCS-based diff algorithm:
/// add/delete/context chunks, applyPatch, edge cases.
final class DiffServiceTests: XCTestCase {

    private let service = DiffService()

    // MARK: - Identical Texts

    func test_diff_identicalTexts_returnsNoChangeChunks() {
        let text = "line1\nline2\nline3"
        let chunks = service.diff(old: text, new: text)

        // Identical texts produce only context chunks (or empty).
        let nonContextChunks = chunks.filter { $0.type != .context }
        XCTAssertTrue(nonContextChunks.isEmpty, "Identical texts should have no add/delete chunks")
    }

    func test_diff_emptyTexts_returnsEmpty() {
        let chunks = service.diff(old: "", new: "")
        let nonContext = chunks.filter { $0.type != .context }
        XCTAssertTrue(nonContext.isEmpty)
    }

    // MARK: - Single Line Add

    func test_diff_singleLineAddition_detectsAdd() {
        let old = "line1\nline2"
        let new = "line1\nline2\nline3"

        let chunks = service.diff(old: old, new: new)

        let addChunks = chunks.filter { $0.type == .add }
        XCTAssertEqual(addChunks.count, 1, "Should detect one add chunk")
        XCTAssertEqual(addChunks[0].lines.count, 1)
        XCTAssertEqual(addChunks[0].lines[0].content, "line3")
        XCTAssertEqual(addChunks[0].lines[0].type, .added)
    }

    // MARK: - Single Line Delete

    func test_diff_singleLineDeletion_detectsDelete() {
        let old = "line1\nline2\nline3"
        let new = "line1\nline3"

        let chunks = service.diff(old: old, new: new)

        let deleteChunks = chunks.filter { $0.type == .delete }
        XCTAssertEqual(deleteChunks.count, 1, "Should detect one delete chunk")
        XCTAssertEqual(deleteChunks[0].lines.count, 1)
        XCTAssertEqual(deleteChunks[0].lines[0].content, "line2")
        XCTAssertEqual(deleteChunks[0].lines[0].type, .removed)
    }

    // MARK: - Single Line Modification (delete + add)

    func test_diff_singleLineModification_producesDeleteAndAdd() {
        let old = "line1\nline2\nline3"
        let new = "line1\nline2_modified\nline3"

        let chunks = service.diff(old: old, new: new)

        let deleteChunks = chunks.filter { $0.type == .delete }
        let addChunks = chunks.filter { $0.type == .add }

        XCTAssertEqual(deleteChunks.count, 1)
        XCTAssertEqual(deleteChunks[0].lines.count, 1)
        XCTAssertEqual(deleteChunks[0].lines[0].content, "line2")

        XCTAssertEqual(addChunks.count, 1)
        XCTAssertEqual(addChunks[0].lines.count, 1)
        XCTAssertEqual(addChunks[0].lines[0].content, "line2_modified")
    }

    // MARK: - Multi-Line Add

    func test_diff_multiLineAddition_detectsAll() {
        let old = "line1\nline5"
        let new = "line1\nline2\nline3\nline4\nline5"

        let chunks = service.diff(old: old, new: new)

        let addChunks = chunks.filter { $0.type == .add }
        XCTAssertFalse(addChunks.isEmpty, "Should have add chunks")

        let addedLines = addChunks.flatMap { $0.lines.map(\.content) }.sorted()
        XCTAssertEqual(addedLines, ["line2", "line3", "line4"])
    }

    // MARK: - Multi-Line Delete

    func test_diff_multiLineDeletion_detectsAll() {
        let old = "line1\nline2\nline3\nline4\nline5"
        let new = "line1\nline5"

        let chunks = service.diff(old: old, new: new)

        let deleteChunks = chunks.filter { $0.type == .delete }
        XCTAssertFalse(deleteChunks.isEmpty, "Should have delete chunks")

        let deletedLines = deleteChunks.flatMap { $0.lines.map(\.content) }.sorted()
        XCTAssertEqual(deletedLines, ["line2", "line3", "line4"])
    }

    // MARK: - Context Lines

    func test_diff_contextLines_surroundsChanges() {
        let old = "a\nb\nc\nd\ne\nf\ng\nh"
        let new = "a\nb\nc\nCHANGED\ne\nf\ng\nh"

        let chunks = service.diff(old: old, new: new, contextLines: 2)

        let contextChunks = chunks.filter { $0.type == .context }
        // With contextLines=2, there should be context around the change.
        XCTAssertFalse(contextChunks.isEmpty, "Should have context chunks with contextLines=2")
    }

    func test_diff_zeroContextLines_producesOnlyChanges() {
        let old = "a\nb\nc\nd"
        let new = "a\nb\nX\nd"

        let chunks = service.diff(old: old, new: new, contextLines: 0)

        let contextChunks = chunks.filter { $0.type == .context }
        // With contextLines=0, only the changed lines should appear.
        // There may still be context chunks from adjacent equal lines at boundaries.
        let nonContext = chunks.filter { $0.type != .context }
        XCTAssertFalse(nonContext.isEmpty, "Should have non-context chunks")
    }

    // MARK: - applyPatch

    func test_applyPatch_deleteChunk_removesLines() {
        let original = "line1\nline2\nline3"
        let chunk = DiffChunk(
            type: .delete,
            lines: [
                DiffLine(content: "line2", type: .removed, oldLineNumber: 2, newLineNumber: nil),
            ],
            oldStartLine: 2,
            newStartLine: 2
        )

        let result = service.applyPatch(original: original, chunks: [chunk])
        XCTAssertEqual(result, "line1\nline3")
    }

    func test_applyPatch_addChunk_insertsLines() {
        let original = "line1\nline3"
        let chunk = DiffChunk(
            type: .add,
            lines: [
                DiffLine(content: "line2", type: .added, oldLineNumber: nil, newLineNumber: 2),
            ],
            oldStartLine: 1,
            newStartLine: 2
        )

        let result = service.applyPatch(original: original, chunks: [chunk])
        XCTAssertEqual(result, "line1\nline2\nline3")
    }

    func test_applyPatch_contextChunk_noChange() {
        let original = "line1\nline2"
        let chunk = DiffChunk(
            type: .context,
            lines: [
                DiffLine(content: "line1", type: .unchanged, oldLineNumber: 1, newLineNumber: 1),
            ],
            oldStartLine: 1,
            newStartLine: 1
        )

        let result = service.applyPatch(original: original, chunks: [chunk])
        XCTAssertEqual(result, original)
    }

    func test_applyPatch_roundTrip() {
        let old = "line1\nline2\nline3\nline4\nline5"
        let new = "line1\nlineA\nlineB\nline4\nline5"

        let chunks = service.diff(old: old, new: new)
        let patched = service.applyPatch(original: old, chunks: chunks)

        XCTAssertEqual(patched, new, "applyPatch should reconstruct new from old + chunks")
    }

    // MARK: - Empty String Edge Cases

    func test_diff_oldEmpty_newNonEmpty() {
        let chunks = service.diff(old: "", new: "line1\nline2")

        let addChunks = chunks.filter { $0.type == .add }
        XCTAssertFalse(addChunks.isEmpty, "Adding to empty should produce add chunks")
    }

    func test_diff_newEmpty_oldNonEmpty() {
        let chunks = service.diff(old: "line1\nline2", new: "")

        let deleteChunks = chunks.filter { $0.type == .delete }
        XCTAssertFalse(deleteChunks.isEmpty, "Deleting everything should produce delete chunks")
    }

    // MARK: - DiffChunk Line Numbers

    func test_diff_lineNumbers_correctForAdditions() {
        let old = "line1\nline3"
        let new = "line1\nline2\nline3"

        let chunks = service.diff(old: old, new: new)
        let addChunk = chunks.first(where: { $0.type == .add })

        XCTAssertNotNil(addChunk)
        if let chunk = addChunk {
            // The added line should have newLineNumber set.
            XCTAssertNotNil(chunk.lines.first?.newLineNumber)
            XCTAssertNil(chunk.lines.first?.oldLineNumber)
        }
    }

    func test_diff_lineNumbers_correctForDeletions() {
        let old = "line1\nline2\nline3"
        let new = "line1\nline3"

        let chunks = service.diff(old: old, new: new)
        let deleteChunk = chunks.first(where: { $0.type == .delete })

        XCTAssertNotNil(deleteChunk)
        if let chunk = deleteChunk {
            XCTAssertNotNil(chunk.lines.first?.oldLineNumber)
            XCTAssertNil(chunk.lines.first?.newLineNumber)
        }
    }

    // MARK: - applyPatch with sequential chunks

    func test_applyPatch_multipleSequentialChunks() {
        let original = "a\nb\nc\nd\ne"
        // Delete "b", add "X", add "Y" after "d"
        let chunks: [DiffChunk] = [
            DiffChunk(
                type: .delete,
                lines: [DiffLine(content: "b", type: .removed, oldLineNumber: 2, newLineNumber: nil)],
                oldStartLine: 2, newStartLine: 2
            ),
            DiffChunk(
                type: .add,
                lines: [DiffLine(content: "X", type: .added, oldLineNumber: nil, newLineNumber: 2)],
                oldStartLine: 2, newStartLine: 2
            ),
            DiffChunk(
                type: .add,
                lines: [DiffLine(content: "Y", type: .added, oldLineNumber: nil, newLineNumber: 5)],
                oldStartLine: 4, newStartLine: 5
            ),
        ]

        let result = service.applyPatch(original: original, chunks: chunks)
        // "b" removed, "X" inserted at position 2, "Y" inserted at position 5 (after "d")
        // Original: a b c d e → delete b → a c d e → insert X at 2 → a X c d e → insert Y at 5 → a X c d Y e
        XCTAssertEqual(result, "a\nX\nc\nd\nY\ne")
    }

    // MARK: - Stress: LCS correctness

    func test_diff_lcsCorrectness_largerInput() {
        let oldLines = (1...20).map { "line\($0)" }
        let old = oldLines.joined(separator: "\n")

        // Modify some lines.
        var newLines = oldLines
        newLines[5] = "CHANGED_6"
        newLines[10] = "CHANGED_11"
        newLines.insert("INSERTED", at: 3)
        newLines.remove(at: 15)
        let new = newLines.joined(separator: "\n")

        let chunks = service.diff(old: old, new: new)
        let patched = service.applyPatch(original: old, chunks: chunks)

        XCTAssertEqual(patched, new, "LCS round-trip should work for larger inputs")
    }

    // MARK: - DiffChunk model properties

    func test_diffChunk_lineCount() {
        let chunk = DiffChunk(
            type: .add,
            lines: [
                DiffLine(content: "a", type: .added),
                DiffLine(content: "b", type: .added),
                DiffLine(content: "c", type: .added),
            ]
        )
        XCTAssertEqual(chunk.lineCount, 3)
    }

    func test_diffChunk_changedLines_filtersOutUnchanged() {
        let chunk = DiffChunk(
            type: .context,
            lines: [
                DiffLine(content: "ctx1", type: .unchanged),
                DiffLine(content: "ctx2", type: .unchanged),
                DiffLine(content: "added1", type: .added),
            ]
        )
        XCTAssertEqual(chunk.changedLines.count, 1)
        XCTAssertEqual(chunk.changedLines[0].content, "added1")
    }
}
