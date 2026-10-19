//
//  StatusSnapshot.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What one `git status --porcelain=v2 --branch --show-stash -z` says.
struct StatusSnapshot: Sendable, Equatable {
    var head: String?
    var branch: String?
    var detached = false
    var upstream: String?
    var ahead: Int?
    var behind: Int?
    var changes = WorkingChanges.none
    var stashes = 0

    /// An upstream is named but `branch.ab` is missing: it no longer exists.
    var upstreamGone: Bool { upstream != nil && ahead == nil }
}
