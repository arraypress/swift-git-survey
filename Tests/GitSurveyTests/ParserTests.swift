//
//  ParserTests.swift
//  GitSurveyTests
//
//  Created by David Sherlock on 2026.
//
//  The pure readers, on output written out by hand where the fixture
//  cannot easily produce it: renames in porcelain v2, tags that look like
//  describe's suffix, remote URL spellings, odd remote names.
//

import Foundation
import Testing
@testable import GitSurvey

struct ParserTests {

    @Test func aRenameRecordDoesNotCountItsOriginalPathAsAnotherRecord() {
        let records = [
            "# branch.oid 1111111111111111111111111111111111111111", "# branch.head main",
            "# branch.upstream origin/main", "# branch.ab +3 -4", "# stash 2",
            "2 R. N... 100644 100644 100644 aaaa bbbb R100 new name.txt", "? looks like a record.txt",
            "1 .M N... 100644 100644 100644 aaaa aaaa b.txt", "1 .M N... 100644 100644 100644 aaaa aaaa e.txt",
            "1 MM N... 100644 100644 100644 aaaa bbbb cccc f.txt", "1 A. N... 000000 100644 100644 0000 aaaa g.txt",
            "u UU N... 100644 100644 100644 100644 a b c c.txt", "? d.txt", "! ignored.txt",
        ]
        let status = StatusText.parse(Data((records.joined(separator: "\0") + "\0").utf8))
        #expect(status.branch == "main" && status.upstream == "origin/main")
        #expect(status.ahead == 3 && status.behind == 4 && status.stashes == 2 && !status.upstreamGone)
        #expect(status.changes == WorkingChanges(staged: 3, unstaged: 3, untracked: 1, conflicted: 1))
    }

    @Test func describeSplitsOnlyASuffixThatNamesHead() {
        let head = "abcdef0123456789abcdef0123456789abcdef01"
        #expect(LogText.describe("v1.2-3-g\(head)", head: head)! == ("v1.2", 3))
        #expect(LogText.describe("v1.2", head: head)! == ("v1.2", 0))
        #expect(LogText.describe("release-1-gabc", head: head)! == ("release-1-gabc", 0))
        #expect(LogText.describe("my-tag-12-g\(head)", head: head)! == ("my-tag", 12))
        #expect(LogText.describe("", head: head) == nil)
    }

    @Test func remotesWithDotsAndBranchRemotes() {
        let output = "remote.origin.url\ngit@github.com:o/r.git\0remote.my.fork.url\nhttps://github.com/me/r\0branch.feat.x.remote\nmy.fork\0remote.origin.url\nsecond\0"
        #expect(RemoteText.parse(output) == [GitRemote(name: "origin", url: "git@github.com:o/r.git"),
                                             GitRemote(name: "my.fork", url: "https://github.com/me/r")])
        #expect(RemoteText.branchRemotes(output) == ["feat.x": "my.fork"])
        let remotes = RemoteText.parse(output)
        #expect(RemoteText.primary(remotes, upstream: "my.fork/main")?.name == "my.fork")
        #expect(RemoteText.primary(remotes, upstream: nil)?.name == "origin")
        #expect(RemoteText.primary([], upstream: nil) == nil)
    }

    @Test func gitHubSlugsInEverySpelling() {
        #expect(RemoteText.gitHubSlug("git@github.com:owner/name.git") == "owner/name")
        #expect(RemoteText.gitHubSlug("https://github.com/owner/name") == "owner/name")
        #expect(RemoteText.gitHubSlug("https://github.com/owner/name.git/") == "owner/name")
        #expect(RemoteText.gitHubSlug("ssh://git@github.com/owner/name.git") == "owner/name")
        #expect(RemoteText.gitHubSlug("https://gitlab.com/owner/name") == nil)
        #expect(RemoteText.gitHubSlug("github-work:owner/name.git") == nil)
        #expect(RemoteText.gitHubSlug("/srv/git/name.git") == nil)
        #expect(RemoteText.gitHubSlug("https://github.com/owner") == nil)
    }

    @Test func skipRules() {
        for name in [".build", "node_modules", "Packages", "DerivedData", ".swiftpm", "checkouts", ".git", ".cache",
                     "Foo.app", "Photos Library.photoslibrary"] {
            #expect(SkipRules.skips(name, depth: 3, home: false), "\(name)")
        }
        for name in ["Sources", "Library", "Dropbox", "my.project"] {
            #expect(!SkipRules.skips(name, depth: 1, home: false), "\(name)")
        }
        for name in ["Library", "Dropbox", "Dropbox (Work)", "OneDrive - Company", "Google Drive", "Pictures"] {
            #expect(SkipRules.skips(name, depth: 1, home: true), "\(name)")
            #expect(!SkipRules.skips(name, depth: 2, home: true), "\(name) deeper down is an ordinary folder")
        }
    }

    @Test func gitFilesAndKinds() {
        #expect(GitDirectory.target(ofGitFile: "gitdir: ../main/.git/worktrees/wt\n", workTree: "/r/wt") == "/r/main/.git/worktrees/wt")
        #expect(GitDirectory.target(ofGitFile: "gitdir: /abs/.git/modules/lib", workTree: "/x") == "/abs/.git/modules/lib")
        #expect(GitDirectory.target(ofGitFile: "nonsense", workTree: "/x") == nil)
        #expect(GitDirectory.kind(gitDirectory: "/r/.git/worktrees/wt", gitFile: true) == .worktree)
        #expect(GitDirectory.kind(gitDirectory: "/r/.git/modules/lib", gitFile: true) == .submodule)
        #expect(GitDirectory.kind(gitDirectory: "/elsewhere/repo.git", gitFile: true) == .repository)
        #expect(GitDirectory.kind(gitDirectory: "/r/.git/worktrees/wt", gitFile: false) == .repository)
        #expect(GitDirectory.operation { ["rebase-apply", "rebase-apply/applying"].contains($0) } == .am)
        #expect(GitDirectory.operation { $0 == "CHERRY_PICK_HEAD" } == .cherryPick)
        #expect(GitDirectory.operation { $0 == "REVERT_HEAD" } == .revert)
        #expect(GitDirectory.operation { $0 == "BISECT_LOG" } == .bisect)
        #expect(GitDirectory.operation { _ in false } == nil)
    }

    @Test func versions() {
        #expect(VersionText.parse("git version 2.39.5 (Apple Git-154)")! == (2, 39))
        #expect(VersionText.atLeast((2, 41), 2, 41) && !VersionText.atLeast((2, 40), 2, 41) && VersionText.atLeast((3, 0), 2, 41))
        #expect(VersionText.parse("nonsense") == nil)
    }

    @Test func refTrackingWords() {
        #expect(RefText.count("ahead", in: "ahead 2, behind 1") == 2)
        #expect(RefText.count("behind", in: "ahead 2, behind 1") == 1)
        #expect(RefText.count("ahead", in: "gone") == 0)
        #expect(TagText.names("aaa\trefs/tags/v1\nbbb\trefs/tags/v2.0-rc\n") == ["v1", "v2.0-rc"])
    }

    @Test func releaseAnswers() {
        func run(_ status: Int32, _ out: String, _ err: String = "", timedOut: Bool = false) -> ReleaseCheck {
            ReleaseJSON.check(repository: "o/r", tag: "v1",
                              result: ChildResult(status: status, stdout: Data(out.utf8), stderr: Data(err.utf8), timedOut: timedOut),
                              timeout: 20)
        }
        let published = run(0, #"{"assets":[{"name":"x.tar.gz"}],"isDraft":false,"tagName":"v1","url":"https://github.com/o/r/releases/tag/v1"}"#)
        #expect(published.state == .published && published.assets == 1 && published.url?.hasSuffix("/v1") == true)
        #expect(run(0, #"{"assets":[],"isDraft":false}"#).state == .noAssets)
        #expect(run(0, #"{"assets":[{"name":"x"}],"isDraft":true}"#).state == .draft)
        #expect(run(1, "", "release not found\n").state == .missing)
        let unknown = run(1, "", "GraphQL: Could not resolve to a Repository with the name 'o/r'.\n")
        #expect(unknown.state == .unknown && unknown.error?.contains("Could not resolve") == true)
        #expect(run(0, "", timedOut: true).error == "gh timed out after 20 s")
    }

    @Test func releaseProblems() {
        func problems(_ state: ReleaseState) -> [Problem] {
            let base = RepoStatus(path: "/r", root: "/", kind: .repository, branch: "main", detached: false, head: "a",
                                  upstream: "origin/main", upstreamGone: false, ahead: 0, behind: 0, changes: .none,
                                  stashes: 0, operation: nil, remotes: [GitRemote(name: "origin", url: "u")],
                                  lastCommit: nil, latestTag: TagState(name: "v1", commitsSince: 0, onRemote: true),
                                  localOnlyBranches: [], unpushedBranches: [], fetch: nil, release: nil, error: nil,
                                  problems: [])
            return base.with(release: ReleaseCheck(repository: "o/r", tag: "v1", state: state, assets: nil, url: nil, error: nil)).problems
        }
        #expect(problems(.published) == [])
        #expect(problems(.missing) == [.noRelease])
        #expect(problems(.draft) == [.noRelease])
        #expect(problems(.noAssets) == [.noReleaseAsset])
        #expect(problems(.unknown) == [])
    }
}
