//
//  GitSurveyError.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why a survey could not run, in words a caller can print unchanged.
///
/// A repository that cannot be read does not throw: it comes back with
/// ``RepoStatus/error`` set, so one broken repository never hides the rest.
public enum GitSurveyError: Error, LocalizedError, Equatable, Sendable {

    /// No `git` on PATH or at /usr/bin/git.
    case gitNotFound

    /// git is older than the 2.35 this library needs (`status --show-stash`).
    case gitTooOld(String)

    /// A root to search does not exist.
    case noSuchRoot(String)

    /// The path is not inside a git working tree.
    case notARepository(String)

    /// A program could not be started.
    case toolFailed(tool: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .gitNotFound:
            return "git was not found on PATH"
        case .gitTooOld(let version):
            return "git \(version) is too old; 2.35 or later is needed"
        case .noSuchRoot(let path):
            return "no such folder: \(path)"
        case .notARepository(let path):
            return "not inside a git repository: \(path)"
        case .toolFailed(let tool, let reason):
            return "\(tool) could not be started: \(reason)"
        }
    }
}
