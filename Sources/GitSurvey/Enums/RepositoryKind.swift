//
//  RepositoryKind.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What kind of working tree a `.git` entry makes.
public enum RepositoryKind: String, Codable, Sendable, CaseIterable {

    /// A `.git` directory, or a `.git` file to a separate git directory.
    case repository

    /// A linked worktree: a `.git` file pointing into another repository's
    /// `worktrees/`. Its stashes and branches are that repository's.
    case worktree

    /// A submodule: a `.git` file pointing into a superproject's `modules/`.
    case submodule
}
