import Testing
import Foundation
@testable import HostsManager

@Suite("ProfileStore")
struct ProfileStoreTests {
    /// Build a UserDefaults-backed store on an isolated suite so tests don't pollute standard defaults.
    private func makeStore() -> (store: ProfileStore, defaults: UserDefaults, key: String) {
        let suiteName = "test.profile-store.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let key = "test.profiles"
        return (ProfileStore(defaults: defaults, key: key), defaults, key)
    }

    @Test("Empty store returns empty array")
    func emptyLoadReturnsEmpty() {
        let (store, _, _) = makeStore()
        #expect(store.load().isEmpty)
    }

    @Test("save and load round-trips profile data")
    func roundTrip() {
        let (store, _, _) = makeStore()
        let profiles = Profile.defaults
        store.save(profiles)
        let loaded = store.load()
        #expect(loaded == profiles)
    }

    @Test("Overwrite previous data on subsequent save")
    func overwriteOnResave() {
        let (store, _, _) = makeStore()
        store.save([.release])
        store.save([.production, .master])
        #expect(store.load().map(\.name) == ["Production", "Master"])
    }

    @Test("Corrupt blob returns empty array, does not crash")
    func corruptBlobIsTolerated() {
        let (store, defaults, key) = makeStore()
        defaults.set(Data([0xFF, 0x00, 0xAB]), forKey: key)
        #expect(store.load().isEmpty)
    }

    @Test("MockProfileStore mirrors real semantics")
    func mockBehaviour() {
        let mock = MockProfileStore(initial: [.release])
        #expect(mock.load() == [.release])
        mock.save([.production])
        #expect(mock.load() == [.production])
    }
}
