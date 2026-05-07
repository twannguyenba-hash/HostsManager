import SwiftUI

/// Single host entry row matching docs/mockup-reference.md → "List rows (Hosts)".
/// Grid: toggle (30) | IP (mono) | hostname (mono) | source badge | menu.
struct HostRowView: View {
    let entry: HostEntry
    let hostsManager: HostsFileManager
    let isAlternate: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: DSSpacing.p2) {
            DSToggle(isOn: Binding(
                get: { entry.isEnabled },
                set: { _ in hostsManager.toggleEntry(id: entry.id) }
            ))
            .frame(width: 30)

            Text(entry.ip)
                .font(.dsMono)
                .foregroundStyle(ipColor)
                .strikethrough(!entry.isEnabled, color: ipColor)
                .frame(width: 116, alignment: .leading)

            Text(entry.hostname)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Color.dsTextPrimary)
                .strikethrough(!entry.isEnabled, color: Color.dsTextPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(entry.hostname)
                .frame(maxWidth: .infinity, alignment: .leading)

            tagBadge
                .frame(width: 80, alignment: .leading)

            menuButton
                .frame(width: 24)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .opacity(entry.isEnabled ? 1 : 0.5)
        .background(rowBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.dsBorderTertiary).frame(height: 0.5)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu { contextMenu }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var tagBadge: some View {
        if let tag = entry.tag {
            SourceBadge(kind: .profile(name: tag))
        } else {
            EmptyView()
        }
    }

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
        Button {
            onEdit()
        } label: { Label("Sửa", systemImage: "pencil") }

        Button {
            hostsManager.toggleEntry(id: entry.id)
        } label: {
            Label(
                entry.isEnabled ? "Tắt" : "Bật",
                systemImage: entry.isEnabled ? "pause.circle" : "play.circle"
            )
        }

        Button {
            if let copy = hostsManager.duplicateEntry(id: entry.id) {
                _ = copy  // Caller's edit sheet handles selection; nothing to do here.
            }
        } label: { Label("Nhân đôi", systemImage: "plus.square.on.square") }

        Divider()

        Button(role: .destructive, action: onDelete) {
            Label("Xoá", systemImage: "trash")
        }
    }

    // MARK: - Styling

    private var ipColor: Color {
        // Blocking entries (0.0.0.0 / 127.0.0.1 → non-localhost) flagged red
        if entry.ip == "0.0.0.0" { return Color.dsProfileRed }
        if entry.ip == "127.0.0.1" && entry.hostname != "localhost" { return Color.dsIPLocalhost }
        if entry.ip == "127.0.0.1" || entry.ip == "::1" { return Color.dsIPLocalhost }
        return Color.dsIPRemote
    }

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
}
