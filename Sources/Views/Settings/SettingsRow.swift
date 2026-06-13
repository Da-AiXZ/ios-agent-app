import SwiftUI

/// A reusable preference row for the Settings form.
///
/// Renders a label on the left with optional description, and
/// a customizable trailing content area. Used throughout
/// SettingsView for consistent styling.
struct SettingsRow<Content: View>: View {

    /// The primary row label.
    let label: String

    /// An optional secondary description shown below the label.
    var description: String?

    /// Whether to show a divider below this row.
    var showDivider: Bool = true

    /// The trailing content (Toggle, TextField, Picker, etc).
    @ViewBuilder let content: () -> Content

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.body)
                        .foregroundColor(.primary)
                        .accessibilityLabel(label)

                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityLabel(description)
                    }
                }

                Spacer()

                content()
            }
            .padding(.vertical, 4)

            if showDivider {
                Divider()
            }
        }
        .dynamicTypeSize(.small ... .accessibility3)
    }
}

// MARK: - Previews

#Preview {
    List {
        SettingsRow(label: "Appearance", description: "Choose light, dark, or system theme.") {
            Text("System")
                .foregroundColor(.secondary)
        }
        SettingsRow(label: "Auto-Approve Read-Only") {
            Toggle("", isOn: .constant(true))
                .labelsHidden()
        }
    }
}
