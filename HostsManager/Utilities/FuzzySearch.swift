import Foundation

/// Sublime Text–style fuzzy matcher for the ⌘K command palette.
///
/// Scoring rewards consecutive matches, matches at word boundaries, and
/// case-sensitive matches. Returns `nil` when the query isn't a subsequence.
enum FuzzySearch {

    struct Match {
        let score: Double
        /// UTF-16 offset ranges of matched characters in the candidate, for highlighting.
        let ranges: [Range<Int>]
    }

    /// Best-fit subsequence match. Empty `query` is treated as "match everything"
    /// at neutral score so callers can still rank by other signals.
    static func match(query: String, in candidate: String) -> Match? {
        if query.isEmpty {
            return Match(score: 0, ranges: [])
        }
        let q = Array(query)
        let c = Array(candidate)
        guard !c.isEmpty else { return nil }

        var matchedIndices: [Int] = []
        matchedIndices.reserveCapacity(q.count)

        var qi = 0
        var ci = 0
        while qi < q.count && ci < c.count {
            if q[qi].lowercased() == c[ci].lowercased() {
                matchedIndices.append(ci)
                qi += 1
            }
            ci += 1
        }
        guard qi == q.count else { return nil }

        var score: Double = 0
        var prev = -2
        for (idx, candIdx) in matchedIndices.enumerated() {
            let qChar = q[idx]
            let cChar = c[candIdx]

            // Consecutive bonus.
            if candIdx == prev + 1 {
                score += 5
            } else {
                score += 1
            }

            // Start-of-word bonus (first char or preceded by non-alphanum).
            if candIdx == 0 || isWordBoundary(c[candIdx - 1]) {
                score += 4
            }

            // Case-sensitive bonus.
            if qChar == cChar {
                score += 1
            }

            prev = candIdx
        }

        // Penalize length difference so shorter candidates win when scores tie.
        score -= Double(c.count - matchedIndices.count) * 0.05

        return Match(score: score, ranges: collapseRanges(matchedIndices))
    }

    private static func isWordBoundary(_ ch: Character) -> Bool {
        !ch.isLetter && !ch.isNumber
    }

    /// Collapse contiguous indices [1,2,3,7] → [1..<4, 7..<8].
    private static func collapseRanges(_ indices: [Int]) -> [Range<Int>] {
        guard let first = indices.first else { return [] }
        var ranges: [Range<Int>] = []
        var start = first
        var prev = first
        for idx in indices.dropFirst() {
            if idx == prev + 1 {
                prev = idx
            } else {
                ranges.append(start..<(prev + 1))
                start = idx
                prev = idx
            }
        }
        ranges.append(start..<(prev + 1))
        return ranges
    }
}
