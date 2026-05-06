import SwiftUI

/// Environment value cho biết tab hiện tại có active không.
/// Dùng để gate các modifier register toolbar item (như .searchable) — tránh duplicate khi
/// nhiều view cùng resident trong ZStack.
private struct IsActiveTabKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var isActiveTab: Bool {
        get { self[IsActiveTabKey.self] }
        set { self[IsActiveTabKey.self] = newValue }
    }
}

struct SearchableWithFocus: ViewModifier {
    @Binding var searchText: String
    @Binding var isPresented: Bool
    @Environment(\.isActiveTab) private var isActiveTab

    func body(content: Content) -> some View {
        // Chỉ attach .searchable khi tab active — nếu cả 2 view cùng add sẽ bị NSToolbar
        // assert: "already contains an item with the identifier com.apple.SwiftUI.search".
        if !isActiveTab {
            content
        } else if #available(macOS 14.0, *) {
            content
                .searchable(
                    text: $searchText,
                    isPresented: $isPresented,
                    placement: .toolbar,
                    prompt: "Tìm kiếm hostname, IP..."
                )
        } else {
            content
                .searchable(text: $searchText, placement: .toolbar, prompt: "Tìm kiếm hostname, IP...")
        }
    }
}

struct GlassBackgroundModifier: ViewModifier {
    let cornerRadius: CGFloat
    var tintColor: Color = .clear

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(
                    tintColor == .clear ? .regular : .regular.tint(tintColor),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(tintColor.opacity(0.3), lineWidth: tintColor == .clear ? 0 : 1)
                )
        }
    }
}

struct PulseEffectModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.symbolEffect(.pulse, isActive: isActive)
        } else {
            content
        }
    }
}

struct NumericTransitionModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.contentTransition(.numericText())
        } else {
            content
        }
    }
}
