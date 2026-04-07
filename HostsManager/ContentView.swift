import SwiftUI
import AppKit

// MARK: - Raw Text Editor with Comment Toggle (Cmd+/)

struct RawTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = CommentToggleTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isRichText = false
        textView.string = text
        textView.delegate = context.coordinator
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RawTextEditor

        init(_ parent: RawTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

class CommentToggleTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "/" {
            toggleCommentOnSelectedLines()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func toggleCommentOnSelectedLines() {
        let fullText = string
        let nsString = fullText as NSString
        let selectedRange = self.selectedRange()

        let lineRange = nsString.lineRange(for: selectedRange)
        let linesString = nsString.substring(with: lineRange)
        let lines = linesString.components(separatedBy: "\n")

        // Remove trailing empty element from split
        let trimmedLines: [String]
        if lines.last == "" {
            trimmedLines = Array(lines.dropLast())
        } else {
            trimmedLines = lines
        }

        // Check if all non-empty lines are commented
        let allCommented = trimmedLines.allSatisfy { $0.isEmpty || $0.hasPrefix("#") }

        let newLines: [String] = trimmedLines.map { line in
            if line.isEmpty { return line }
            if allCommented {
                // Uncomment: remove leading "# " or "#"
                if line.hasPrefix("# ") {
                    return String(line.dropFirst(2))
                } else if line.hasPrefix("#") {
                    return String(line.dropFirst(1))
                }
                return line
            } else {
                // Comment: add "# " prefix
                return "# " + line
            }
        }

        var replacement = newLines.joined(separator: "\n")
        if lines.last == "" {
            replacement += "\n"
        }

        if shouldChangeText(in: lineRange, replacementString: replacement) {
            replaceCharacters(in: lineRange, with: replacement)
            didChangeText()

            // Reselect the modified lines
            let newLength = (replacement as NSString).length
            setSelectedRange(NSRange(location: lineRange.location, length: newLength))
        }
    }
}

// MARK: - Sidebar Selection

enum SidebarSelection: Hashable {
    case filter(SidebarFilter)
    case tag(String)
}

// MARK: - View Mode

enum ViewMode {
    case table
    case text
}

// MARK: - Content View

struct ContentView: View {
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
            SidebarView(
                selection: $sidebarSelection,
                hostsManager: hostsManager
            )
        } detail: {
            ZStack {
                if viewMode == .text {
                    rawTextEditorView
                } else {
                    entriesListView
                }

                // Toast overlay
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
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
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
                        hostsManager.replaceContentFromRawText(rawText)
                    }
                }

                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Thêm entry mới")
                .disabled(viewMode == .text)

                Menu {
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
                    Divider()
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
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(viewMode == .text)

                Button {
                    if viewMode == .text {
                        hostsManager.applyRawText(rawText)
                    } else {
                        hostsManager.applyChanges()
                    }
                } label: {
                    if hostsManager.isApplying {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Áp dụng")
                    }
                }
                .modifier(ApplyButtonStyleModifier(hasChanges: hostsManager.hasUnsavedChanges))
                .disabled(!hostsManager.hasUnsavedChanges || hostsManager.isApplying)
                .keyboardShortcut("s", modifiers: .command)
            }
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

    private var rawTextEditorView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Raw Hosts Editor")
                    .font(.headline)
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
                    hostsManager.hasUnsavedChanges = true
                }
        }
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
        let filtered = hostsManager.filteredEntries(filter: currentFilter, searchText: searchText, selectedTag: currentTag)

        return Group {
            if filtered.isEmpty {
                Group {
                    if #available(macOS 14.0, *) {
                        ContentUnavailableView {
                            Label("Không có entry nào", systemImage: "doc.text.magnifyingglass")
                        } description: {
                            if !searchText.isEmpty {
                                Text("Thử tìm kiếm với từ khóa khác")
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Không có entry nào")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(entry.ip == "0.0.0.0" ? Color.red : Color.green)
                            .opacity(entry.isEnabled ? 1.0 : 0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .contextMenu { entryContextMenu(entry: entry) }
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Hostname") { entry in
                        Text(entry.hostname)
                            .font(.system(.body, design: .monospaced))
                            .opacity(entry.isEnabled ? 1.0 : 0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .contextMenu { entryContextMenu(entry: entry) }
                    }
                    .width(min: 150, ideal: 250)

                    TableColumn("Comment") { entry in
                        Text(entry.comment)
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
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(.rect(cornerRadius: 4))
                            } else {
                                Text("—")
                                    .foregroundStyle(.secondary)
                                    .opacity(0.5)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .contextMenu { entryContextMenu(entry: entry) }
                    }
                    .width(min: 60, ideal: 100)

                    TableColumn("") { entry in
                        HStack(spacing: 4) {
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
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .contentShape(Rectangle())
                        .contextMenu { entryContextMenu(entry: entry) }
                    }
                    .width(60)
                }
                .tableStyle(.bordered(alternatesRowBackgrounds: true))
            }
        }
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

        Divider()

        Button(role: .destructive) {
            deleteTarget = entry
            showDeleteConfirm = true
        } label: {
            Label("Xóa", systemImage: "trash")
        }
    }
}

// MARK: - Tag Toggle Button

struct TagToggleButton: View {
    let state: HostsFileManager.TagState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private var icon: String {
        switch state {
        case .allEnabled: return "checkmark.circle.fill"
        case .allDisabled: return "circle"
        case .mixed: return "minus.circle.fill"
        }
    }

    private var color: Color {
        switch state {
        case .allEnabled: return .green
        case .allDisabled: return .secondary
        case .mixed: return .orange
        }
    }

    private var tooltip: String {
        switch state {
        case .allEnabled: return "Tất cả đang bật — nhấn để tắt"
        case .allDisabled: return "Tất cả đang tắt — nhấn để bật"
        case .mixed: return "Một số đang bật — nhấn để tắt tất cả"
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var selection: SidebarSelection?
    @ObservedObject var hostsManager: HostsFileManager

    @State private var showCreateTagAlert = false
    @State private var newTagName = ""
    @State private var showRenameTagAlert = false
    @State private var renameTagOldName = ""
    @State private var renameTagNewName = ""
    @State private var showDeleteTagConfirm = false
    @State private var deleteTagTarget = ""

    var body: some View {
        List(selection: $selection) {
            Section("Bộ lọc") {
                ForEach(SidebarFilter.allCases) { filter in
                    Label {
                        HStack {
                            Text(filter.rawValue)
                            Spacer()
                            Text("\(hostsManager.entryCount(for: filter))")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    } icon: {
                        Image(systemName: filter.icon)
                    }
                    .tag(SidebarSelection.filter(filter))
                }
            }

            Section("Tags") {
                ForEach(hostsManager.tags) { tag in
                    HStack {
                        Label {
                            HStack {
                                Text(tag.name)
                                Spacer()
                                Text("\(hostsManager.tagEntryCount(name: tag.name))")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        } icon: {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(.tint)
                        }

                        TagToggleButton(state: hostsManager.tagState(name: tag.name)) {
                            hostsManager.toggleTag(name: tag.name)
                        }
                    }
                    .tag(SidebarSelection.tag(tag.name))
                    .contextMenu {
                        Button {
                            renameTagOldName = tag.name
                            renameTagNewName = tag.name
                            showRenameTagAlert = true
                        } label: {
                            Label("Đổi tên", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteTagTarget = tag.name
                            showDeleteTagConfirm = true
                        } label: {
                            Label("Xóa tag", systemImage: "trash")
                        }
                    }
                }

                Button {
                    newTagName = ""
                    showCreateTagAlert = true
                } label: {
                    Label("Tạo tag mới...", systemImage: "plus.circle")
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }

            if hostsManager.hasUnsavedChanges {
                Section {
                    Label {
                        Text("Có thay đổi chưa lưu")
                            .foregroundStyle(.orange)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 240)
        .alert("Tạo tag mới", isPresented: $showCreateTagAlert) {
            TextField("Tên tag", text: $newTagName)
            Button("Tạo") {
                hostsManager.createTag(name: newTagName)
                newTagName = ""
            }
            Button("Hủy", role: .cancel) {
                newTagName = ""
            }
        }
        .alert("Đổi tên tag", isPresented: $showRenameTagAlert) {
            TextField("Tên mới", text: $renameTagNewName)
            Button("Đổi tên") {
                hostsManager.renameTag(oldName: renameTagOldName, newName: renameTagNewName)
                if case .tag(renameTagOldName) = selection {
                    selection = .tag(renameTagNewName)
                }
                renameTagOldName = ""
                renameTagNewName = ""
            }
            Button("Hủy", role: .cancel) {
                renameTagOldName = ""
                renameTagNewName = ""
            }
        }
        .alert("Xác nhận xóa tag", isPresented: $showDeleteTagConfirm) {
            Button("Xóa", role: .destructive) {
                if case .tag(deleteTagTarget) = selection {
                    selection = .filter(.all)
                }
                hostsManager.deleteTag(name: deleteTagTarget)
                deleteTagTarget = ""
            }
            Button("Hủy", role: .cancel) {
                deleteTagTarget = ""
            }
        } message: {
            Text("Xóa tag \"\(deleteTagTarget)\"? Các entry trong tag sẽ trở thành không có tag.")
        }
    }
}

// MARK: - Entry Form

enum EntryFormMode: Identifiable {
    case add
    case edit(HostEntry)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let entry): return entry.id.uuidString
        }
    }
}

struct EntryFormSheet: View {
    @ObservedObject var hostsManager: HostsFileManager
    let mode: EntryFormMode
    @Environment(\.dismiss) private var dismiss

    @State private var ip = ""
    @State private var hostname = ""
    @State private var comment = ""
    @State private var selectedTag: String = ""
    @State private var errorMessage = ""

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var title: String {
        isEditing ? "Sửa entry" : "Thêm entry mới"
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.title3.bold())
                .padding(.top, 20)
                .padding(.bottom, 12)

            Form {
                Section {
                    TextField("IP Address", text: $ip, prompt: Text("Ví dụ: 127.0.0.1"))
                        .font(.system(.body, design: .monospaced))

                    HStack(spacing: 8) {
                        Text("Chọn nhanh")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        QuickIPButton(label: "127.0.0.1", ip: $ip)
                        QuickIPButton(label: "0.0.0.0", ip: $ip)
                        QuickIPButton(label: "::1", ip: $ip)
                    }

                    TextField("Hostname", text: $hostname, prompt: Text("Ví dụ: example.com"))
                        .font(.system(.body, design: .monospaced))

                    TextField("Ghi chú", text: $comment, prompt: Text("Tuỳ chọn"))
                }

                if !hostsManager.tags.isEmpty {
                    Section {
                        Picker("Tag", selection: $selectedTag) {
                            Text("Không có tag").tag("")
                            ForEach(hostsManager.tags) { tag in
                                Text(tag.name).tag(tag.name)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal, 20)
            }

            HStack {
                Button("Hủy") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(isEditing ? "Cập nhật" : "Thêm") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 420, height: 360)
        .onAppear {
            if case .edit(let entry) = mode {
                ip = entry.ip
                hostname = entry.hostname
                comment = entry.comment
                selectedTag = entry.tag ?? ""
            }
        }
    }

    private func save() {
        errorMessage = ""

        guard !ip.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "IP không được để trống"
            return
        }
        guard !hostname.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Hostname không được để trống"
            return
        }

        let trimmedHostname = hostname.trimmingCharacters(in: .whitespaces)
        let trimmedIP = ip.trimmingCharacters(in: .whitespaces)

        let tagValue = selectedTag.isEmpty ? nil : selectedTag

        if case .add = mode {
            if hostsManager.hostnameExists(trimmedHostname) {
                errorMessage = "Hostname \"\(trimmedHostname)\" đã tồn tại"
                return
            }
            hostsManager.addEntry(ip: trimmedIP, hostname: trimmedHostname, comment: comment.trimmingCharacters(in: .whitespaces), tag: tagValue)
        } else if case .edit(let entry) = mode {
            hostsManager.updateEntry(id: entry.id, ip: trimmedIP, hostname: trimmedHostname, comment: comment.trimmingCharacters(in: .whitespaces), tag: tagValue)
        }

        dismiss()
    }
}

struct QuickIPButton: View {
    let label: String
    @Binding var ip: String

    var body: some View {
        Button(label) {
            ip = label
        }
        .buttonStyle(.bordered)
        .font(.system(.caption, design: .monospaced))
    }
}

// MARK: - Import Sheet

struct ImportSheet: View {
    @ObservedObject var hostsManager: HostsFileManager
    @Environment(\.dismiss) private var dismiss
    @State private var importText = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Import Entries")
                .font(.title3.bold())

            Text("Paste nội dung file hosts vào đây. Chỉ các entry chưa tồn tại mới được thêm.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $importText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .border(Color.secondary.opacity(0.3))

            HStack {
                Button("Hủy") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Import") {
                    hostsManager.importEntries(from: importText)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500, height: 380)
    }
}

// MARK: - Toast View

struct ToastView: View {
    let toast: ToastMessage

    var accentColor: Color {
        switch toast.type {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }

    var icon: String {
        switch toast.type {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(accentColor)
                .font(.body.weight(.semibold))
            Text(toast.message)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .modifier(GlassBackgroundModifier(cornerRadius: 10, tintColor: accentColor))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

struct SearchableWithFocus: ViewModifier {
    @Binding var searchText: String
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content
                .searchable(text: $searchText, isPresented: $isPresented, placement: .toolbar, prompt: "Tìm kiếm hostname, IP...")
        } else {
            content
                .searchable(text: $searchText, placement: .toolbar, prompt: "Tìm kiếm hostname, IP...")
        }
    }
}

// MARK: - Liquid Glass Modifiers

struct GlassBackgroundModifier: ViewModifier {
    let cornerRadius: CGFloat
    var tintColor: Color = .clear

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(
                    tintColor == .clear ? .regular : .regular.tint(tintColor),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(tintColor.opacity(0.3), lineWidth: tintColor == .clear ? 0 : 1)
                )
        }
    }
}

struct ApplyButtonStyleModifier: ViewModifier {
    let hasChanges: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .buttonStyle(.glassProminent)
                .tint(hasChanges ? .blue : .gray)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .tint(hasChanges ? .blue : .gray)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HostsFileManager())
}
