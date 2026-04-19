import SwiftUI

enum EnvProfileSheetMode: Identifiable {
    case save(repoId: UUID)
    case manage(repoId: UUID)

    var id: String {
        switch self {
        case .save(let id): return "save-\(id.uuidString)"
        case .manage(let id): return "manage-\(id.uuidString)"
        }
    }

    var repoId: UUID {
        switch self {
        case .save(let id), .manage(let id): return id
        }
    }
}

struct EnvProfileSheet: View {
    @EnvironmentObject var envManager: EnvFileManager
    let mode: EnvProfileSheetMode
    @Environment(\.dismiss) private var dismiss

    @State private var newProfileName: String = ""
    @State private var errorMessage: String = ""
    @State private var renamingId: UUID?
    @State private var renameBuffer: String = ""

    private var repo: EnvRepo? {
        envManager.repos.first(where: { $0.id == mode.repoId })
    }

    var body: some View {
        switch mode {
        case .save:
            saveModeBody
        case .manage:
            manageModeBody
        }
    }

    // MARK: - Save mode

    private var saveModeBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lưu state hiện tại thành profile")
                .font(.title3.bold())

            Text("App sẽ chụp lại nội dung các file .env trong repo hiện tại.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Tên profile", text: $newProfileName, prompt: Text("dev, staging, prod..."))
                .textFieldStyle(.roundedBorder)
                .onSubmit { saveProfile() }

            if !errorMessage.isEmpty {
                Text(errorMessage).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Button("Hủy") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Lưu") { saveProfile() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                    .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func saveProfile() {
        errorMessage = ""
        do {
            _ = try envManager.saveCurrentAsProfile(
                repoId: mode.repoId,
                profileName: newProfileName
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Manage mode

    private var manageModeBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quản lý profiles")
                .font(.title3.bold())

            if let repo = repo, !repo.profiles.isEmpty {
                List {
                    ForEach(repo.profiles) { profile in
                        profileRow(profile)
                    }
                }
                .frame(minHeight: 220)
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Text("Chưa có profile nào")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(minHeight: 220)
            }

            HStack {
                Spacer()
                Button("Đóng") { dismiss() }
                    .keyboardShortcut(.escape)
            }
        }
        .padding(20)
        .frame(width: 520)
        .alert("Đổi tên profile", isPresented: Binding(
            get: { renamingId != nil },
            set: { if !$0 { renamingId = nil } }
        )) {
            TextField("Tên mới", text: $renameBuffer)
            Button("Đổi") { performRename() }
            Button("Hủy", role: .cancel) { renamingId = nil }
        }
    }

    @ViewBuilder
    private func profileRow(_ profile: EnvProfile) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(.body.weight(.medium))
                Text("\(profile.files.count) files · \(profile.capturedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                renamingId = profile.id
                renameBuffer = profile.name
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Đổi tên")

            Button(role: .destructive) {
                envManager.deleteProfile(repoId: mode.repoId, profileId: profile.id)
            } label: {
                Image(systemName: "trash").foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Xoá")
        }
        .padding(.vertical, 4)
    }

    private func performRename() {
        guard let id = renamingId else { return }
        try? envManager.renameProfile(
            repoId: mode.repoId,
            profileId: id,
            newName: renameBuffer
        )
        renamingId = nil
        renameBuffer = ""
    }
}
