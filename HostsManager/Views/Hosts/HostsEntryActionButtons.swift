import SwiftUI

struct EntryActionButtons: View {
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .opacity(isHovered ? 1 : 0)
        .frame(maxWidth: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct TagToggleButton: View {
    let state: HostsFileManager.TagState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private var icon: String {
        switch state {
        case .allEnabled: return "checkmark.circle.fill"
        case .allDisabled: return "circle"
        case .mixed: return "minus.circle.fill"
        }
    }

    private var color: Color {
        switch state {
        case .allEnabled: return .green
        case .allDisabled: return .secondary
        case .mixed: return .orange
        }
    }

    private var tooltip: String {
        switch state {
        case .allEnabled: return "Tất cả đang bật — nhấn để tắt"
        case .allDisabled: return "Tất cả đang tắt — nhấn để bật"
        case .mixed: return "Một số đang bật — nhấn để tắt tất cả"
        }
    }
}
