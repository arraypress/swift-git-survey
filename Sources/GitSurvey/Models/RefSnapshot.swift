//
//  RefSnapshot.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One local branch from `git for-each-ref`.
struct LocalBranch: Sendable, Equatable {
    let name: String
    /// Its upstream's full ref, e.g. `refs/remotes/origin/main`.
    let upstream: String?
    let ahead: Int
    let gone: Bool
    /// Commits it has that HEAD does not; `nil` when git is too old to say.
    let aheadOfHead: Int?
}

/// The branches `git for-each-ref refs/heads refs/remotes` lists.
struct RefSnapshot: Sendable, Equatable {
    var local: [LocalBranch] = []
    /// Remote-tracking branches as `remote/branch`, without `*/HEAD`.
    var remoteTracking: Set<String> = []
}
