import SwiftUI
import AppKit

/// Env-tab sidebar restyled with v2 tokens to match Hosts sidebar.
/// Reference: docs/mockup-reference.md → "Section: Repos".
struct EnvSidebarView: View {
    @Environment(EnvFileManager.self) private var envManager
    @State private var showRenameAlert = false
    @State private var renamingRepoId: UUID?
    @State private var renameBuffer = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.p4) {
                    reposSection
                }
                .padding(.horizontal, DSSpacing.p2)
                .padding(.vertical, DSSpacing.p3)
            }

            addRepoButton
        }
        .background(Color.dsBackgroundSidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        .alert("Đổi tên repo", isPresented: $showRenameAlert) {
            TextField("Tên mới", text: $renameBuffer)
            Button("Đổi") { performRename() }
            Button("Hủy", role: .cancel) { renamingRepoId = nil }
        }
    }

    // MARK: - Repos section

    private var reposSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.p2) {
            sectionHeader("Repos")

            if envManager.repos.isEmpty {
                emptyReposState
            } else {
                ForEach(envManager.repos) { repo in
                    repoRow(repo)
                }
            }
        }
    }

    private var emptyReposState: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.badge.questionmark")
                .foregroundStyle(Color.dsTextTertiary)
                .font(.system(size: 11))
            Text("Chưa có repo")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.dsTextTertiary)
        }
        .padding(.horizontal, DSSpacing.p2)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func repoRow(_ repo: EnvRepo) -> some View {
        let exists = envManager.repoPathExists(repo)
        let isActive = envManager.selectedRepoId == repo.id

        Button {
            guard envManager.selectedRepoId != repo.id else { return }
            DispatchQueue.main.async { envManager.selectedRepoId = repo.id }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: exists ? "folder.fill" : "folder.badge.questionmark")
                    .font(.system(size: 12))
                    .foregroundStyle(exists ? Color.dsProfilePurple : Color.dsTextTertiary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(repo.name)
                        .font(.system(size: 11.5, weight: isActive ? .medium : .regular))
                        .foregroundStyle(exists ? Color.dsTextPrimary : Color.dsTextSecondary)
                    Text(repo.path)
                        .font(.dsMonoTiny)
                        .foregroundStyle(Color.dsTextTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
                if !exists {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.dsProfileAmber)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(repoRowBackground(isActive: isActive))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(
                        isActive ? Color.dsProfilePurple.opacity(0.35) : Color.clear,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .help(exists ? repo.path : "\(repo.path)\n(thư mục không tồn tại)")
        .contextMenu {
            Button {
                renamingRepoId = repo.id
                renameBuffer = repo.name
                showRenameAlert = true
            } label: { Label("Đổi tên", systemImage: "pencil") }
            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: repo.path))
            } label: { Label("Mở trong Finder", systemImage: "folder") }
            Divider()
            Button(role: .destructive) {
                envManager.removeRepo(id: repo.id)
            } label: { Label("Xoá khỏi danh sách", systemImage: "trash") }
        }
    }

    @ViewBuilder
    private func repoRowBackground(isActive: Bool) -> some View {
        if isActive {
            RoundedRectangle(cornerRadius: 7)
                .fill(LinearGradient(
                    colors: [
                        Color.dsProfilePurple.opacity(0.18),
                        Color.dsProfilePurple.opacity(0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        } else {
            RoundedRectangle(cornerRadius: 7).fill(Color.clear)
        }
    }

    // MARK: - Footer button

    private var addRepoButton: some View {
        Button(action: pickFolder) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12))
                Text("Thêm repo")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#378ADD"), Color(hex: "#185FA5")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .strokeBorder(Color(hex: "#78b4ff").opacity(0.4), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
        }
        .buttonStyle(.plain)
        .padding(DSSpacing.p2)
        .background(Color.dsBackgroundSidebar)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.dsBorderTertiary).frame(height: 0.5)
        }
    }

    // MARK: - Header helper

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .medium))
            .tracking(0.6)
            .foregroundStyle(Color.dsTextTertiary)
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
    }

    // MARK: - Actions

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
