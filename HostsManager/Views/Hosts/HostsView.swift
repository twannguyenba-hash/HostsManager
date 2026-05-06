import SwiftUI

enum ViewMode {
    case table
    case text
}

struct HostsView: View {
    @EnvironmentObject var hostsManager: HostsFileManager
    @State private var sidebarSelection: SidebarSelection? = .filter(.all)
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var showImportSheet = false
    @State private var editingEntry: HostEntry?
    @State private var deleteTarget: HostEntry?
    @State private var showDeleteConfirm = false
    @State private var viewMode: ViewMode = .table
    @State private var rawText = ""

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection, hostsManager: hostsManager)
        } detail: {
            ZStack {
                if viewMode == .text {
                    rawTextEditorView
                } else {
                    entriesListView
                }

                if let toast = hostsManager.toast {
                    VStack {
                        Spacer()
                        ToastView(toast: toast)
                            .padding(.bottom, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.spring(response: 0.4), value: hostsManager.toast)
                }
            }
        }
        .modifier(SearchableWithFocus(searchText: $searchText, isPresented: $hostsManager.isSearchFocused))
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAddSheet) {
            EntryFormSheet(hostsManager: hostsManager, mode: .add)
        }
        .sheet(item: $editingEntry) { entry in
            EntryFormSheet(hostsManager: hostsManager, mode: .edit(entry))
        }
        .sheet(isPresented: $showImportSheet) {
            ImportSheet(hostsManager: hostsManager)
        }
        .alert("Xác nhận xóa", isPresented: $showDeleteConfirm, presenting: deleteTarget) { entry in
            Button("Xóa", role: .destructive) {
                hostsManager.deleteEntry(id: entry.id)
            }
            Button("Hủy", role: .cancel) {}
        } message: { entry in
            Text("Bạn có chắc muốn xóa entry \"\(entry.hostname)\"?")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Left: secondary view controls — tách riêng để toolbar bên phải sạch chỉ chứa primary actions
        ToolbarItemGroup(placement: .navigation) {
            Picker("Mode", selection: $viewMode) {
                Image(systemName: "tablecells").tag(ViewMode.table)
                Image(systemName: "doc.plaintext").tag(ViewMode.text)
            }
            .pickerStyle(.segmented)
            .help("Chuyển đổi chế độ xem")
            .onChange(of: viewMode) { newValue in
                if newValue == .text {
                    rawText = hostsManager.generateHostsContent()
                    searchText = ""
                } else {
                    let snapshot = rawText
                    DispatchQueue.main.async {
                        hostsManager.replaceContentFromRawText(snapshot)
                    }
                }
            }
        }

        // Right: primary actions
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .help("Thêm entry mới")
            .disabled(viewMode == .text)

            Menu {
                Section("Import / Export") {
                    Button {
                        showImportSheet = true
                    } label: {
                        Label("Import từ text", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        hostsManager.exportToClipboard()
                    } label: {
                        Label("Export vào clipboard", systemImage: "doc.on.clipboard")
                    }
                }
                Section("File") {
                    Button {
                        hostsManager.createBackup()
                    } label: {
                        Label("Tạo backup", systemImage: "externaldrive.badge.plus")
                    }
                    Button {
                        hostsManager.loadHostsFile()
                        if viewMode == .text {
                            rawText = hostsManager.generateHostsContent()
                        }
                    } label: {
                        Label("Tải lại từ file", systemImage: "arrow.clockwise")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .help("Tuỳ chọn khác")
            .disabled(viewMode == .text)

            applyButton
        }
    }

    private var applyButton: some View {
        Button {
            if viewMode == .text {
                hostsManager.applyRawText(rawText)
            } else {
                hostsManager.applyChanges()
            }
        } label: {
            HStack(spacing: 6) {
                if hostsManager.isApplying {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: hostsManager.hasUnsavedChanges ? "arrow.up.circle.fill" : "checkmark.circle")
                        .modifier(PulseEffectModifier(isActive: hostsManager.hasUnsavedChanges))
                }
                Text(hostsManager.isApplying ? "Đang lưu" : "Áp dụng")
                    .fontWeight(.medium)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(hostsManager.hasUnsavedChanges ? .accentColor : .secondary)
        .disabled(!hostsManager.hasUnsavedChanges || hostsManager.isApplying)
        .keyboardShortcut("s", modifiers: .command)
        .animation(.easeInOut(duration: 0.2), value: hostsManager.hasUnsavedChanges)
    }

    private var rawTextEditorView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Raw Hosts Editor").font(.headline)
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
                    guard !hostsManager.hasUnsavedChanges else { return }
                    DispatchQueue.main.async {
                        hostsManager.hasUnsavedChanges = true
                    }
                }
        }
    }

    /// Đếm dòng bằng utf8 byte scan — tránh `components(separatedBy:)` cấp phát mảng String mỗi keystroke.
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

    private var currentFilter: SidebarFilter {
        if case .filter(let f) = sidebarSelection { return f }
        return .all
    }

    private var currentTag: String? {
        if case .tag(let t) = sidebarSelection { return t }
        return nil
    }

    private var entriesListView: some View {
        let filtered = hostsManager.filteredEntries(
            filter: currentFilter,
            searchText: searchText,
            selectedTag: currentTag
        )

        return Group {
            if filtered.isEmpty {
                emptyView
            } else {
                entriesTable(filtered)
            }
        }
    }

    private var emptyView: some View {
        EmptyStateView(
            icon: "doc.text.magnifyingglass",
            title: "Không có entry nào",
            message: searchText.isEmpty
                ? (currentTag != nil ? "Tag này chưa có entry. Thêm entry mới hoặc chọn bộ lọc khác." : nil)
                : "Thử tìm kiếm với từ khóa khác.",
            actionLabel: searchText.isEmpty && currentTag == nil ? "Thêm entry mới" : nil,
            action: searchText.isEmpty && currentTag == nil ? { showAddSheet = true } : nil
        )
    }

    private func entriesTable(_ filtered: [HostEntry]) -> some View {
        Table(filtered) {
            TableColumn("") { entry in
                Toggle("", isOn: Binding(
                    get: { entry.isEnabled },
                    set: { _ in hostsManager.toggleEntry(id: entry.id) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .contextMenu { entryContextMenu(entry: entry) }
            }
            .width(50)

            TableColumn("IP") { entry in
                Text(entry.ip)
                    .font(.system(.body, design: .monospaced).weight(.regular))
                    .foregroundStyle(ipColor(for: entry))
                    .opacity(entry.isEnabled ? 1.0 : 0.45)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .contextMenu { entryContextMenu(entry: entry) }
            }
            .width(min: 100, ideal: 140)

            TableColumn("Hostname") { entry in
                Text(entry.hostname)
                    .font(.system(.body, design: .monospaced).weight(entry.isEnabled ? .medium : .regular))
                    .foregroundStyle(.primary)
                    .opacity(entry.isEnabled ? 1.0 : 0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .contextMenu { entryContextMenu(entry: entry) }
            }
            .width(min: 150, ideal: 250)

            TableColumn("Comment") { entry in
                Text(entry.comment)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .opacity(entry.isEnabled ? 1.0 : 0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .contextMenu { entryContextMenu(entry: entry) }
            }
            .width(min: 80, ideal: 150)

            TableColumn("Tag") { entry in
                Group {
                    if let tag = entry.tag {
                        TagPill(name: tag)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .contextMenu { entryContextMenu(entry: entry) }
            }
            .width(min: 60, ideal: 100)

            TableColumn("") { entry in
                EntryActionButtons(
                    onEdit: { editingEntry = entry },
                    onDelete: {
                        deleteTarget = entry
                        showDeleteConfirm = true
                    }
                )
                .contextMenu { entryContextMenu(entry: entry) }
            }
            .width(60)
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
    }

    /// Blocking entries (0.0.0.0 hoặc 127.0.0.1 → non-localhost) hiện đỏ; localhost/loopback xanh nhạt; còn lại xanh primary.
    private func ipColor(for entry: HostEntry) -> Color {
        if entry.ip == "0.0.0.0" { return .red }
        if entry.ip == "127.0.0.1" && entry.hostname != "localhost" { return .red }
        if entry.ip == "127.0.0.1" || entry.ip == "::1" { return .secondary }
        return .green
    }

    @ViewBuilder
    private func entryContextMenu(entry: HostEntry) -> some View {
        Button {
            editingEntry = entry
        } label: {
            Label("Sửa", systemImage: "pencil")
        }

        Button {
            hostsManager.toggleEntry(id: entry.id)
        } label: {
            Label(entry.isEnabled ? "Tắt" : "Bật", systemImage: entry.isEnabled ? "pause.circle" : "play.circle")
        }

        Button {
            if let copy = hostsManager.duplicateEntry(id: entry.id) {
                editingEntry = copy
            }
        } label: {
            Label("Nhân đôi", systemImage: "plus.square.on.square")
        }

        Divider()

        Button(role: .destructive) {
            deleteTarget = entry
            showDeleteConfirm = true
        } label: {
            Label("Xóa", systemImage: "trash")
        }
    }
}
