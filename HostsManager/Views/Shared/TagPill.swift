import SwiftUI

/// Pill hiển thị tên tag — style đồng bộ giữa Hosts table và sidebar.
/// Tint nhẹ accentColor để dễ phân biệt mà không quá nổi.
struct TagPill: View {
    let name: String
    var size: Size = .regular

    enum Size {
        case compact, regular
    }

    var body: some View {
        Text(name)
            .font(size == .compact ? .caption2 : .caption)
            .fontWeight(.medium)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, size == .compact ? 6 : 8)
            .padding(.vertical, size == .compact ? 2 : 3)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule(style: .continuous))
    }
}
