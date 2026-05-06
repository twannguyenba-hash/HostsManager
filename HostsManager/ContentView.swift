import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case hosts = "Hosts"
    case env = "Env"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .hosts: return "network"
        case .env: return "doc.text.fill"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .hosts
    @AppStorage("appearanceMode") private var appearanceRaw: String = AppearanceMode.system.rawValue

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("", selection: $selectedTab) {
                    ForEach(AppTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                appearanceMenu
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Switch giữa 2 view — chỉ 1 NavigationSplitView render tại 1 thời điểm.
            // .transaction tắt animation transition → swap tức thì, giảm flicker.
            // Trade-off: @State trong mỗi view (rawText, viewMode, searchText...) reset khi
            // đổi tab. Chấp nhận đánh đổi này để tránh double toolbar/double render lag từ ZStack.
            Group {
                switch selectedTab {
                case .hosts:
                    HostsView()
                case .env:
                    EnvView()
                }
            }
            .transaction { $0.animation = nil }
        }
        .preferredColorScheme(appearance.colorScheme)
    }

    private var appearanceMenu: some View {
        Menu {
            ForEach(AppearanceMode.allCases) { mode in
                Button {
                    appearanceRaw = mode.rawValue
                } label: {
                    if appearance == mode {
                        Label(mode.label, systemImage: "checkmark")
                    } else {
                        Label(mode.label, systemImage: mode.icon)
                    }
                }
            }
        } label: {
            Image(systemName: appearance.icon)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Chế độ hiển thị")
    }
}

#Preview {
    ContentView()
        .environmentObject(HostsFileManager())
        .environmentObject(EnvFileManager())
}
