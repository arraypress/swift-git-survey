//
//  ConfigText.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  Reading a repository's own config file for the two things a survey needs
//  from it — each remote's URL and each branch's remote — without starting
//  `git config`, which is a quarter of the processes a survey would
//  otherwise run. The file's grammar, as git-config(1) gives it:
//
//  - `[section]`, `[section "subsection"]` (the subsection case-sensitive,
//    with `\"` and `\\` escapes), or the old `[section.subsection]`;
//    section and key names are case-insensitive;
//  - `key = value`, or a bare `key`; `#` and `;` start a comment outside
//    double quotes; `\"`, `\\`, `\n`, `\t`, `\b` are escapes; a backslash at
//    the end of a line continues the value on the next; whitespace outside
//    quotes is trimmed at both ends and runs of it inside become one space.
//
//  A file that includes another (`[include]`, `[includeIf …]`) could
//  define remotes this reader would miss, so it reports that and the
//  caller asks git instead. The repository-level file is all that is read:
//  remotes in ~/.gitconfig are not a thing anyone does on purpose.
//

import Foundation

/// What a config file says about remotes.
struct ConfigFacts: Sendable, Equatable {
    var remotes: [GitRemote] = []
    var branchRemotes: [String: String] = [:]
    /// The file includes others: the facts may be incomplete.
    var includes = false
}

enum ConfigText {

    static func parse(_ text: String) -> ConfigFacts {
        var facts = ConfigFacts()
        var section = "", subsection: String?
        var lines = text.components(separatedBy: "\n")[...]
        while var line = lines.popFirst() {
            if line.hasSuffix("\r") { line.removeLast() }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") { continue }
            var rest = Substring(trimmed)
            if rest.hasPrefix("[") {
                guard let header = sectionHeader(&rest) else { section = ""; subsection = nil; continue }
                (section, subsection) = header
                if section == "include" || section == "includeif" { facts.includes = true }
                rest = rest.drop { $0 == " " || $0 == "\t" }
                if rest.isEmpty || rest.hasPrefix("#") || rest.hasPrefix(";") { continue }
            }
            // key [= value]
            let keyEnd = rest.firstIndex { !($0.isLetter || $0.isNumber || $0 == "-") } ?? rest.endIndex
            let key = rest[..<keyEnd].lowercased()
            var after = rest[keyEnd...].drop { $0 == " " || $0 == "\t" }
            var value = "true"
            if after.hasPrefix("=") {
                after = after.dropFirst()
                var raw = String(after)
                // A trailing backslash outside quotes continues the value on the next line.
                while endsInContinuation(raw), let next = lines.popFirst() {
                    raw.removeLast()
                    raw += next.hasSuffix("\r") ? String(next.dropLast()) : next
                }
                value = parseValue(raw)
            }
            switch (section, key) {
            case ("remote", "url"):
                if let name = subsection, !facts.remotes.contains(where: { $0.name == name }) {
                    facts.remotes.append(GitRemote(name: name, url: value))
                }
            case ("branch", "remote"):
                if let name = subsection { facts.branchRemotes[name] = value }
            default:
                break
            }
        }
        return facts
    }

    /// Reads `[section "sub"]` or `[section.sub]` from the start of `text`,
    /// leaving what follows the `]`.
    private static func sectionHeader(_ text: inout Substring) -> (String, String?)? {
        text = text.dropFirst()
        guard let close = closingBracket(text) else { return nil }
        let inside = text[..<close]
        text = text[text.index(after: close)...]
        if let quote = inside.firstIndex(of: "\"") {
            let name = inside[..<quote].trimmingCharacters(in: .whitespaces).lowercased()
            var sub = "", escaped = false
            for character in inside[inside.index(after: quote)...] {
                if escaped { sub.append(character); escaped = false; continue }
                if character == "\\" { escaped = true; continue }
                if character == "\"" { break }
                sub.append(character)
            }
            return (name, sub)
        }
        let parts = inside.split(separator: ".", maxSplits: 1)
        let name = parts.first.map { $0.lowercased() } ?? ""
        return (name, parts.count == 2 ? parts[1].lowercased() : nil)
    }

    /// The `]` that ends a header, skipping any inside the quoted subsection.
    private static func closingBracket(_ text: Substring) -> Substring.Index? {
        var quoted = false, escaped = false
        for index in text.indices {
            let character = text[index]
            if escaped { escaped = false; continue }
            if character == "\\" { escaped = true; continue }
            if character == "\"" { quoted.toggle(); continue }
            if character == "]" && !quoted { return index }
        }
        return nil
    }

    private static func endsInContinuation(_ raw: String) -> Bool {
        var quoted = false, escaped = false, last: Character?
        for character in raw {
            if escaped { escaped = false; last = nil; continue }
            if character == "\\" { escaped = true; last = "\\"; continue }
            if character == "\"" { quoted.toggle() }
            if !quoted && (character == "#" || character == ";") { return false }
            last = character
        }
        return escaped && last == "\\"
    }

    /// A value with quotes, escapes, comments and whitespace handled as git does.
    static func parseValue(_ raw: String) -> String {
        var result = "", quoted = false, pendingSpace = false, escaped = false
        for character in raw {
            if escaped {
                escaped = false
                if pendingSpace && !result.isEmpty { result.append(" ") }
                pendingSpace = false
                switch character {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "b": if !result.isEmpty { result.removeLast() }
                default: result.append(character)
                }
                continue
            }
            if character == "\\" { escaped = true; continue }
            if character == "\"" { quoted.toggle(); continue }
            if !quoted && (character == "#" || character == ";") { break }
            if !quoted && (character == " " || character == "\t") { pendingSpace = true; continue }
            if pendingSpace && !result.isEmpty { result.append(" ") }
            pendingSpace = false
            result.append(character)
        }
        return result
    }
}
