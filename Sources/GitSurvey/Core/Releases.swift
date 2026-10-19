//
//  Releases.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  Whether the latest tag has a GitHub release with an asset, through gh.
//  Only github.com remotes are asked; gh missing or signed out skips the
//  whole check with a note, never failing the survey. Each call has its
//  own timeout and they run side by side.
//

import Foundation

enum Releases {

    /// What stopped the check, if anything, and the gh to use.
    static func gh(timeout: Double) async -> (executable: String?, note: String?) {
        guard let executable = Tools.locate("gh") else {
            return (nil, "gh is not installed, so GitHub releases were not checked (brew install gh)")
        }
        let auth = try? await Spawn.run(executable, ["auth", "status", "--hostname", "github.com"],
                                        environment: Tools.quietEnvironment, timeout: timeout)
        guard let auth, auth.succeeded else {
            let why = auth?.timedOut == true ? "gh auth status timed out" : "gh is not signed in to github.com (gh auth login)"
            return (nil, "\(why), so GitHub releases were not checked")
        }
        return (executable, nil)
    }

    /// The release check for `status`, or `nil` when there is nothing to ask:
    /// no tag, or no github.com remote.
    static func check(_ status: RepoStatus, gh: String, timeout: Double) async -> ReleaseCheck? {
        guard let tag = status.latestTag?.name,
              let remote = RemoteText.primary(status.remotes, upstream: status.upstream),
              let slug = RemoteText.gitHubSlug(remote.url) else { return nil }
        // A name starting with a dash would be read as an option.
        guard !tag.hasPrefix("-") else {
            return ReleaseCheck(repository: slug, tag: tag, state: .unknown, assets: nil, url: nil,
                                error: "a tag starting with a dash is not passed to gh")
        }
        do {
            let result = try await Spawn.run(gh, ["release", "view", tag, "--repo", slug, "--json", "tagName,isDraft,assets,url"],
                                             environment: Tools.quietEnvironment, timeout: timeout)
            return ReleaseJSON.check(repository: slug, tag: tag, result: result, timeout: timeout)
        } catch {
            return ReleaseCheck(repository: slug, tag: tag, state: .unknown, assets: nil, url: nil,
                                error: error.localizedDescription)
        }
    }
}
