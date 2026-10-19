//
//  ConfigTests.swift
//  GitSurveyTests
//
//  Created by David Sherlock on 2026.
//
//  The config-file reader that replaces a `git config` process per
//  repository must say exactly what git says. Checked three ways: tricky
//  syntax written out by hand; every fixture repository against git
//  itself; and, opt-in (GITSURVEY_COMPARE_ROOT=<folder>), every repository
//  under a real folder.
//

import Foundation
import Testing
@testable import GitSurvey

struct ConfigTests {

    @Test func theGrammarsCornerCases() {
        let text = """
        [core]
        \tbare = false
        [remote "origin"]
        \turl = git@github.com:o/r.git ; a comment
        \tfetch = +refs/heads/*:refs/remotes/origin/*
        [Remote "My \\"Fork\\""]
        \tURL = "https://example.com/a b.git" # quoted space kept
        [remote "cont"]
        \turl = https://example.com/\\
        long.git
        [branch "Feature/X"]
        \tremote = My "Fork"
        [branch.lower]
        \tremote = origin
        [remote "origin"]
        \turl = second-url-ignored
        """
        let facts = ConfigText.parse(text)
        #expect(facts.remotes == [GitRemote(name: "origin", url: "git@github.com:o/r.git"),
                                  GitRemote(name: "My \"Fork\"", url: "https://example.com/a b.git"),
                                  GitRemote(name: "cont", url: "https://example.com/long.git")])
        #expect(facts.branchRemotes == ["Feature/X": "My Fork", "lower": "origin"])
        #expect(!facts.includes)
        #expect(ConfigText.parse("[includeIf \"gitdir:~/w/\"]\n\tpath = x").includes)
        #expect(ConfigText.parse("[include]\n\tpath = x").includes)
        #expect(ConfigText.parseValue(#"  a   b  "#) == "a b")
        #expect(ConfigText.parseValue(#""a\tb" c\\d \"e\""#) == "a\tb c\\d \"e\"")
    }

    /// The fixture includes a remote name with a space (branches) and a
    /// remote only an included file defines (stashed).
    @Test func agreesWithGitOnEveryFixtureRepository() async throws {
        let layout = try Fixture.main.get()
        let disagreements = try await compare(Survey.discover(roots: [layout.root], options: SurveyOptions(nested: true)))
        #expect(disagreements == [])
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GITSURVEY_COMPARE_ROOT"] != nil))
    func agreesWithGitOnARealFolder() async throws {
        let root = try #require(ProcessInfo.processInfo.environment["GITSURVEY_COMPARE_ROOT"])
        let found = try Survey.discover(roots: [root])
        let disagreements = try await compare(found)
        print("config reader: \(found.count) repositories compared, \(disagreements.count) disagreements")
        #expect(disagreements == [])
    }

    /// The repositories whose file-read remotes differ from `git config`'s.
    private func compare(_ found: [FoundRepository]) async throws -> [String] {
        let git = try await Git.locate()
        var disagreements: [String] = []
        for repository in found {
            var gitDirectory = (repository.path as NSString).appendingPathComponent(".git")
            if repository.gitFile {
                let contents = (try? String(contentsOfFile: gitDirectory, encoding: .utf8)) ?? ""
                gitDirectory = GitDirectory.target(ofGitFile: contents, workTree: repository.path) ?? gitDirectory
            }
            let fromFile = try await Inspector.remoteFacts(path: repository.path, gitDirectory: gitDirectory, git: git, timeout: 30)
            let result = try await git.run(["config", "-z", "--get-regexp", RemoteText.configPattern], in: repository.path, timeout: 30)
            let remotes = RemoteText.parse(result.output), branchRemotes = RemoteText.branchRemotes(result.output)
            if fromFile?.remotes != remotes || fromFile?.branchRemotes != branchRemotes {
                disagreements.append((repository.path as NSString).lastPathComponent)
            }
        }
        return disagreements
    }
}
