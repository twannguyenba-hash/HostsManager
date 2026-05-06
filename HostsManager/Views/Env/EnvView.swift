import SwiftUI

struct EnvView: View {
    @EnvironmentObject var envManager: EnvFileManager

    var body: some View {
        NavigationSplitView {
            EnvSidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
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
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let repoId = envManager.selectedRepoId,
           let repo = envManager.repos.first(where: { $0.id == repoId }) {
            EnvFilePane(repo: repo)
        } else {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Chưa có repo nào")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Thêm repo FE ở sidebar để bắt đầu quản lý file .env.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
