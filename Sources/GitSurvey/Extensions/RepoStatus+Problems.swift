//
//  RepoStatus+Problems.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

public extension RepoStatus {

    /// Something wants attention: any problem but the informational
    /// ``Problem/untagged``.
    var needsAttention: Bool { problems.contains { !$0.isInformational } }

    /// The last commit is older than `date` (a repository with no commits is not stale).
    func isStale(before date: Date) -> Bool { lastCommit.map { $0.date < date } ?? false }

    /// The repository on a remote: the upstream's remote, else `origin`, else the first.
    var primaryRemote: GitRemote? { RemoteText.primary(remotes, upstream: upstream) }
}

extension RepoStatus {

    /// The same status with its problems worked out (see ``ProblemRules``).
    func withProblems() -> RepoStatus { replacing(release: release) }

    /// The same status with a release check, and its problems worked out again.
    func with(release check: ReleaseCheck) -> RepoStatus { replacing(release: check) }

    private func replacing(release: ReleaseCheck?) -> RepoStatus {
        let draft = RepoStatus(
            path: path, root: root, kind: kind, branch: branch, detached: detached, head: head, upstream: upstream,
            upstreamGone: upstreamGone, ahead: ahead, behind: behind, changes: changes, stashes: stashes,
            operation: operation, remotes: remotes, lastCommit: lastCommit, latestTag: latestTag,
            localOnlyBranches: localOnlyBranches, unpushedBranches: unpushedBranches, fetch: fetch, release: release,
            error: error, problems: [])
        return RepoStatus(
            path: path, root: root, kind: kind, branch: branch, detached: detached, head: head, upstream: upstream,
            upstreamGone: upstreamGone, ahead: ahead, behind: behind, changes: changes, stashes: stashes,
            operation: operation, remotes: remotes, lastCommit: lastCommit, latestTag: latestTag,
            localOnlyBranches: localOnlyBranches, unpushedBranches: unpushedBranches, fetch: fetch, release: release,
            error: error, problems: ProblemRules.problems(of: draft))
    }
}
