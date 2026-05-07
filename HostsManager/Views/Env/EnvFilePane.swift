import SwiftUI

struct EnvFilePane: View {
    @Environment(EnvFileManager.self) private var envManager
    let repo: EnvRepo

    @State private var discoverResult: EnvDiscoverResult = .ok([])
    private var availableFiles: [String] { discoverResult.paths }
    @State private var selectedFilePath: String?
    @State private var searchText: String = ""
    @State private var isSearchFocused: Bool = false
    @State private var editingEntry: EnvEntry?
    @State private var showAddSheet: Bool = false
    @State private var deleteTarget: EnvEntry?
    @State private var showDeleteConfirm: Bool = false
    @State private var loadError: String?
    @State private var isLoadingFile: Bool = false
    @State private var loadingPath: String?
    @State private var profileSheetMode: EnvProfileSheetMode?
    @State private var pendingApplyProfileId: UUID?
    @State private var showApplyConfirm: Bool = false
    @State private var viewMode: ViewMode = .table
    @State private var rawText: String = ""
    @FocusState private var isSearchFieldFocused: Bool

    private var currentFile: EnvFile? {
        guard let path = selectedFilePath else { return nil }
        return envManager.loadedFile(repoId: repo.id, relativePath: path)
    }

    private var hasUnsavedChanges: Bool {
        currentFile?.hasUnsavedChanges == true
    }

    var body: some View {
        VStack(spacing: 0) {
            detailHeaderBar
            fileTabBar
            Divider()
            mainContent
        }
        .toolbar(.hidden, for: .windowToolbar)
        // .task(id:) chạy mỗi khi view appear hoặc repo.id đổi, với `self` hiện tại
        // (.onAppear + .onChange capture self cũ → đọc repo.path sai khi user click repo khác).
        .task(id: repo.id) {
            refreshFiles()
        }
        .onChange(of: envManager.pendingSearchQuery) { query in
            if let query, !query.isEmpty {
                searchText = query
                isSearchFocused = true
                envManager.pendingSearchQuery = nil
            }
        }
        .sheet(isPresented: $showAddSheet) {
            if let file = currentFile {
                EnvKeyFormSheet(mode: .add) { key, value, comment in
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
                EnvKeyFormSheet(mode: .edit(entry)) { key, value, comment in
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
                .environment(envManager)
        }
        .alert("Áp dụng profile?", isPresented: $showApplyConfirm) {
            Button("Áp dụng", role: .destructive) { performApplyProfile() }
            Button("Huỷ", role: .cancel) { pendingApplyProfileId = nil }
        } message: {
            Text("Có thay đổi chưa lưu ở file hiện tại. App sẽ tự backup state hiện tại trước khi áp dụng.")
        }
    }

    // MARK: - Detail header (replaces window toolbar — same pattern as HostsView)

    private var detailHeaderBar: some View {
        HStack(spacing: DSSpacing.p3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.dsTextPrimary)
                Text(headerSubtitleText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.dsTextSecondary)
            }

            Spacer()

            inlineSearchField

            Picker("", selection: $viewMode) {
                Image(systemName: "tablecells").tag(ViewMode.table)
                Image(systemName: "doc.plaintext").tag(ViewMode.text)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 88)
            .disabled(currentFile == nil)
            .onChange(of: viewMode) { newValue in
                syncModeChange(to: newValue)
            }

            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.sm)
                            .strokeBorder(Color.dsBorderSecondary, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(currentFile == nil || viewMode == .text)
            .help("Thêm key mới")

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
                }
                Section("Profiles") {
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
                }
                Section("File") {
                    Button {
                        refreshFiles()
                    } label: {
                        Label("Tải lại danh sách file", systemImage: "arrow.clockwise")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dsTextSecondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(viewMode == .text)
            .help("Tuỳ chọn khác")
        }
        .padding(.horizontal, 18)
        .padding(.top, DSSpacing.p3)
        .padding(.bottom, DSSpacing.p2)
        .background(Color.dsBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.dsBorderTertiary).frame(height: 0.5)
        }
    }

    private var inlineSearchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Color.dsTextTertiary)
            TextField("Tìm key, value…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .frame(width: 200)
                .focused($isSearchFieldFocused)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .strokeBorder(Color.dsBorderSecondary, lineWidth: 0.5)
        )
    }

    private var headerSubtitleText: String {
        guard let file = currentFile else { return "Chưa chọn file" }
        let total = file.entries.filter { !$0.isBlankOrComment }.count
        let active = file.entries.filter { !$0.isBlankOrComment && $0.isEnabled }.count
        return "\(file.relativePath) · \(active)/\(total) keys"
    }

    // MARK: - File tabs

    private var fileTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if availableFiles.isEmpty {
                    emptyTabMessage
                } else {
                    ForEach(availableFiles, id: \.self) { path in
                        fileTabButton(path)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var emptyTabMessage: some View {
        // Phân biệt 2 nguyên nhân: folder biến mất vs chỉ thiếu file — giúp user fix đúng chỗ
        switch discoverResult {
        case .repoMissing:
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Folder repo không tồn tại").font(.caption).bold()
                    Text(repo.path)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } icon: {
                Image(systemName: "folder.badge.questionmark").foregroundStyle(.orange)
            }
            .padding(.horizontal, 12)
            .help(repo.path)
        case .envMissing:
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Không có .env / .env.local trong repo").font(.caption).bold()
                    Text(repo.path)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } icon: {
                Image(systemName: "doc.badge.ellipsis").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .help(repo.path)
        case .ok:
            EmptyView()
        }
    }

    private func fileTabButton(_ path: String) -> some View {
        let isSelected = selectedFilePath == path
        let file = envManager.loadedFile(repoId: repo.id, relativePath: path)
        let hasChanges = file?.hasUnsavedChanges == true
        return Button {
            selectFile(path)
        } label: {
            HStack(spacing: 6) {
                Text(path)
                    .font(.system(.body, design: .monospaced).weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                if hasChanges {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .help("Có thay đổi chưa lưu")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        if let error = loadError {
            ErrorStateView(
                message: error,
                retryLabel: "Tải lại",
                onRetry: refreshFiles
            )
        } else if isLoadingFile && currentFile == nil {
            LoadingStateView(label: "Đang đọc \(loadingPath ?? "")")
        } else if let file = currentFile {
            if viewMode == .text {
                rawEditorView(file)
            } else {
                entriesTable(file)
            }
        } else {
            EmptyStateView(
                icon: "doc.text",
                title: availableFiles.isEmpty ? "Không có file .env" : "Chọn một file .env",
                message: availableFiles.isEmpty
                    ? "Repo này không có file .env hoặc .env.local."
                    : "Chọn file ở thanh tab phía trên để xem nội dung."
            )
        }
    }

    private func rawEditorView(_ file: EnvFile) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(file.relativePath)
                    .font(.system(.headline, design: .monospaced))
                Spacer()
                Text("\(lineCount(rawText)) dòng")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            RawTextEditor(text: $rawText)
                .onChange(of: rawText) { _ in
                    guard file.hasUnsavedChanges == false else { return }
                    let repoId = repo.id
                    let fileId = file.id
                    DispatchQueue.main.async {
                        envManager.markFileDirty(repoId: repoId, fileId: fileId)
                    }
                }
        }
    }

    /// Đếm dòng bằng utf8 byte scan — tránh cấp phát mảng String mỗi keystroke.
    private func lineCount(_ s: String) -> Int {
        if s.isEmpty { return 1 }
        var count = 1
        for byte in s.utf8 where byte == 0x0A {
            count += 1
        }
        if s.utf8.last == 0x0A {
            count -= 1
        }
        return count
    }

    private func entriesTable(_ file: EnvFile) -> some View {
        let rows = filteredEntries(file)
        return Group {
            if rows.isEmpty {
                EmptyStateView(
                    icon: searchText.isEmpty ? "doc.plaintext" : "magnifyingglass",
                    title: searchText.isEmpty ? "File trống" : "Không có kết quả",
                    message: searchText.isEmpty
                        ? "File này chưa có key nào. Thêm key mới hoặc dùng raw mode để paste content."
                        : "Thử tìm kiếm với từ khóa khác.",
                    actionLabel: searchText.isEmpty ? "Thêm key mới" : nil,
                    action: searchText.isEmpty ? { showAddSheet = true } : nil
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        envListHeader
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                            EnvRowView(
                                entry: entry,
                                onToggle: { _ in
                                    envManager.toggleEntry(
                                        repoId: repo.id,
                                        fileId: file.id,
                                        entryId: entry.id
                                    )
                                },
                                onEdit: { editingEntry = entry },
                                onDelete: {
                                    deleteTarget = entry
                                    showDeleteConfirm = true
                                },
                                isAlternate: index.isMultiple(of: 2)
                            )
                        }
                    }
                }
                .background(Color.dsBackground)
            }
        }
    }

    /// Column header above env list. Widths from `EnvRowLayout`.
    private var envListHeader: some View {
        HStack(spacing: DSSpacing.p2) {
            Spacer().frame(width: EnvRowLayout.toggle)
            Text("KEY")
                .frame(width: EnvRowLayout.key, alignment: .leading)
            Text("VALUE")
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: EnvRowLayout.menu)
        }
        .font(.dsLabel)
        .foregroundStyle(Color.dsTextTertiary)
        .padding(.horizontal, 10)
        .padding(.vertical, DSSpacing.p2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.dsBorderSecondary).frame(height: 0.5)
        }
    }

    // MARK: - Profile actions

    private func requestApplyProfile(_ id: UUID) {
        pendingApplyProfileId = id
        if hasUnsavedChanges {
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
        discoverResult = envManager.discoverEnvFiles(in: repo.path)
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
            // selectFile có thể được gọi từ .task closure → defer @Published mutation
            let repoId = repo.id
            let oldFileId = oldFile.id
            let snapshot = rawText
            DispatchQueue.main.async {
                envManager.replaceEntriesFromRawText(
                    repoId: repoId,
                    fileId: oldFileId,
                    rawText: snapshot
                )
            }
        }
        selectedFilePath = path
        loadSelected(path)
        // Nếu đã có cache (sync return từ loadSelected) thì sync rawText ngay,
        // còn khi async đang chạy thì loadSelected sẽ tự gán rawText sau khi xong.
        if viewMode == .text, let file = currentFile, file.relativePath == path {
            rawText = EnvParser.format(file.entries)
        }
    }

    private func syncModeChange(to newMode: ViewMode) {
        guard let file = currentFile else { return }
        if newMode == .text {
            rawText = EnvParser.format(file.entries)
            searchText = ""
        } else {
            // Defer @Published mutation ra ngoài view update phase
            let repoId = repo.id
            let fileId = file.id
            let snapshot = rawText
            DispatchQueue.main.async {
                envManager.replaceEntriesFromRawText(
                    repoId: repoId,
                    fileId: fileId,
                    rawText: snapshot
                )
            }
        }
    }

    private func loadSelected(_ path: String) {
        // If already cached with unsaved changes, keep
        if let cached = envManager.loadedFile(repoId: repo.id, relativePath: path),
           cached.hasUnsavedChanges {
            loadError = nil
            return
        }
        // Nếu đã có cache (đã load trước đó) thì không cần reload — tránh nháy spinner.
        if envManager.loadedFile(repoId: repo.id, relativePath: path) != nil {
            loadError = nil
            return
        }

        // Async load để I/O + parse không block main actor (root cause của lag lần đầu).
        loadError = nil
        isLoadingFile = true
        loadingPath = path
        let repoId = repo.id

        Task { @MainActor in
            do {
                let file = try await envManager.loadFileAsync(repoId: repoId, relativePath: path)
                // Bỏ kết quả nếu user đã chọn file khác trong lúc đang load
                guard loadingPath == path else { return }
                envManager.setLoadedFile(repoId: repoId, file: file)
                loadError = nil
                if viewMode == .text, selectedFilePath == path {
                    rawText = EnvParser.format(file.entries)
                }
            } catch {
                guard loadingPath == path else { return }
                loadError = error.localizedDescription
            }
            if loadingPath == path {
                isLoadingFile = false
                loadingPath = nil
            }
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
