import SwiftUI

/// A theme preview card that shows a visual sample of how UI elements
/// render in the current theme, used in SettingsView.
///
/// Displays sample chat bubbles, code blocks, and accent colors so
/// users can preview their theme choice before applying it.
struct ThemePreviewCard: View {

    /// The currently selected theme.
    let theme: AppTheme

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Sample chat bubbles.
            HStack {
                Spacer()
                Text("Hello, I need help")
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Sample user message")
            }

            HStack {
                Text("Sure! Let me take a look at your code.")
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Sample assistant message")
                Spacer()
            }

            // Sample code block.
            Text("func hello() {\n    print(\"Hello\")\n}")
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.tertiarySystemBackground))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .accessibilityLabel("Sample code block")

            // Color indicators.
            HStack(spacing: 16) {
                colorSwatch(.blue, label: "Accent")
                colorSwatch(.green, label: "Success")
                colorSwatch(.red, label: "Error")
                colorSwatch(.yellow, label: "Warning")
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .dynamicTypeSize(.small ... .accessibility3)
    }

    // MARK: - Helpers

    private func colorSwatch(_ color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .accessibilityLabel(label)
        }
    }
}

// MARK: - Previews

#Preview {
    ThemePreviewCard(theme: .dark)
        .padding()
        .preferredColorScheme(.dark)
}
