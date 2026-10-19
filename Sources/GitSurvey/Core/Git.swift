//
//  Git.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  One git, configured once. Every call reads only: `--no-optional-locks`
//  keeps `status` from refreshing the index; the fsmonitor is off so no
//  daemon is started on someone's behalf; signatures are not checked, so
//  `log` never runs gpg.
//

import Foundation

struct Git: Sendable {

    let executable: String

    /// Commits ahead of HEAD per branch, `%(ahead-behind:HEAD)`, needs 2.41.
    let hasAheadBehind: Bool

    /// Finds git and checks its version.
    ///
    /// - Throws: ``GitSurveyError/gitNotFound``, ``GitSurveyError/gitTooOld(_:)``.
    static func locate() async throws -> Git {
        guard let executable = Tools.locate("git") else { throw GitSurveyError.gitNotFound }
        let result = try await Spawn.run(executable, ["--version"], environment: Tools.quietEnvironment, timeout: 15)
        let text = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let version = VersionText.parse(text) else { throw GitSurveyError.toolFailed(tool: "git", reason: text) }
        guard VersionText.atLeast(version, 2, 35) else { throw GitSurveyError.gitTooOld("\(version.major).\(version.minor)") }
        return Git(executable: executable, hasAheadBehind: VersionText.atLeast(version, 2, 41))
    }

    /// Runs `git -C <repository> <arguments>` with the read-only settings.
    func run(_ arguments: [String], in repository: String, timeout: Double) async throws -> ChildResult {
        let settings = ["-C", repository, "--no-optional-locks", "-c", "core.fsmonitor=false",
                        "-c", "log.showSignature=false", "-c", "color.ui=false"]
        return try await Spawn.run(executable, settings + arguments, environment: Tools.quietEnvironment, timeout: timeout)
    }
}
