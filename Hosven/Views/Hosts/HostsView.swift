import SwiftUI

enum ViewMode {
    case table
    case text
}

struct HostsView: View {
    @Environment(HostsFileManager.self) private var hostsManager
    @State private var sidebarSelection: SidebarSelection? = .filter(.all)
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var showImportSheet = false
    @State private var editingEntry: HostEntry?
    @State private var deleteTarget: HostEntry?
    @State private var showDeleteConfirm = false
    @State private var viewMode: ViewMode = .table
    @State private var rawText = ""
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        @Bindable var hostsManager = hostsManager
        // HStack-based layout instead of NavigationSplitView — macOS 26 NSV
        // imposes a floating Liquid-Glass sidebar panel with insets we can't
        // suppress. We need flush, edge-to-edge sidebar/detail like a desktop
        // IDE, so manually compose with HStack + Divider.
        return HStack(spacing: 0) {
            SidebarView(selection: $sidebarSelection, hostsManager: hostsManager)
                .frame(width: 220)
            Divider()
            VStack(spacing: 0) {
                detailHeaderBar
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
                        .animation(.dsBouncy, value: hostsManager.toast)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

    /// Inline detail header (replaces the old `.toolbar` items now that MainWindowView owns chrome).
    /// Reference: docs/mockup-reference.md → "Detail content area" → "Header bar".
    private var detailHeaderBar: some View {
        HStack(spacing: DSSpacing.p3) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hosts")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.dsTextPrimary)
                detailHeaderSubtitle
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
            .disabled(viewMode == .text)
            .help("Thêm entry mới")

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
            TextField("Tìm hostname, IP…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .frame(width: 200)
                .focused($isSearchFieldFocused)
                .accessibilityIdentifier("hosts-search-field")
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
        .onChange(of: hostsManager.isSearchFocused) { newValue in
            if newValue {
                isSearchFieldFocused = true
                hostsManager.isSearchFocused = false
            }
        }
        .onChange(of: hostsManager.pendingSearchQuery) { query in
            if let query, !query.isEmpty {
                searchText = query
                isSearchFieldFocused = true
                hostsManager.pendingSearchQuery = nil
            }
        }
    }

    /// Subtitle with colored dots inline: ●6 enabled · ●1 disabled (matches mockup).
    private var detailHeaderSubtitle: some View {
        let enabled = hostsManager.entries.filter(\.isEnabled).count
        let disabled = hostsManager.entries.count - enabled
        return HStack(spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(Color.dsResolvedGreen).frame(width: 5, height: 5)
                Text("\(enabled) enabled")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.dsTextSecondary)
            }
            Text("·")
                .foregroundStyle(Color.dsTextTertiary)
            HStack(spacing: 4) {
                Circle().fill(Color.dsTextTertiary).frame(width: 5, height: 5)
                Text("\(disabled) disabled")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.dsTextSecondary)
            }
        }
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
                        hostsManager.markRawTextDirty()
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var entriesListView: some View {
        let filtered = hostsManager.filteredEntries(
            filter: currentFilter,
            searchText: searchText,
            selectedTag: currentTag
        )

        return Group {
            if filtered.isEmpty {
                emptyView
                    .transition(.opacity)
            } else {
                entriesTable(filtered)
                    // Force Table rebuild on sidebar switch so crossfade transition
                    // can run — Table doesn't animate its own row diffs, so we
                    // swap the whole instance instead of relying on row deltas.
                    .id(sidebarSelection)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .dsSmooth, value: sidebarSelection)
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
        // Native macOS Table = NSTableView underneath = real row recycling.
        // Replaces previous LazyVStack which couldn't recycle and saturated CPU
        // at ~30% with 300 entries (see plans/reports for benchmark history).
        Table(filtered) {
            TableColumn("") { entry in
                DSToggle(isOn: Binding(
                    get: { entry.isEnabled },
                    set: { _ in hostsManager.toggleEntry(id: entry.id) }
                ))
            }
            .width(HostRowLayout.toggle)

            TableColumn("IP") { entry in
                Text(entry.ip)
                    .font(.dsMono)
                    .foregroundStyle(ipColor(for: entry))
                    .strikethrough(!entry.isEnabled, color: ipColor(for: entry))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(entry.ip)
                    .opacity(entry.isEnabled ? 1 : 0.5)
                    .animation(.dsSmooth, value: entry.isEnabled)
            }
            .width(HostRowLayout.ip)

            TableColumn("Hostname") { entry in
                Text(entry.hostname)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Color.dsTextPrimary)
                    .strikethrough(!entry.isEnabled, color: Color.dsTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(entry.comment.isEmpty ? entry.hostname : "\(entry.hostname) — \(entry.comment)")
                    .opacity(entry.isEnabled ? 1 : 0.5)
                    .animation(.dsSmooth, value: entry.isEnabled)
            }

            TableColumn("Source") { entry in
                if let tag = entry.tag {
                    SourceBadge(kind: .profile(name: tag))
                        .opacity(entry.isEnabled ? 1 : 0.5)
                        .animation(.dsSmooth, value: entry.isEnabled)
                }
            }
            .width(HostRowLayout.source)

            TableColumn("") { entry in
                Menu {
                    rowContextMenu(for: entry)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dsTextTertiary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .width(HostRowLayout.menu)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: HostEntry.ID.self) { ids in
            if let id = ids.first, let entry = filtered.first(where: { $0.id == id }) {
                rowContextMenu(for: entry)
            }
        } primaryAction: { ids in
            if let id = ids.first, let entry = filtered.first(where: { $0.id == id }) {
                editingEntry = entry
            }
        }
        .background(Color.dsBackground)
    }

    /// IP foreground color — block (0.0.0.0) red; localhost blue; remote default.
    private func ipColor(for entry: HostEntry) -> Color {
        if entry.ip == "0.0.0.0" { return Color.dsProfileRed }
        if entry.ip == "127.0.0.1" && entry.hostname != "localhost" { return Color.dsIPLocalhost }
        if entry.ip == "127.0.0.1" || entry.ip == "::1" { return Color.dsIPLocalhost }
        return Color.dsIPRemote
    }

    @ViewBuilder
    private func rowContextMenu(for entry: HostEntry) -> some View {
        Button { editingEntry = entry } label: { Label("Sửa", systemImage: "pencil") }
        Button {
            hostsManager.toggleEntry(id: entry.id)
        } label: {
            Label(
                entry.isEnabled ? "Tắt" : "Bật",
                systemImage: entry.isEnabled ? "pause.circle" : "play.circle"
            )
        }
        Button {
            if let copy = hostsManager.duplicateEntry(id: entry.id) {
                editingEntry = copy
            }
        } label: { Label("Nhân đôi", systemImage: "plus.square.on.square") }
        Divider()
        Button(role: .destructive) {
            deleteTarget = entry
            showDeleteConfirm = true
        } label: { Label("Xoá", systemImage: "trash") }
    }
}
