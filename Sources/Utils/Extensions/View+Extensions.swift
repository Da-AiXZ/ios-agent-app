import SwiftUI

// MARK: - View Extensions

extension View {

    /// Type-erases the view into an `AnyView`, useful for returning
    /// different view types from the same function or computed property.
    ///
    /// - Returns: The view wrapped in an `AnyView`.
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }

    /// Conditionally applies a transformation to the view when an
    /// optional value is present.
    ///
    /// Usage:
    /// ```swift
    /// Text("Hello")
    ///     .ifLet(optionalColor) { view, color in
    ///         view.foregroundColor(color)
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - value: An optional value that controls whether the
    ///     transform is applied.
    ///   - transform: A closure that receives the view and the
    ///     unwrapped value, returning a modified view.
    /// - Returns: The transformed view if `value` is non-nil,
    ///   otherwise the original view.
    @ViewBuilder
    func ifLet<T>(
        _ value: T?,
        transform: (Self, T) -> some View
    ) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }

    /// Conditionally applies a modifier based on a boolean flag.
    ///
    /// - Parameters:
    ///   - condition: The condition that controls whether the
    ///     transform is applied.
    ///   - transform: A closure that returns a modified view.
    /// - Returns: The transformed view if `condition` is `true`,
    ///   otherwise the original view.
    @ViewBuilder
    func `if`(
        _ condition: Bool,
        transform: (Self) -> some View
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
