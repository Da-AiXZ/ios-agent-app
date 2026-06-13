import SwiftUI

/// A reusable empty state view used when lists have no content.
///
/// Displays an SF Symbol icon, a title, and an optional subtitle
/// to guide the user. Used for empty conversations, empty file
/// trees, clean settings, etc.
struct EmptyStateView: View {

    /// The SF Symbol name for the icon.
    let icon: String

    /// The primary title text.
    let title: String

    /// An optional subtitle providing more detail.
    var subtitle: String?

    /// An optional action button label.
    var actionLabel: String?

    /// An optional action to perform when the button is tapped.
    var action: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .accessibilityLabel(title)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .accessibilityLabel(subtitle)
            }

            if let actionLabel = actionLabel, let action = action {
                Button(action: action) {
                    Text(actionLabel)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(actionLabel)
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dynamicTypeSize(.small ... .accessibility3)
    }
}

// MARK: - Previews

#Preview {
    EmptyStateView(
        icon: "bubble.left.and.bubble.right",
        title: "No Conversations",
        subtitle: "Start a new conversation to begin coding with the AI agent.",
        actionLabel: "New Conversation",
        action: {}
    )
}
