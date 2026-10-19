//
//  LogText.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  Reading `git log -1 --format=%H%x00%ct%x00%s%x00%(describe:tags=true,abbrev=40)`:
//  HEAD's commit, its date and subject, and the nearest tag in one call.
//  `%(describe)` prints `v1.2` on the tagged commit itself and
//  `v1.2-3-g<hash>` past it; nothing when no tag is reachable.
//

import Foundation

/// HEAD as `git log -1` describes it.
struct LogLine: Sendable, Equatable {
    let head: String
    let commit: CommitSummary
    let tag: String?
    let commitsSinceTag: Int
}

enum LogText {

    /// The format string the parser expects.
    static let format = "%H%x00%ct%x00%s%x00%(describe:tags=true,abbrev=40)"

    static func parse(_ output: String) -> LogLine? {
        let fields = output.trimmingCharacters(in: .newlines).split(separator: "\0", omittingEmptySubsequences: false)
            .map(String.init)
        guard fields.count >= 4, let seconds = TimeInterval(fields[1]) else { return nil }
        let head = fields[0]
        let described = describe(fields[3], head: head)
        return LogLine(head: head, commit: CommitSummary(date: Date(timeIntervalSince1970: seconds), subject: fields[2]),
                       tag: described?.tag, commitsSinceTag: described?.since ?? 0)
    }

    /// Splits describe's output into the tag and the commits since it. A
    /// `-N-g<hex>` suffix counts only when the hex is at least 7 digits and
    /// the start of HEAD's hash, so a tag that merely looks like one
    /// (`v1-2-gabc`) stays whole.
    static func describe(_ text: String, head: String) -> (tag: String, since: Int)? {
        guard !text.isEmpty else { return nil }
        guard let g = text.range(of: "-g", options: .backwards) else { return (text, 0) }
        let hex = text[g.upperBound...]
        let stem = text[..<g.lowerBound]
        guard hex.count >= 7, head.hasPrefix(hex), let dash = stem.range(of: "-", options: .backwards),
              let count = Int(stem[dash.upperBound...]) else { return (text, 0) }
        return (String(stem[..<dash.lowerBound]), count)
    }
}
