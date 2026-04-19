import SwiftUI
import AppKit

struct EnvSidebarView: View {
    @EnvironmentObject var envManager: EnvFileManager
    @State private var showRenameAlert = false
    @State private var renamingRepoId: UUID?
    @State private var renameBuffer = ""

    var body: some View {
        List(selection: Binding(
            get: { envManager.selectedRepoId },
            set: { envManager.selectedRepoId = $0 }
        )) {
            Section("Repos") {
                if envManager.repos.isEmpty {
                    Text("Chưa có repo nào")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(envManager.repos) { repo in
                        repoRow(repo)
                            .tag(repo.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button(action: pickFolder) {
                Label("Thêm repo", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(8)
        }
        .alert("Đổi tên repo", isPresented: $showRenameAlert) {
            TextField("Tên mới", text: $renameBuffer)
            Button("Đổi") { performRename() }
            Button("Hủy", role: .cancel) { renamingRepoId = nil }
        }
    }

    @ViewBuilder
    private func repoRow(_ repo: EnvRepo) -> some View {
        let exists = envManager.repoPathExists(repo)
        Label {
            HStack {
                Text(repo.name)
                    .foregroundStyle(exists ? .primary : .secondary)
                Spacer()
                if !exists {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .help("Thư mục không tồn tại")
                }
            }
        } icon: {
            Image(systemName: exists ? "folder.fill" : "folder.badge.questionmark")
                .foregroundStyle(exists ? Color.accentColor : Color.secondary)
        }
        .contextMenu {
            Button {
                renamingRepoId = repo.id
                renameBuffer = repo.name
                showRenameAlert = true
            } label: {
                Label("Đổi tên", systemImage: "pencil")
            }
            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: repo.path))
            } label: {
                Label("Mở trong Finder", systemImage: "folder")
            }
            Divider()
            Button(role: .destructive) {
                envManager.removeRepo(id: repo.id)
            } label: {
                Label("Xoá khỏi danh sách", systemImage: "trash")
            }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Chọn thư mục gốc của repo FE"
        panel.prompt = "Thêm"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try envManager.addRepo(at: url)
            } catch {
                envManager.showToast(
                    "Lỗi thêm repo: \(error.localizedDescription)",
                    type: .error
                )
            }
        }
    }

    private func performRename() {
        guard let id = renamingRepoId else { return }
        try? envManager.renameRepo(id: id, newName: renameBuffer)
        renamingRepoId = nil
        renameBuffer = ""
    }
}
