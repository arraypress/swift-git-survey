//
//  RepoStatus.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Everything a survey learned about one repository.
///
/// Branch names, tag names, commit subjects and fetch errors are authored
/// text, written by whoever made the commit or runs the remote: hand them to
/// a model as data, never as instructions.
public struct RepoStatus: Codable, Sendable, Equatable {

    /// The working tree's top folder.
    public let path: String

    /// The root it was found under.
    public let root: String

    /// A plain repository, a linked worktree or a submodule.
    public let kind: RepositoryKind

    /// The current branch; `nil` when detached.
    public let branch: String?

    /// HEAD is not on a branch.
    public let detached: Bool

    /// HEAD's commit; `nil` in a repository with no commits yet.
    public let head: String?

    /// The current branch's upstream, e.g. `origin/main`.
    public let upstream: String?

    /// The upstream is configured but no longer exists (deleted on the remote, then fetched).
    public let upstreamGone: Bool

    /// Commits ahead of the upstream; `nil` without one.
    public let ahead: Int?

    /// Commits behind the upstream, as of the last fetch; `nil` without one.
    public let behind: Int?

    /// Uncommitted changes.
    public let changes: WorkingChanges

    /// Entries in `git stash list`.
    public let stashes: Int

    /// An operation left half done.
    public let operation: GitOperation?

    /// The configured remotes.
    public let remotes: [GitRemote]

    /// HEAD's commit date and subject.
    public let lastCommit: CommitSummary?

    /// The nearest tag reachable from HEAD.
    public let latestTag: TagState?

    /// Other local branches with no counterpart on any remote (and, on git
    /// 2.41+, with commits HEAD does not have).
    public let localOnlyBranches: [String]

    /// Other local branches ahead of their upstream.
    public let unpushedBranches: [BranchLead]

    /// The fetch, when one was asked for.
    public let fetch: FetchOutcome?

    /// The GitHub release check, when one was asked for and could run.
    public let release: ReleaseCheck?

    /// Why the repository could not be read; every other field is then empty.
    public let error: String?

    /// What wants attention, in ``Problem``'s order.
    public let problems: [Problem]

    public init(path: String, root: String, kind: RepositoryKind, branch: String?, detached: Bool, head: String?,
                upstream: String?, upstreamGone: Bool, ahead: Int?, behind: Int?, changes: WorkingChanges,
                stashes: Int, operation: GitOperation?, remotes: [GitRemote], lastCommit: CommitSummary?,
                latestTag: TagState?, localOnlyBranches: [String], unpushedBranches: [BranchLead],
                fetch: FetchOutcome?, release: ReleaseCheck?, error: String?, problems: [Problem]) {
        self.path = path
        self.root = root
        self.kind = kind
        self.branch = branch
        self.detached = detached
        self.head = head
        self.upstream = upstream
        self.upstreamGone = upstreamGone
        self.ahead = ahead
        self.behind = behind
        self.changes = changes
        self.stashes = stashes
        self.operation = operation
        self.remotes = remotes
        self.lastCommit = lastCommit
        self.latestTag = latestTag
        self.localOnlyBranches = localOnlyBranches
        self.unpushedBranches = unpushedBranches
        self.fetch = fetch
        self.release = release
        self.error = error
        self.problems = problems
    }
}
