import SwiftUI

/// 44-pt window header with app identity, tab switcher, and right-side actions.
/// Reference: docs/mockup-reference.md → "TitleBar".
struct TitleBarView: View {
    @Binding var selectedTab: AppTab
    let hostsCount: Int
    let envCount: Int
    var onSearch: () -> Void = {}
    var onSettings: () -> Void = {}

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        HStack(spacing: 0) {
            leftZone
            Spacer(minLength: DSSpacing.p3)
            tabSwitcher
            Spacer(minLength: DSSpacing.p3)
            rightZone
        }
        .padding(.horizontal, DSSpacing.p3)
        // Align content vertically with the traffic-light buttons (which sit at
        // y=9..23 within the 32pt native titlebar — center y=16). Container is 38pt
        // with `alignment: .top` and 4pt top padding pushes content center to y≈18,
        // matching button center while leaving slight breathing room below.
        .frame(maxHeight: 38, alignment: .top)
        .padding(.top, 4)
        .frame(height: 38)
        .background(titleBarBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.dsBorderSecondary)
                .frame(height: 0.5)
        }
    }

    // MARK: - Subviews

    private var leftZone: some View {
        HStack(spacing: DSSpacing.p2) {
            Image(systemName: "server.rack")
                .font(.system(size: 13))
                .foregroundStyle(Color.dsTextSecondary)
            Text("Hosts Manager")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.dsTextPrimary)
            // Version visible only on hover via tooltip — keeps title bar minimal per mockup.
        }
        .help("v\(appVersion)")
        // Reserve room for traffic-light buttons (window controls overlap left edge).
        .padding(.leading, 60)
    }

    private var tabSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab, count: tab == .hosts ? hostsCount : envCount)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func tabButton(_ tab: AppTab, count: Int) -> some View {
        let isActive = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                Text(tab.rawValue)
                    .font(.system(size: 11.5, weight: isActive ? .medium : .regular))
                Text("\(count)")
                    .font(.system(size: 9.5))
                    .padding(.horizontal, 4)
                    .background(
                        Capsule().fill(
                            isActive
                                ? Color.dsProfilePurple.opacity(0.25)
                                : Color.white.opacity(0.08)
                        )
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .foregroundStyle(
                isActive ? Color(hex: "#CECBF6") : Color.dsTextSecondary
            )
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isActive ? Color.dsProfilePurple.opacity(0.22) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        isActive ? Color.dsProfilePurple.opacity(0.3) : Color.clear,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        // SwiftUI adds a system focus ring around the button when it gets keyboard
        // focus after a click — that ring sits on top of and visually obscures the
        // tab pill. Disable it; selected state is communicated via fill+stroke.
        .focusEffectDisabled()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tab.rawValue)
        .accessibilityIdentifier("tab-\(tab.rawValue.lowercased())")
    }

    private var rightZone: some View {
        HStack(spacing: DSSpacing.p2) {
            Button(action: onSearch) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                    Text("Tìm")
                        .font(.system(size: 11))
                    Text("⌘K")
                        .font(.dsMonoTiny)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .foregroundStyle(Color.dsTextSecondary)
                .background(
                    RoundedRectangle(cornerRadius: DSRadius.md)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.md)
                        .strokeBorder(Color.dsBorderSecondary, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
        }
    }

    private var titleBarBackground: some View {
        LinearGradient(
            colors: [Color(hex: "#232325"), Color(hex: "#1f1f21")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    TitleBarView(
        selectedTab: .constant(.hosts),
        hostsCount: 12,
        envCount: 8
    )
    .frame(width: 980)
    .background(Color.dsBackground)
}
