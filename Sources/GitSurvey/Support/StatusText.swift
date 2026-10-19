//
//  StatusText.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  Reading `git status --porcelain=v2 --branch --show-stash -z`: header
//  lines start with "# ", then one record per changed path, each ended by
//  NUL. A rename or copy ("2 …") is followed by one more NUL-ended field,
//  the original path, which must be skipped or it would be read as a record.
//

import Foundation

enum StatusText {

    static func parse(_ data: Data) -> StatusSnapshot {
        var snapshot = StatusSnapshot()
        var staged = 0, unstaged = 0, untracked = 0, conflicted = 0
        let fields = data.split(separator: 0, omittingEmptySubsequences: false)
        var index = 0
        while index < fields.count {
            let record = String(decoding: fields[index], as: UTF8.self)
            index += 1
            if record.hasPrefix("# ") {
                header(record.dropFirst(2), into: &snapshot)
                continue
            }
            guard let kind = record.first else { continue }
            switch kind {
            case "1", "2":
                let xy = Array(record.dropFirst(2).prefix(2))
                if xy.count == 2 {
                    if xy[0] != "." { staged += 1 }
                    if xy[1] != "." { unstaged += 1 }
                }
                if kind == "2" { index += 1 }
            case "u": conflicted += 1
            case "?": untracked += 1
            default: break
            }
        }
        snapshot.changes = WorkingChanges(staged: staged, unstaged: unstaged, untracked: untracked,
                                          conflicted: conflicted)
        return snapshot
    }

    private static func header(_ line: Substring, into snapshot: inout StatusSnapshot) {
        let parts = line.split(separator: " ", maxSplits: 1)
        guard parts.count == 2 else { return }
        let value = String(parts[1])
        switch parts[0] {
        case "branch.oid":
            snapshot.head = value == "(initial)" ? nil : value
        case "branch.head":
            if value == "(detached)" { snapshot.detached = true } else { snapshot.branch = value }
        case "branch.upstream":
            snapshot.upstream = value
        case "branch.ab":
            let numbers = value.split(separator: " ").compactMap { Int($0.dropFirst()) }
            if numbers.count == 2 {
                snapshot.ahead = numbers[0]
                snapshot.behind = numbers[1]
            }
        case "stash":
            snapshot.stashes = Int(value) ?? 0
        default:
            break
        }
    }
}
