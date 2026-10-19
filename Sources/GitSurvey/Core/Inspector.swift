//
//  Inspector.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  One repository, in as few processes as git allows:
//
//  1. the config file, read directly — the remotes, and which one the
//     current branch pulls from (`git config` only when it includes others);
//  2. with a fetch only: `git fetch` and `git ls-remote --tags` side by side;
//  3. side by side: `git status --porcelain=v2 --branch --show-stash -z`
//     (branch, upstream, ahead/behind, every change count, stashes),
//     `git log -1` (HEAD's date and subject, and the nearest tag with the
//     commits since it, through `%(describe)`), and `git for-each-ref`
//     (the other branches and what they track).
//
//  The git directory's marker files say whether a merge or rebase was left
//  half done, and HEAD's file names the branch before status runs, without
//  a process.
//

import Foundation

enum Inspector {

    static func inspect(_ found: FoundRepository, git: Git, options: SurveyOptions) async -> RepoStatus {
        let path = found.path
        let gitDirectory: String
        if found.gitFile {
            let contents = (try? String(contentsOfFile: (path as NSString).appendingPathComponent(".git"), encoding: .utf8)) ?? ""
            guard let target = GitDirectory.target(ofGitFile: contents, workTree: path) else {
                return failed(found, kind: .repository, "its .git file does not name a git directory")
            }
            gitDirectory = target
        } else {
            gitDirectory = (path as NSString).appendingPathComponent(".git")
        }
        let kind = GitDirectory.kind(gitDirectory: gitDirectory, gitFile: found.gitFile)
        guard FileManager.default.fileExists(atPath: gitDirectory) else {
            return failed(found, kind: kind, "its git directory is missing: \(gitDirectory)")
        }
        let operation = GitDirectory.operation { name in
            FileManager.default.fileExists(atPath: (gitDirectory as NSString).appendingPathComponent(name))
        }

        do {
            // 1. Remotes: from the config file, or from git when the file includes others.
            guard let facts = try await remoteFacts(path: path, gitDirectory: gitDirectory, git: git,
                                                    timeout: options.gitTimeout) else {
                return failed(found, kind: kind, "git config could not be read")
            }
            let remotes = facts.remotes
            let headBranch = currentBranch(gitDirectory: gitDirectory)
            let fetchRemote = headBranch.flatMap { facts.branchRemotes[$0] }
                .flatMap { name in remotes.first { $0.name == name } } ?? RemoteText.primary(remotes, upstream: nil)

            // 2. The fetch and the remote's tags.
            var fetch: FetchOutcome?
            var remoteTags: Set<String>?
            // A remote name starting with a dash would be read as an option.
            if options.fetch, let remote = fetchRemote, !remote.name.hasPrefix("-") {
                async let fetched = git.run(["fetch", "--quiet", "--no-tags", "--no-write-fetch-head",
                                             "--no-auto-maintenance", "--recurse-submodules=no", remote.name],
                                            in: path, timeout: options.fetchTimeout)
                async let listed = git.run(["ls-remote", "--tags", "--refs", remote.name], in: path,
                                           timeout: options.fetchTimeout)
                let (fetchResult, tagResult) = try await (fetched, listed)
                fetch = FetchOutcome(remote: remote.name, succeeded: fetchResult.succeeded,
                                     error: fetchResult.succeeded ? nil : describe(fetchResult, "git fetch", options.fetchTimeout))
                if tagResult.succeeded { remoteTags = TagText.names(tagResult.output) }
            }

            // 3. Everything else.
            async let statusRun = git.run(["status", "--porcelain=v2", "--branch", "--show-stash", "-z",
                                           "--untracked-files=normal"], in: path, timeout: options.gitTimeout)
            async let logRun = git.run(["log", "-1", "--no-show-signature", "--format=\(LogText.format)"], in: path,
                                       timeout: options.gitTimeout)
            async let refRun = git.run(["for-each-ref", "--format=\(RefText.format(aheadBehind: git.hasAheadBehind))",
                                        "refs/heads", "refs/remotes"], in: path, timeout: options.gitTimeout)
            let (statusResult, logResult, refResult) = try await (statusRun, logRun, refRun)
            guard statusResult.succeeded else {
                return failed(found, kind: kind, describe(statusResult, "git status", options.gitTimeout))
            }
            let status = StatusText.parse(statusResult.stdout)
            // log fails in a repository with no commits; that is not an error.
            let log = logResult.succeeded ? LogText.parse(logResult.output) : nil
            let refs = refResult.succeeded ? RefText.parse(refResult.output) : RefSnapshot()

            let tag = log?.tag.map { name in
                TagState(name: name, commitsSince: log?.commitsSinceTag ?? 0,
                         onRemote: remoteTags.map { $0.contains(name) })
            }
            let built = RepoStatus(
                path: path, root: found.root, kind: kind, branch: status.branch, detached: status.detached,
                head: status.head, upstream: status.upstream, upstreamGone: status.upstreamGone,
                ahead: status.ahead, behind: status.behind, changes: status.changes, stashes: status.stashes,
                operation: operation, remotes: remotes, lastCommit: log?.commit, latestTag: tag,
                localOnlyBranches: RefText.localOnly(refs, current: status.branch),
                unpushedBranches: RefText.unpushed(refs, current: status.branch),
                fetch: fetch, release: nil, error: nil, problems: [])
            return built.withProblems()
        } catch {
            return failed(found, kind: kind, error.localizedDescription)
        }
    }

    /// The remotes and branch remotes, read from the repository's config file
    /// (its common directory's, for a linked worktree) — or, when that file
    /// includes others or a per-worktree file exists, from `git config`,
    /// which follows them. `nil` when git itself fails.
    static func remoteFacts(path: String, gitDirectory: String, git: Git, timeout: Double) async throws -> ConfigFacts? {
        let common = (try? String(contentsOfFile: (gitDirectory as NSString).appendingPathComponent("commondir"), encoding: .utf8))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.hasPrefix("/") ? $0 : ((gitDirectory as NSString).appendingPathComponent($0) as NSString).standardizingPath }
            ?? gitDirectory
        let perWorktree = FileManager.default.fileExists(atPath: (gitDirectory as NSString).appendingPathComponent("config.worktree"))
        if !perWorktree,
           let text = try? String(contentsOfFile: (common as NSString).appendingPathComponent("config"), encoding: .utf8) {
            let facts = ConfigText.parse(text)
            if !facts.includes { return facts }
        }
        let config = try await git.run(["config", "-z", "--get-regexp", RemoteText.configPattern], in: path, timeout: timeout)
        // Exit 1 is "no such keys": a repository with no remote.
        guard config.status == 0 || (config.status == 1 && !config.timedOut) else { return nil }
        return ConfigFacts(remotes: RemoteText.parse(config.output), branchRemotes: RemoteText.branchRemotes(config.output),
                           includes: false)
    }

    /// The branch HEAD names, from the git directory's HEAD file.
    static func currentBranch(gitDirectory: String) -> String? {
        guard let head = try? String(contentsOfFile: (gitDirectory as NSString).appendingPathComponent("HEAD"), encoding: .utf8),
              head.hasPrefix("ref: refs/heads/") else { return nil }
        return String(head.dropFirst("ref: refs/heads/".count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A failed call in words: git's last line, or the timeout.
    static func describe(_ result: ChildResult, _ command: String, _ timeout: Double) -> String {
        if result.timedOut { return "\(command) timed out after \(Int(timeout)) s" }
        return result.reason.isEmpty ? "\(command) exited \(result.status)" : result.reason
    }

    private static func failed(_ found: FoundRepository, kind: RepositoryKind, _ error: String) -> RepoStatus {
        RepoStatus(path: found.path, root: found.root, kind: kind, branch: nil, detached: false, head: nil,
                   upstream: nil, upstreamGone: false, ahead: nil, behind: nil, changes: .none, stashes: 0,
                   operation: nil, remotes: [], lastCommit: nil, latestTag: nil, localOnlyBranches: [],
                   unpushedBranches: [], fetch: nil, release: nil, error: error, problems: [.error])
    }
}
