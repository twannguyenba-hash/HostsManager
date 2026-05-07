import Testing
import Foundation
@testable import HostsManager

@Suite("FuzzySearch")
struct FuzzySearchTests {

    @Test("Empty query matches everything at neutral score")
    func emptyQuery() {
        let m = FuzzySearch.match(query: "", in: "anything")
        #expect(m != nil)
        #expect(m?.score == 0)
        #expect(m?.ranges.isEmpty == true)
    }

    @Test("Subsequence match returns ranges")
    func subsequence() throws {
        let m = try #require(FuzzySearch.match(query: "rls", in: "Release"))
        // r at 0, l at 2, s at 6 — three separate ranges.
        #expect(m.ranges.count == 3)
        #expect(m.ranges[0] == 0..<1)
    }

    @Test("Consecutive match scores higher than scattered")
    func consecutiveBeatsScattered() throws {
        let consec = try #require(FuzzySearch.match(query: "rel", in: "Release"))
        let scattered = try #require(FuzzySearch.match(query: "rel", in: "rXeXl"))
        #expect(consec.score > scattered.score)
    }

    @Test("Start-of-word bonus prefers boundary matches")
    func startOfWordBonus() throws {
        let boundary = try #require(FuzzySearch.match(query: "p", in: "Production"))
        let middle = try #require(FuzzySearch.match(query: "p", in: "tap"))
        #expect(boundary.score > middle.score)
    }

    @Test("Non-subsequence returns nil")
    func nonMatchReturnsNil() {
        #expect(FuzzySearch.match(query: "xyz", in: "Release") == nil)
    }

    @Test("Case-sensitive bonus rewards exact case")
    func caseSensitiveBonus() throws {
        let exact = try #require(FuzzySearch.match(query: "Re", in: "Release"))
        let mixed = try #require(FuzzySearch.match(query: "re", in: "Release"))
        #expect(exact.score > mixed.score)
    }

    @Test("Searching 1000 candidates completes under 50ms", .timeLimit(.minutes(1)))
    func performanceUnderFiftyMs() {
        var candidates: [String] = []
        for i in 0..<1000 {
            candidates.append("command-\(i)-action-\(i % 7)")
        }
        let start = Date()
        var hits = 0
        for c in candidates {
            if FuzzySearch.match(query: "act3", in: c) != nil { hits += 1 }
        }
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 0.050, "FuzzySearch took \(elapsed)s for 1000 candidates")
        #expect(hits > 0)
    }
}
