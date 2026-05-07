import Foundation

/// Persists `Profile` definitions (color, shortcut, name) outside `/etc/hosts`.
/// Hosts file only stores tag-name markers; this store layers metadata on top.
protocol ProfileStoring {
    func load() -> [Profile]
    func save(_ profiles: [Profile])
}

/// UserDefaults-backed implementation. Defaults to standard suite; injectable for tests.
final class ProfileStore: ProfileStoring {
    static let storageKey = "com.hostsmanager.profiles.v2"

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = ProfileStore.storageKey) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [Profile] {
        guard let data = defaults.data(forKey: key) else { return [] }
        // Corrupt blob → drop it rather than crash; UI will reseed defaults.
        return (try? JSONDecoder().decode([Profile].self, from: data)) ?? []
    }

    func save(_ profiles: [Profile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: key)
    }
}

/// In-memory mock for tests — does not touch UserDefaults.
final class MockProfileStore: ProfileStoring {
    private(set) var stored: [Profile]

    init(initial: [Profile] = []) {
        self.stored = initial
    }

    func load() -> [Profile] { stored }
    func save(_ profiles: [Profile]) { stored = profiles }
}
