import Foundation
import SwiftUI

struct HostEntry: Identifiable, Equatable {
    let id: UUID
    var ip: String
    var hostname: String
    var comment: String
    var isEnabled: Bool
    var isComment: Bool // pure comment line, not a disabled entry
    var tag: String? // nil = untagged

    init(id: UUID = UUID(), ip: String = "", hostname: String = "", comment: String = "", isEnabled: Bool = true, isComment: Bool = false, tag: String? = nil) {
        self.id = id
        self.ip = ip
        self.hostname = hostname
        self.comment = comment
        self.isEnabled = isEnabled
        self.isComment = isComment
        self.tag = tag
    }
}

struct HostTag: Identifiable, Equatable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

enum SidebarFilter: String, CaseIterable, Identifiable {
    case all = "Tất cả"
    case enabled = "Đang bật"
    case disabled = "Đã tắt"
    case blocking = "Đang chặn"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .enabled: return "checkmark.circle.fill"
        case .disabled: return "xmark.circle"
        case .blocking: return "hand.raised.fill"
        }
    }
}

enum ToastType {
    case success, error, info
}

struct ToastMessage: Equatable {
    let message: String
    let type: ToastType

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.message == rhs.message
    }
}

@MainActor
class HostsFileManager: ObservableObject {
    @Published var entries: [HostEntry] = []
    @Published var tags: [HostTag] = []
    @Published var commentLines: [(index: Int, text: String)] = []
    @Published var hasUnsavedChanges = false
    @Published var isApplying = false
    @Published var isSearchFocused = false
    @Published var toast: ToastMessage?

    private var originalContent = ""
    private let hostsPath = "/etc/hosts"

    init() {
        loadHostsFile()
    }

    func loadHostsFile() {
        do {
            let content = try String(contentsOfFile: hostsPath, encoding: .utf8)
            originalContent = content
            parseHostsContent(content)
            hasUnsavedChanges = false
        } catch {
            showToast("Không thể đọc file /etc/hosts: \(error.localizedDescription)", type: .error)
        }
    }

    private static let tagStartPattern = try! NSRegularExpression(pattern: #"^##\s*\[tag:(.+)\]\s*$"#)
    private static let tagEndPattern = try! NSRegularExpression(pattern: #"^##\s*\[/tag:(.+)\]\s*$"#)

    private func parseTagMarker(_ line: String) -> (isStart: Bool, name: String)? {
        let range = NSRange(line.startIndex..., in: line)
        if let match = Self.tagStartPattern.firstMatch(in: line, range: range),
           let nameRange = Range(match.range(at: 1), in: line) {
            return (isStart: true, name: String(line[nameRange]).trimmingCharacters(in: .whitespaces))
        }
        if let match = Self.tagEndPattern.firstMatch(in: line, range: range),
           let nameRange = Range(match.range(at: 1), in: line) {
            return (isStart: false, name: String(line[nameRange]).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    func parseHostsContent(_ content: String) {
        var newEntries: [HostEntry] = []
        var newCommentLines: [(index: Int, text: String)] = []
        var discoveredTagNames: [String] = []
        var currentTag: String? = nil
        let lines = content.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Check for tag markers
            if let marker = parseTagMarker(trimmed) {
                if marker.isStart {
                    currentTag = marker.name
                    if !discoveredTagNames.contains(where: { $0.lowercased() == marker.name.lowercased() }) {
                        discoveredTagNames.append(marker.name)
                    }
                } else {
                    currentTag = nil
                }
                continue // tag markers are metadata, not stored as comments
            }

            if trimmed.hasPrefix("#") {
                let uncommented = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                let parts = uncommented.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 && isValidIP(parts[0]) {
                    // Disabled entry
                    let comment = parts.count > 2 ? parts[2...].joined(separator: " ") : ""
                    let entry = HostEntry(
                        ip: parts[0],
                        hostname: parts[1],
                        comment: comment,
                        isEnabled: false,
                        isComment: false,
                        tag: currentTag
                    )
                    newEntries.append(entry)
                } else {
                    // Pure comment
                    newCommentLines.append((index: index, text: line))
                }
            } else {
                // Active entry
                let withoutComment: String
                let inlineComment: String
                if let hashIndex = trimmed.firstIndex(of: "#") {
                    withoutComment = String(trimmed[trimmed.startIndex..<hashIndex]).trimmingCharacters(in: .whitespaces)
                    inlineComment = String(trimmed[trimmed.index(after: hashIndex)...]).trimmingCharacters(in: .whitespaces)
                } else {
                    withoutComment = trimmed
                    inlineComment = ""
                }

                let parts = withoutComment.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    let entry = HostEntry(
                        ip: parts[0],
                        hostname: parts[1],
                        comment: inlineComment,
                        isEnabled: true,
                        isComment: false,
                        tag: currentTag
                    )
                    newEntries.append(entry)
                }
            }
        }

        entries = newEntries
        commentLines = newCommentLines
        tags = discoveredTagNames.map { HostTag(name: $0) }
    }

    func generateHostsContent() -> String {
        var lines: [String] = []

        // Preserve original comment lines at top
        for cl in commentLines {
            lines.append(cl.text)
        }

        if !commentLines.isEmpty {
            lines.append("")
        }

        // Write untagged entries first
        for entry in entries where entry.tag == nil {
            lines.append(formatEntry(entry))
        }

        // Write tagged entries grouped by tag
        for tag in tags {
            let tagEntries = entries.filter { $0.tag == tag.name }
            if tagEntries.isEmpty { continue }

            if lines.last != "" && lines.last != nil {
                lines.append("")
            }
            lines.append("## [tag:\(tag.name)]")
            for entry in tagEntries {
                lines.append(formatEntry(entry))
            }
            lines.append("## [/tag:\(tag.name)]")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func formatEntry(_ entry: HostEntry) -> String {
        if entry.isEnabled {
            var line = "\(entry.ip)\t\(entry.hostname)"
            if !entry.comment.isEmpty {
                line += " # \(entry.comment)"
            }
            return line
        } else {
            var line = "# \(entry.ip)\t\(entry.hostname)"
            if !entry.comment.isEmpty {
                line += " # \(entry.comment)"
            }
            return line
        }
    }

    private func isValidIP(_ string: String) -> Bool {
        // IPv4
        let ipv4Parts = string.split(separator: ".")
        if ipv4Parts.count == 4 && ipv4Parts.allSatisfy({ Int($0) != nil && Int($0)! >= 0 && Int($0)! <= 255 }) {
            return true
        }
        // IPv6 (simple check)
        if string.contains(":") {
            return true
        }
        return false
    }

    func addEntry(ip: String, hostname: String, comment: String, tag: String? = nil) {
        let entry = HostEntry(ip: ip, hostname: hostname, comment: comment, isEnabled: true, tag: tag)
        entries.append(entry)
        hasUnsavedChanges = true
        showToast("Đã thêm \(hostname)", type: .success)
    }

    func updateEntry(id: UUID, ip: String, hostname: String, comment: String, tag: String? = nil) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].ip = ip
            entries[index].hostname = hostname
            entries[index].comment = comment
            entries[index].tag = tag
            hasUnsavedChanges = true
        }
    }

    // MARK: - Tag Management

    func createTag(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !tags.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else {
            showToast("Tag \"\(trimmed)\" đã tồn tại", type: .error)
            return
        }
        tags.append(HostTag(name: trimmed))
        hasUnsavedChanges = true
        showToast("Đã tạo tag \"\(trimmed)\"", type: .success)
    }

    func renameTag(oldName: String, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !tags.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else {
            showToast("Tag \"\(trimmed)\" đã tồn tại", type: .error)
            return
        }
        if let tagIndex = tags.firstIndex(where: { $0.name == oldName }) {
            tags[tagIndex].name = trimmed
        }
        // Batch mutate via local copy to avoid one publisher event per entry
        var updated = entries
        for i in updated.indices where updated[i].tag == oldName {
            updated[i].tag = trimmed
        }
        entries = updated
        hasUnsavedChanges = true
        showToast("Đã đổi tên tag thành \"\(trimmed)\"", type: .success)
    }

    func deleteTag(name: String) {
        tags.removeAll { $0.name == name }
        var updated = entries
        for i in updated.indices where updated[i].tag == name {
            updated[i].tag = nil
        }
        entries = updated
        hasUnsavedChanges = true
        showToast("Đã xóa tag \"\(name)\"", type: .success)
    }

    func toggleTag(name: String) {
        let state = tagState(name: name)
        // mixed or allEnabled → turn all off; allDisabled → turn all on
        let newState = state == .allDisabled

        var updated = entries
        for i in updated.indices where updated[i].tag == name {
            updated[i].isEnabled = newState
        }
        entries = updated
        hasUnsavedChanges = true
    }

    enum TagState {
        case allEnabled, allDisabled, mixed
    }

    func tagState(name: String) -> TagState {
        let tagEntries = entries.filter { $0.tag == name }
        guard !tagEntries.isEmpty else { return .allDisabled }
        let allEnabled = tagEntries.allSatisfy { $0.isEnabled }
        let allDisabled = tagEntries.allSatisfy { !$0.isEnabled }
        if allEnabled { return .allEnabled }
        if allDisabled { return .allDisabled }
        return .mixed
    }

    func isTagEnabled(name: String) -> Bool {
        return tagState(name: name) == .allEnabled
    }

    func moveEntryToTag(entryId: UUID, tag: String?) {
        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            entries[index].tag = tag
            hasUnsavedChanges = true
        }
    }

    func tagEntryCount(name: String) -> Int {
        entries.filter { $0.tag == name }.count
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        hasUnsavedChanges = true
    }

    @discardableResult
    func duplicateEntry(id: UUID) -> HostEntry? {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return nil }
        let source = entries[idx]
        let copy = HostEntry(
            ip: source.ip,
            hostname: source.hostname,
            comment: source.comment,
            isEnabled: source.isEnabled,
            isComment: source.isComment,
            tag: source.tag
        )
        entries.insert(copy, at: idx + 1)
        hasUnsavedChanges = true
        return copy
    }

    func toggleEntry(id: UUID) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].isEnabled.toggle()
            hasUnsavedChanges = true
        }
    }

    func hostnameExists(_ hostname: String) -> Bool {
        entries.contains { $0.hostname.lowercased() == hostname.lowercased() }
    }

    func filteredEntries(filter: SidebarFilter, searchText: String, selectedTag: String? = nil) -> [HostEntry] {
        var result = entries

        // Tag filter takes priority
        if let tag = selectedTag {
            result = result.filter { $0.tag == tag }
        } else {
            switch filter {
            case .all:
                break
            case .enabled:
                result = result.filter { $0.isEnabled }
            case .disabled:
                result = result.filter { !$0.isEnabled }
            case .blocking:
                result = result.filter { ($0.ip == "0.0.0.0") || ($0.ip == "127.0.0.1" && $0.hostname != "localhost") }
            }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.ip.localizedCaseInsensitiveContains(searchText) ||
                $0.hostname.localizedCaseInsensitiveContains(searchText) ||
                $0.comment.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    func entryCount(for filter: SidebarFilter) -> Int {
        switch filter {
        case .all: return entries.count
        case .enabled: return entries.filter { $0.isEnabled }.count
        case .disabled: return entries.filter { !$0.isEnabled }.count
        case .blocking: return entries.filter { $0.ip == "0.0.0.0" || ($0.ip == "127.0.0.1" && $0.hostname != "localhost") }.count
        }
    }

    private func runPrivilegedCommand(_ command: String, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let status = runPrivilegedShellCommand(command)

            DispatchQueue.main.async {
                if status == errAuthorizationSuccess {
                    completion(true, nil)
                } else if status == errAuthorizationCanceled {
                    completion(false, nil) // User cancelled
                } else {
                    completion(false, "Lỗi xác thực (code: \(status))")
                }
            }
        }
    }

    func applyChanges() {
        guard hasUnsavedChanges else { return }
        isApplying = true

        let content = generateHostsContent()
        let tempPath = NSTemporaryDirectory() + "hosts_\(UUID().uuidString)"

        do {
            try content.write(toFile: tempPath, atomically: true, encoding: .utf8)
        } catch {
            isApplying = false
            showToast("Lỗi tạo file tạm: \(error.localizedDescription)", type: .error)
            return
        }

        let command = "cp \(tempPath) /etc/hosts && rm -f \(tempPath) && dscacheutil -flushcache && killall -HUP mDNSResponder 2>/dev/null; true"

        runPrivilegedCommand(command) { [weak self] success, error in
            guard let self = self else { return }
            self.isApplying = false

            if success {
                self.originalContent = content
                self.hasUnsavedChanges = false
                self.showToast("Đã áp dụng thành công!", type: .success)
            } else if let error = error {
                self.showToast("Lỗi: \(error)", type: .error)
            }
            // error == nil means user cancelled — do nothing
        }
    }

    func replaceContentFromRawText(_ text: String) {
        parseHostsContent(text)
        hasUnsavedChanges = true
    }

    func applyRawText(_ text: String) {
        guard !text.isEmpty else { return }
        isApplying = true

        let content = text.hasSuffix("\n") ? text : text + "\n"
        let tempPath = NSTemporaryDirectory() + "hosts_\(UUID().uuidString)"

        do {
            try content.write(toFile: tempPath, atomically: true, encoding: .utf8)
        } catch {
            isApplying = false
            showToast("Lỗi tạo file tạm: \(error.localizedDescription)", type: .error)
            return
        }

        let command = "cp \(tempPath) /etc/hosts && rm -f \(tempPath) && dscacheutil -flushcache && killall -HUP mDNSResponder 2>/dev/null; true"

        runPrivilegedCommand(command) { [weak self] success, error in
            guard let self = self else { return }
            self.isApplying = false

            if success {
                self.originalContent = content
                self.parseHostsContent(content)
                self.hasUnsavedChanges = false
                self.showToast("Đã áp dụng thành công!", type: .success)
            } else if let error = error {
                self.showToast("Lỗi: \(error)", type: .error)
            }
        }
    }

    func createBackup() {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let command = "cp /etc/hosts /etc/hosts.backup.\(timestamp)"

        runPrivilegedCommand(command) { [weak self] success, error in
            if success {
                self?.showToast("Đã tạo backup: hosts.backup.\(timestamp)", type: .success)
            } else if let error = error {
                self?.showToast("Lỗi tạo backup: \(error)", type: .error)
            }
        }
    }

    func exportToClipboard() {
        let content = generateHostsContent()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        showToast("Đã copy nội dung hosts vào clipboard", type: .success)
    }

    func importEntries(from text: String) {
        let lines = text.components(separatedBy: "\n")
        var added = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let withoutComment: String
            let inlineComment: String
            if let hashIndex = trimmed.firstIndex(of: "#") {
                withoutComment = String(trimmed[trimmed.startIndex..<hashIndex]).trimmingCharacters(in: .whitespaces)
                inlineComment = String(trimmed[trimmed.index(after: hashIndex)...]).trimmingCharacters(in: .whitespaces)
            } else {
                withoutComment = trimmed
                inlineComment = ""
            }

            let parts = withoutComment.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 2 && isValidIP(parts[0]) && !hostnameExists(parts[1]) {
                entries.append(HostEntry(ip: parts[0], hostname: parts[1], comment: inlineComment))
                added += 1
            }
        }

        if added > 0 {
            hasUnsavedChanges = true
            showToast("Đã import \(added) entry mới", type: .success)
        } else {
            showToast("Không có entry mới để import", type: .info)
        }
    }

    func showToast(_ message: String, type: ToastType) {
        toast = ToastMessage(message: message, type: type)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.toast?.message == message {
                self?.toast = nil
            }
        }
    }
}
