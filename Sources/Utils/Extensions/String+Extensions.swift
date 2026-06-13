import Foundation

// MARK: - String Extensions

extension String {

    /// Returns a new string with leading and trailing whitespace
    /// and newline characters removed.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Splits the string into an array of lines, separated by
    /// newline characters. Empty trailing lines are omitted.
    ///
    /// - Returns: An array of strings, one per line.
    func lines() -> [String] {
        components(separatedBy: .newlines)
    }

    /// Calculates the leading whitespace indentation level of
    /// the string by counting the number of leading space
    /// characters (tabs count as 4 spaces).
    ///
    /// - Returns: The indentation level as an integer count
    ///   of equivalent space characters.
    func indentationLevel() -> Int {
        var count: Int = 0
        for char in self {
            if char == " " {
                count += 1
            } else if char == "\t" {
                count += 4
            } else {
                break
            }
        }
        return count
    }

    /// Returns `true` if the string contains only whitespace
    /// and newline characters, or is empty.
    var isBlank: Bool {
        trimmed.isEmpty
    }
}
