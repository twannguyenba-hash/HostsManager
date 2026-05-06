import Foundation

enum EnvParser {
    private static let disabledPattern = try! NSRegularExpression(
        pattern: #"^[A-Za-z_][A-Za-z0-9_]*\s*="#
    )
    private static let keyValuePattern = try! NSRegularExpression(
        pattern: #"^([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$"#
    )

    static func parse(_ content: String) -> [EnvEntry] {
        var rawLines = content.components(separatedBy: "\n")
        // A trailing newline produces an empty final element — drop it so we don't synthesize a spurious blank entry
        if rawLines.last?.isEmpty == true {
            rawLines.removeLast()
        }

        var entries: [EnvEntry] = []
        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                entries.append(EnvEntry(isBlankOrComment: true, rawLine: line))
                continue
            }

            if trimmed.hasPrefix("#") {
                let stripped = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if matches(disabledPattern, stripped), let parsed = parseKeyValue(stripped) {
                    entries.append(EnvEntry(
                        key: parsed.key,
                        value: parsed.value,
                        comment: parsed.comment,
                        isEnabled: false
                    ))
                } else {
                    entries.append(EnvEntry(isBlankOrComment: true, rawLine: line))
                }
                continue
            }

            if let parsed = parseKeyValue(trimmed) {
                entries.append(EnvEntry(
                    key: parsed.key,
                    value: parsed.value,
                    comment: parsed.comment,
                    isEnabled: true
                ))
            } else {
                // Unparseable line — preserve verbatim
                entries.append(EnvEntry(isBlankOrComment: true, rawLine: line))
            }
        }

        return entries
    }

    static func format(_ entries: [EnvEntry]) -> String {
        var lines: [String] = []
        for entry in entries {
            if entry.isBlankOrComment {
                lines.append(entry.rawLine ?? "")
            } else {
                lines.append(formatEntry(entry))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private

    private struct ParsedKV {
        let key: String
        let value: String
        let comment: String
    }

    private static func matches(_ pattern: NSRegularExpression, _ s: String) -> Bool {
        let range = NSRange(s.startIndex..., in: s)
        return pattern.firstMatch(in: s, range: range) != nil
    }

    private static func parseKeyValue(_ s: String) -> ParsedKV? {
        let range = NSRange(s.startIndex..., in: s)
        guard let match = keyValuePattern.firstMatch(in: s, range: range),
              let keyRange = Range(match.range(at: 1), in: s),
              let restRange = Range(match.range(at: 2), in: s) else { return nil }

        let key = String(s[keyRange])
        let rest = String(s[restRange])
        let (value, comment) = splitValueAndInlineComment(rest)
        return ParsedKV(key: key, value: value, comment: comment)
    }

    private static func splitValueAndInlineComment(_ raw: String) -> (String, String) {
        // Trim leading whitespace after '='
        var value = String(raw.drop(while: { $0 == " " || $0 == "\t" }))

        if value.hasPrefix("\"") {
            if let closing = indexOfUnescapedQuote(in: value, quote: "\"") {
                let inner = String(value[value.index(after: value.startIndex)..<closing])
                let after = value[value.index(after: closing)...]
                let comment = extractInlineComment(after)
                return (unescapeDoubleQuoted(inner), comment)
            }
        } else if value.hasPrefix("'") {
            if let closing = indexOfUnescapedQuote(in: value, quote: "'") {
                let inner = String(value[value.index(after: value.startIndex)..<closing])
                let after = value[value.index(after: closing)...]
                let comment = extractInlineComment(after)
                return (inner, comment)
            }
        }

        // Plain value — inline comment starts at first " #" or "\t#"
        if let markerRange = value.range(of: " #") ?? value.range(of: "\t#") {
            let comment = String(value[markerRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            value = String(value[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            return (value, comment)
        }

        return (value.trimmingCharacters(in: .whitespaces), "")
    }

    private static func extractInlineComment<S: StringProtocol>(_ after: S) -> String {
        let trimmed = after.drop(while: { $0 == " " || $0 == "\t" })
        guard trimmed.hasPrefix("#") else { return "" }
        return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    private static func indexOfUnescapedQuote(in s: String, quote: Character) -> String.Index? {
        var idx = s.index(after: s.startIndex)
        while idx < s.endIndex {
            let ch = s[idx]
            if ch == "\\" {
                let next = s.index(after: idx)
                if next < s.endIndex {
                    idx = s.index(after: next)
                    continue
                }
            }
            if ch == quote {
                return idx
            }
            idx = s.index(after: idx)
        }
        return nil
    }

    private static func unescapeDoubleQuoted(_ s: String) -> String {
        var result = ""
        var i = s.startIndex
        while i < s.endIndex {
            let ch = s[i]
            if ch == "\\" {
                let next = s.index(after: i)
                if next < s.endIndex {
                    let nc = s[next]
                    switch nc {
                    case "n": result.append("\n")
                    case "t": result.append("\t")
                    case "r": result.append("\r")
                    case "\"": result.append("\"")
                    case "\\": result.append("\\")
                    default: result.append(nc)
                    }
                    i = s.index(after: next)
                    continue
                }
            }
            result.append(ch)
            i = s.index(after: i)
        }
        return result
    }

    private static func formatEntry(_ entry: EnvEntry) -> String {
        let formattedValue = formatValue(entry.value)
        var line = entry.isEnabled
            ? "\(entry.key)=\(formattedValue)"
            : "# \(entry.key)=\(formattedValue)"
        if !entry.comment.isEmpty {
            line += " # \(entry.comment)"
        }
        return line
    }

    private static func formatValue(_ value: String) -> String {
        let needsQuoting = value.contains(" ")
            || value.contains("\t")
            || value.contains("#")
            || value.contains("\"")
            || value.contains("\n")
        guard needsQuoting else { return value }

        var escaped = ""
        for ch in value {
            switch ch {
            case "\\": escaped.append("\\\\")
            case "\"": escaped.append("\\\"")
            case "\n": escaped.append("\\n")
            case "\t": escaped.append("\\t")
            default: escaped.append(ch)
            }
        }
        return "\"\(escaped)\""
    }
}
