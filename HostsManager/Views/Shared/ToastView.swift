import SwiftUI

struct ToastView: View {
    let toast: ToastMessage

    var accentColor: Color {
        switch toast.type {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }

    var icon: String {
        switch toast.type {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(accentColor)
                .font(.body.weight(.semibold))
            Text(toast.message)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .modifier(GlassBackgroundModifier(cornerRadius: 10, tintColor: accentColor))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}
