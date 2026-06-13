import SwiftUI

// MARK: - Color Extensions

extension Color {

    // MARK: - Semantic Colors

    /// The primary accent color used for interactive elements,
    /// buttons, and selected states.
    static let accentColor: Color = Color.blue

    /// Semantic color indicating successful operations (e.g.,
    /// passed tests, committed changes).
    static let successGreen: Color = Color.green

    /// Semantic color indicating errors or destructive actions
    /// (e.g., failed builds, merge conflicts).
    static let errorRed: Color = Color.red

    /// Semantic color indicating warnings or caution states
    /// (e.g., uncommitted changes, deprecated API usage).
    static let warningYellow: Color = Color.yellow

    // MARK: - Adaptive Color Helpers

    /// Returns a color that automatically adapts to light and
    /// dark mode using the provided closures.
    ///
    /// - Parameters:
    ///   - light: The color to use in light appearance mode.
    ///   - dark: The color to use in dark appearance mode.
    /// - Returns: A dynamic color that adapts to the current
    ///   interface style.
    static func adaptive(
        light: @autoclosure @escaping () -> Color,
        dark: @autoclosure @escaping () -> Color
    ) -> Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark())
            default:
                return UIColor(light())
            }
        })
    }
}
