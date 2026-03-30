import Foundation
import SwiftUI

struct HostEntry: Identifiable, Equatable {
    let id: UUID
    var ip: String
    var hostname: String
    var comment: String
    var isEnabled: Bool
    var isComment: Bool // pure comment line, not a disabled entry

    init(id: UUID = UUID(), ip: String = "", hostname: String = "", comment: String = "", isEnabled: Bool = true, isComment: Bool = false) {
        self.id = id
        self.ip = ip
        self.hostname = hostname
        self.comment = comment
        self.isEnabled = isEnabled
        self.isComment = isComment
    }
}

enum SidebarFilter: String, CaseIterable, Identifiable {
    case all = "Tất cả"
    case enabled = "Đang bật"
    case disabled = "Đã tắt"
    case blocking = "Đang chặn"
    case presets = "Thêm nhanh"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .enabled: return "checkmark.circle.fill"
        case .disabled: return "xmark.circle"
        case .blocking: return "hand.raised.fill"
        case .presets: return "bolt.fill"
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
    @Published var commentLines: [(index: Int, text: String)] = []
    @Published var hasUnsavedChanges = false
    @Published var isApplying = false
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

    func parseHostsContent(_ content: String) {
        var newEntries: [HostEntry] = []
        var newCommentLines: [(index: Int, text: String)] = []
        let lines = content.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

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
                        isComment: false
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
                        isComment: false
                    )
                    newEntries.append(entry)
                }
            }
        }

        entries = newEntries
        commentLines = newCommentLines
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

        for entry in entries {
            if entry.isEnabled {
                var line = "\(entry.ip)\t\(entry.hostname)"
                if !entry.comment.isEmpty {
                    line += " # \(entry.comment)"
                }
                lines.append(line)
            } else {
                var line = "# \(entry.ip)\t\(entry.hostname)"
                if !entry.comment.isEmpty {
                    line += " # \(entry.comment)"
                }
                lines.append(line)
            }
        }

        return lines.joined(separator: "\n") + "\n"
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

    func addEntry(ip: String, hostname: String, comment: String) {
        let entry = HostEntry(ip: ip, hostname: hostname, comment: comment, isEnabled: true)
        entries.append(entry)
        hasUnsavedChanges = true
        showToast("Đã thêm \(hostname)", type: .success)
    }

    func updateEntry(id: UUID, ip: String, hostname: String, comment: String) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].ip = ip
            entries[index].hostname = hostname
            entries[index].comment = comment
            hasUnsavedChanges = true
        }
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        hasUnsavedChanges = true
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

    func filteredEntries(filter: SidebarFilter, searchText: String) -> [HostEntry] {
        var result = entries

        switch filter {
        case .all:
            break
        case .enabled:
            result = result.filter { $0.isEnabled }
        case .disabled:
            result = result.filter { !$0.isEnabled }
        case .blocking:
            result = result.filter { $0.ip == "0.0.0.0" || $0.ip == "127.0.0.1" && $0.hostname != "localhost" }
        case .presets:
            break
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
        case .presets: return 0
        }
    }

    private func runPrivilegedCommand(_ command: String, completion: @escaping (Bool, String?) -> Void) {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        completion(true, nil)
                    } else if errorString.contains("-128") || process.terminationStatus == 1 {
                        completion(false, nil) // User cancelled
                    } else {
                        completion(false, errorString)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
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
