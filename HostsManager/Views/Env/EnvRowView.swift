import SwiftUI

/// Shared column widths for env entry list. Keeps `EnvRowView` and column header aligned.
enum EnvRowLayout {
    static let toggle: CGFloat = 32
    static let key: CGFloat = 200
    static let menu: CGFloat = 28
}

/// Single env entry row matching docs/mockup-reference.md → "List rows (Env)".
/// Grid: toggle | KEY (mono) | value (mono, flex with truncation) | menu.
/// Comment lines / blank lines render in italic gray with raw text.
struct EnvRowView: View {
    let entry: EnvEntry
    let onToggle: (Bool) -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    let isAlternate: Bool

    @State private var isHovering = false

    var body: some View {
        Group {
            if entry.isBlankOrComment {
                blankOrCommentRow
            } else {
                editableRow
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(rowBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.dsBorderTertiary).frame(height: 0.5)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu { contextMenu }
    }

    // MARK: - Row variants

    private var editableRow: some View {
        HStack(spacing: DSSpacing.p2) {
            DSToggle(isOn: Binding(
                get: { entry.isEnabled },
                set: { onToggle($0) }
            ))
            .frame(width: EnvRowLayout.toggle, alignment: .leading)

            Text(entry.key)
                .font(.dsMono)
                .foregroundStyle(Color(hex: "#85B7EB"))
                .strikethrough(!entry.isEnabled, color: Color(hex: "#85B7EB"))
                .lineLimit(1)
                .truncationMode(.tail)
                .help(entry.key)
                .frame(width: EnvRowLayout.key, alignment: .leading)

            Text(entry.value)
                .font(.dsMono)
                .foregroundStyle(Color.dsValueAmber)
                .strikethrough(!entry.isEnabled, color: Color.dsValueAmber)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(displayValueHelp)
                .frame(maxWidth: .infinity, alignment: .leading)

            menuButton
                .frame(width: EnvRowLayout.menu, alignment: .center)
        }
        .opacity(entry.isEnabled ? 1 : 0.5)
    }

    private var blankOrCommentRow: some View {
        HStack(spacing: DSSpacing.p2) {
            Spacer().frame(width: EnvRowLayout.toggle)
            Text(entry.rawLine ?? "")
                .font(.dsMono)
                .italic()
                .foregroundStyle(Color.dsTextTertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: EnvRowLayout.menu)
        }
    }

    // MARK: - Subviews

    private var menuButton: some View {
        Menu {
            contextMenu
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11))
                .foregroundStyle(Color.dsTextTertiary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .opacity(isHovering ? 1 : 0.5)
    }

    @ViewBuilder
    private var contextMenu: some View {
        if !entry.isBlankOrComment {
            Button(action: onEdit) {
                Label("Sửa", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Xoá", systemImage: "trash")
            }
        }
    }

    // MARK: - Styling

    @ViewBuilder
    private var rowBackground: some View {
        if isHovering {
            Color.white.opacity(0.04)
        } else if isAlternate {
            Color.white.opacity(0.02)
        } else {
            Color.clear
        }
    }

    private var displayValueHelp: String {
        if entry.comment.isEmpty { return entry.value }
        return "\(entry.value)\n\n# \(entry.comment)"
    }
}
