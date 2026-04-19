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

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            switch selectedTab {
            case .hosts:
                HostsView()
            case .env:
                EnvView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HostsFileManager())
        .environmentObject(EnvFileManager())
}
