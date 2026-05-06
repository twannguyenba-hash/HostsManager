import Foundation

struct EnvEntry: Identifiable, Equatable {
    let id: UUID
    var key: String
    var value: String
    var comment: String
    var isEnabled: Bool
    var isBlankOrComment: Bool
    var rawLine: String?

    init(
        id: UUID = UUID(),
        key: String = "",
        value: String = "",
        comment: String = "",
        isEnabled: Bool = true,
        isBlankOrComment: Bool = false,
        rawLine: String? = nil
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.comment = comment
        self.isEnabled = isEnabled
        self.isBlankOrComment = isBlankOrComment
        self.rawLine = rawLine
    }
}

struct EnvFile: Identifiable, Equatable {
    let id: UUID
    let relativePath: String
    var entries: [EnvEntry]
    var hasUnsavedChanges: Bool

    init(
        id: UUID = UUID(),
        relativePath: String,
        entries: [EnvEntry] = [],
        hasUnsavedChanges: Bool = false
    ) {
        self.id = id
        self.relativePath = relativePath
        self.entries = entries
        self.hasUnsavedChanges = hasUnsavedChanges
    }
}

struct ProfileFileSnapshot: Codable, Equatable {
    let relativePath: String
    let content: String
}

struct EnvProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var capturedAt: Date
    var files: [ProfileFileSnapshot]

    init(
        id: UUID = UUID(),
        name: String,
        capturedAt: Date = Date(),
        files: [ProfileFileSnapshot]
    ) {
        self.id = id
        self.name = name
        self.capturedAt = capturedAt
        self.files = files
    }
}

struct EnvRepo: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var path: String
    var profiles: [EnvProfile]

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        profiles: [EnvProfile] = []
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.profiles = profiles
    }
}

// Kết quả discover giúp UI phân biệt 3 trạng thái lỗi thay vì chỉ hiện "không tìm thấy"
enum EnvDiscoverResult: Equatable {
    case ok([String])
    case repoMissing      // Thư mục repo không còn tồn tại
    case envMissing       // Thư mục repo OK nhưng không có file .env

    var paths: [String] {
        if case .ok(let p) = self { return p }
        return []
    }
}

enum EnvError: LocalizedError {
    case repoNotFound
    case profileNotFound
    case duplicateRepoPath
    case duplicateProfileName
    case invalidName
    case invalidPath
    case fileReadFailed(String)
    case fileWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .repoNotFound: return "Không tìm thấy repo"
        case .profileNotFound: return "Không tìm thấy profile"
        case .duplicateRepoPath: return "Repo này đã có trong danh sách"
        case .duplicateProfileName: return "Tên profile đã tồn tại"
        case .invalidName: return "Tên không hợp lệ"
        case .invalidPath: return "Đường dẫn không hợp lệ"
        case .fileReadFailed(let msg): return "Lỗi đọc file: \(msg)"
        case .fileWriteFailed(let msg): return "Lỗi ghi file: \(msg)"
        }
    }
}
