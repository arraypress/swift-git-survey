//
//  Problem.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Something about a repository that wants a person's (or an agent's) attention.
///
/// The raw values are a public contract: they appear in JSON and agents
/// filter on them.
public enum Problem: String, Codable, Sendable, CaseIterable, Comparable {
    /// Staged, unstaged or untracked changes.
    case dirty
    /// Unmerged paths.
    case conflicted
    /// A merge, rebase, cherry-pick, revert, am or bisect was left half done.
    case inProgress = "in_progress"
    /// HEAD is not on a branch.
    case detached
    /// Commits on the current branch that its upstream does not have.
    case ahead
    /// Commits on the upstream that the current branch does not have.
    case behind
    /// The current branch has no upstream, or its upstream is gone, though the repository has a remote.
    case noUpstream = "no_upstream"
    /// The repository has no remote at all.
    case noRemote = "no_remote"
    /// Stashed changes.
    case stashed
    /// Other local branches with commits no remote has: no counterpart on any
    /// remote, or ahead of their upstream.
    case localBranches = "local_branches"
    /// Commits since the latest tag reachable from HEAD.
    case untagged
    /// The latest tag is not on the remote (known only after a fetch).
    case unpushedTag = "unpushed_tag"
    /// `--fetch` failed or timed out for this repository.
    case fetchFailed = "fetch_failed"
    /// The latest tag has no published GitHub release (missing or draft).
    case noRelease = "no_release"
    /// The latest tag's GitHub release has no assets.
    case noReleaseAsset = "no_release_asset"
    /// The repository could not be read at all.
    case error

    /// Reported, but not by itself a reason for attention: commits since a
    /// tag are how every project spends most of its time. Ask for it by name.
    public var isInformational: Bool { self == .untagged }

    public static func < (lhs: Problem, rhs: Problem) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}
