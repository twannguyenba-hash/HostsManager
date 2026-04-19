import SwiftUI

struct EnvFilePane: View {
    @EnvironmentObject var envManager: EnvFileManager
    let repo: EnvRepo

    @State private var availableFiles: [String] = []
    @State private var selectedFilePath: String?
    @State private var searchText: String = ""
    @State private var editingEntry: EnvEntry?
    @State private var showAddSheet: Bool = false
    @State private var deleteTarget: EnvEntry?
    @State private var showDeleteConfirm: Bool = false
    @State private var loadError: String?
    @State private var profileSheetMode: EnvProfileSheetMode?
    @State private var pendingApplyProfileId: UUID?
    @State private var showApplyConfirm: Bool = false
    @State private var viewMode: ViewMode = .table
    @State private var rawText: String = ""

    private var currentFile: EnvFile? {
        guard let path = selectedFilePath else { return nil }
        return envManager.loadedFile(repoId: repo.id, relativePath: path)
    }

    var body: some View {
        VStack(spacing: 0) {
            fileTabBar
            Divider()
            mainContent
            Divider()
            footer
        }
        .onAppear(perform: refreshFiles)
        .onChange(of: repo.id) { _ in refreshFiles() }
        .sheet(isPresented: $showAddSheet) {
            if let file = currentFile {
                EnvKeyFormSheet(
                    mode: .add,
                    existingKeys: Set(file.entries.map { $0.key })
                ) { key, value, comment in
                    envManager.addEntry(
                        repoId: repo.id,
                        fileId: file.id,
                        key: key,
                        value: value,
                        comment: comment
                    )
                }
            }
        }
        .sheet(item: $editingEntry) { entry in
            if let file = currentFile {
                let otherKeys = Set(file.entries.filter { $0.id != entry.id }.map { $0.key })
                EnvKeyFormSheet(
                    mode: .edit(entry),
                    existingKeys: otherKeys
                ) { key, value, comment in
                    envManager.updateEntry(
                        repoId: repo.id,
                        fileId: file.id,
                        entryId: entry.id,
                        key: key,
                        value: value,
                        comment: comment
                    )
                }
            }
        }
        .alert("Xoá key?", isPresented: $showDeleteConfirm, presenting: deleteTarget) { entry in
            Button("Xoá", role: .destructive) {
                if let file = currentFile {
                    envManager.deleteEntry(repoId: repo.id, fileId: file.id, entryId: entry.id)
                }
            }
            Button("Huỷ", role: .cancel) {}
        } message: { entry in
            Text("Xoá key \"\(entry.key)\"?")
        }
        .sheet(item: $profileSheetMode) { mode in
            EnvProfileSheet(mode: mode)
                .environmentObject(envManager)
        }
        .alert("Áp dụng profile?", isPresented: $showApplyConfirm) {
            Button("Áp dụng", role: .destructive) { performApplyProfile() }
            Button("Huỷ", role: .cancel) { pendingApplyProfileId = nil }
        } message: {
            Text("Có thay đổi chưa lưu ở file hiện tại. App sẽ tự backup state hiện tại trước khi áp dụng.")
        }
    }

    // MARK: - File tabs

    private var fileTabBar: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if availableFiles.isEmpty {
                        Text("Không tìm thấy file .env")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .padding(.horizontal, 12)
                    } else {
                        ForEach(availableFiles, id: \.self) { path in
                            fileTabButton(path)
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            Picker("Mode", selection: $viewMode) {
                Image(systemName: "tablecells").tag(ViewMode.table)
                Image(systemName: "doc.plaintext").tag(ViewMode.text)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Chuyển đổi chế độ xem")
            .disabled(currentFile == nil)
            .onChange(of: viewMode) { newValue in
                syncModeChange(to: newValue)
            }

            Button {
                refreshFiles()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Tải lại danh sách file")
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func fileTabButton(_ path: String) -> some View {
        let isSelected = selectedFilePath == path
        let file = envManager.loadedFile(repoId: repo.id, relativePath: path)
        let hasChanges = file?.hasUnsavedChanges == true
        return Button {
            selectFile(path)
        } label: {
            HStack(spacing: 4) {
                Text(path).font(.system(.body, design: .monospaced))
                if hasChanges {
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .clipShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        if let error = loadError {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                Text(error).foregroundStyle(.secondary).font(.callout)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let file = currentFile {
            if viewMode == .text {
                rawEditorView(file)
            } else {
                entriesTable(file)
            }
        } else {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "doc.text")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("Chọn một file .env phía trên")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func rawEditorView(_ file: EnvFile) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(file.relativePath)
                    .font(.system(.headline, design: .monospaced))
                Spacer()
                Text("\(rawText.components(separatedBy: "\n").count) dòng")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            RawTextEditor(text: $rawText)
                .onChange(of: rawText) { _ in
                    envManager.markFileDirty(repoId: repo.id, fileId: file.id)
                }
        }
    }

    private func entriesTable(_ file: EnvFile) -> some View {
        let rows = filteredEntries(file)
        return VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Tìm key / value", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            if rows.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text(searchText.isEmpty ? "File trống" : "Không có kết quả")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(rows) {
                    TableColumn("") { entry in
                        if !entry.isBlankOrComment {
                            Toggle("", isOn: Binding(
                                get: { entry.isEnabled },
                                set: { _ in
                                    envManager.toggleEntry(
                                        repoId: repo.id,
                                        fileId: file.id,
                                        entryId: entry.id
                                    )
                                }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                        }
                    }
                    .width(40)

                    TableColumn("Key") { entry in
                        if entry.isBlankOrComment {
                            Text(entry.rawLine ?? "")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            Text(entry.key)
                                .font(.system(.body, design: .monospaced))
                                .opacity(entry.isEnabled ? 1.0 : 0.5)
                        }
                    }
                    .width(min: 140, ideal: 220)

                    TableColumn("Value") { entry in
                        if !entry.isBlankOrComment {
                            Text(entry.value)
                                .font(.system(.body, design: .monospaced))
                                .opacity(entry.isEnabled ? 1.0 : 0.5)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .help(entry.value)
                        }
                    }
                    .width(min: 180, ideal: 400)

                    TableColumn("Comment") { entry in
                        if !entry.isBlankOrComment {
                            Text(entry.comment)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .width(min: 80, ideal: 180)

                    TableColumn("") { entry in
                        if !entry.isBlankOrComment {
                            HStack(spacing: 6) {
                                Button {
                                    editingEntry = entry
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                Button {
                                    deleteTarget = entry
                                    showDeleteConfirm = true
                                } label: {
                                    Image(systemName: "trash").foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .width(60)
                }
                .tableStyle(.bordered(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                showAddSheet = true
            } label: {
                Label("Thêm key", systemImage: "plus")
            }
            .disabled(currentFile == nil || viewMode == .text)

            profileMenu
                .disabled(viewMode == .text)

            Spacer()

            if currentFile?.hasUnsavedChanges == true {
                Text("Có thay đổi chưa lưu")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            Button {
                apply()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .modifier(PulseEffectModifier(isActive: currentFile?.hasUnsavedChanges == true))
                    Text("Áp dụng")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("s", modifiers: .command)
            .disabled(currentFile?.hasUnsavedChanges != true)
        }
        .padding(10)
    }

    // MARK: - Profile menu

    private var profileMenu: some View {
        Menu {
            if !repo.profiles.isEmpty {
                Section("Áp dụng profile") {
                    ForEach(repo.profiles) { profile in
                        Button {
                            requestApplyProfile(profile.id)
                        } label: {
                            Label(
                                "\(profile.name) (\(profile.files.count) files)",
                                systemImage: "arrow.triangle.2.circlepath"
                            )
                        }
                    }
                }
                Divider()
            }
            Button {
                profileSheetMode = .save(repoId: repo.id)
            } label: {
                Label("Lưu state hiện tại...", systemImage: "square.and.arrow.down")
            }
            Button {
                profileSheetMode = .manage(repoId: repo.id)
            } label: {
                Label("Quản lý profiles...", systemImage: "slider.horizontal.3")
            }
            .disabled(repo.profiles.isEmpty)
        } label: {
            Label("Profiles", systemImage: "square.stack.3d.up")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func requestApplyProfile(_ id: UUID) {
        pendingApplyProfileId = id
        if currentFile?.hasUnsavedChanges == true {
            showApplyConfirm = true
        } else {
            performApplyProfile()
        }
    }

    private func performApplyProfile() {
        guard let id = pendingApplyProfileId else { return }
        pendingApplyProfileId = nil
        do {
            try envManager.applyProfile(repoId: repo.id, profileId: id)
            refreshFiles()
            if viewMode == .text, let file = currentFile {
                rawText = EnvParser.format(file.entries)
            }
        } catch {
            envManager.showToast("Lỗi: \(error.localizedDescription)", type: .error)
        }
    }

    // MARK: - Helpers

    private func refreshFiles() {
        availableFiles = envManager.discoverEnvFiles(in: repo.path)
        loadError = nil
        if let selected = selectedFilePath, availableFiles.contains(selected) {
            loadSelected(selected)
        } else if let first = availableFiles.first {
            selectFile(first)
        } else {
            selectedFilePath = nil
        }
    }

    private func selectFile(_ path: String) {
        // Commit pending raw edits on the previous file before switching away,
        // otherwise the user's in-progress raw text would be lost silently.
        if viewMode == .text, let oldFile = currentFile, oldFile.relativePath != path {
            envManager.replaceEntriesFromRawText(
                repoId: repo.id,
                fileId: oldFile.id,
                rawText: rawText
            )
        }
        selectedFilePath = path
        loadSelected(path)
        if viewMode == .text, let file = currentFile {
            rawText = EnvParser.format(file.entries)
        }
    }

    private func syncModeChange(to newMode: ViewMode) {
        guard let file = currentFile else { return }
        if newMode == .text {
            rawText = EnvParser.format(file.entries)
            searchText = ""
        } else {
            envManager.replaceEntriesFromRawText(
                repoId: repo.id,
                fileId: file.id,
                rawText: rawText
            )
        }
    }

    private func loadSelected(_ path: String) {
        // If already cached with unsaved changes, keep
        if let cached = envManager.loadedFile(repoId: repo.id, relativePath: path),
           cached.hasUnsavedChanges {
            loadError = nil
            return
        }
        do {
            let file = try envManager.loadFile(repoId: repo.id, relativePath: path)
            envManager.setLoadedFile(repoId: repo.id, file: file)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func apply() {
        guard let file = currentFile else { return }
        do {
            if viewMode == .text {
                try envManager.applyRawText(
                    repoId: repo.id,
                    fileId: file.id,
                    relativePath: file.relativePath,
                    rawText: rawText
                )
                if let refreshed = envManager.loadedFile(
                    repoId: repo.id,
                    relativePath: file.relativePath
                ) {
                    rawText = EnvParser.format(refreshed.entries)
                }
            } else {
                try envManager.applyChanges(repoId: repo.id, file: file)
            }
        } catch {
            envManager.showToast("Lỗi: \(error.localizedDescription)", type: .error)
        }
    }

    private func filteredEntries(_ file: EnvFile) -> [EnvEntry] {
        guard !searchText.isEmpty else { return file.entries }
        let q = searchText.lowercased()
        return file.entries.filter { entry in
            if entry.isBlankOrComment {
                return (entry.rawLine ?? "").lowercased().contains(q)
            }
            return entry.key.lowercased().contains(q)
                || entry.value.lowercased().contains(q)
                || entry.comment.lowercased().contains(q)
        }
    }
}
