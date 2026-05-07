import SwiftUI

struct EnvView: View {
    @Environment(EnvFileManager.self) private var envManager

    var body: some View {
        // HStack-based layout (see HostsView for rationale).
        HStack(spacing: 0) {
            EnvSidebarView()
                .frame(width: 220)
            Divider()
            ZStack {
                detailContent

                if let toast = envManager.toast {
                    VStack {
                        Spacer()
                        ToastView(toast: toast)
                            .padding(.bottom, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.spring(response: 0.4), value: envManager.toast)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let repoId = envManager.selectedRepoId,
           let repo = envManager.repos.first(where: { $0.id == repoId }) {
            EnvFilePane(repo: repo)
        } else {
            EmptyStateView(
                icon: "folder.badge.plus",
                title: "Chưa có repo nào",
                message: "Thêm repo frontend ở sidebar để bắt đầu quản lý file .env."
            )
        }
    }
}
