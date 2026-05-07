import SwiftUI

/// 24×13 custom toggle matching mockup-reference.md → "Toggle component".
/// Track: blue when on, white-opacity-10 when off. Knob: 10x10 white circle, spring animation.
struct DSToggle: View {
    @Binding var isOn: Bool
    var disabled: Bool = false
    var onChange: ((Bool) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: toggle) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 6.5)
                    .fill(trackColor)
                    .frame(width: 24, height: 13)

                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .padding(.horizontal, 1.5)
                    .shadow(color: .black.opacity(0.25), radius: 0.5, y: 0.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .animation(
            reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8),
            value: isOn
        )
        .accessibilityLabel("Toggle entry")
        .accessibilityValue(isOn ? "On" : "Off")
    }

    private var trackColor: Color {
        isOn ? Color(hex: "#378ADD") : Color.white.opacity(0.10)
    }

    private func toggle() {
        isOn.toggle()
        onChange?(isOn)
    }
}

#Preview("States") {
    VStack(spacing: 16) {
        DSToggle(isOn: .constant(true))
        DSToggle(isOn: .constant(false))
        DSToggle(isOn: .constant(true), disabled: true)
        DSToggle(isOn: .constant(false), disabled: true)
    }
    .padding()
    .background(Color.dsBackground)
}
