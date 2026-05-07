import SwiftUI

/// One row in the command palette — icon, title, optional subtitle, optional shortcut hint.
struct CommandPaletteRow: View {
    let command: PaletteCommand
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(command.iconTint.opacity(isSelected ? 0.22 : 0.14))
                    .frame(width: 24, height: 24)
                Image(systemName: command.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(command.iconTint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(command.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.dsTextPrimary)
                    .lineLimit(1)
                if let sub = command.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.dsTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let hint = command.shortcutHint {
                Text(hint)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.dsTextTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.dsBorderSecondary, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.dsProfilePurple.opacity(0.18) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isSelected ? Color.dsProfilePurple.opacity(0.5) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
