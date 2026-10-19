//
//  ProblemRules.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  What counts as wanting attention. One place, so `repos`, its summary and
//  its exit code can never disagree.
//

import Foundation

enum ProblemRules {

    /// The problems `status` shows; its own `problems` are ignored.
    static func problems(of status: RepoStatus) -> [Problem] {
        if status.error != nil { return [.error] }
        let changes = status.changes, detached = status.detached, head = status.head
        let upstream = status.upstream, upstreamGone = status.upstreamGone, ahead = status.ahead
        let behind = status.behind, stashes = status.stashes, operation = status.operation
        let remotes = status.remotes, latestTag = status.latestTag, localOnly = status.localOnlyBranches
        let unpushed = status.unpushedBranches, fetch = status.fetch, release = status.release
        var found: [Problem] = []
        if changes.staged + changes.unstaged + changes.untracked > 0 { found.append(.dirty) }
        if changes.conflicted > 0 { found.append(.conflicted) }
        if operation != nil { found.append(.inProgress) }
        if detached { found.append(.detached) }
        if (ahead ?? 0) > 0 { found.append(.ahead) }
        if (behind ?? 0) > 0 { found.append(.behind) }
        // A branch with commits that tracks nothing, in a repository that has somewhere to push.
        if !detached, head != nil, !remotes.isEmpty, upstream == nil || upstreamGone { found.append(.noUpstream) }
        if remotes.isEmpty { found.append(.noRemote) }
        if stashes > 0 { found.append(.stashed) }
        if !localOnly.isEmpty || !unpushed.isEmpty { found.append(.localBranches) }
        if let latestTag, latestTag.commitsSince > 0 { found.append(.untagged) }
        if latestTag?.onRemote == false { found.append(.unpushedTag) }
        if let fetch, !fetch.succeeded { found.append(.fetchFailed) }
        switch release?.state {
        case .missing?, .draft?: found.append(.noRelease)
        case .noAssets?: found.append(.noReleaseAsset)
        default: break
        }
        return found
    }
}
