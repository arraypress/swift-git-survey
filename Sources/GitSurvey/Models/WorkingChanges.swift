//
//  WorkingChanges.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What is uncommitted in a working tree, counted from `git status --porcelain=v2`.
public struct WorkingChanges: Codable, Sendable, Equatable {

    /// Paths with changes in the index.
    public let staged: Int

    /// Tracked paths changed in the working tree but not staged.
    public let unstaged: Int

    /// Untracked entries; a new folder counts once, as `git status` shows it.
    public let untracked: Int

    /// Unmerged paths.
    public let conflicted: Int

    public init(staged: Int, unstaged: Int, untracked: Int, conflicted: Int) {
        self.staged = staged
        self.unstaged = unstaged
        self.untracked = untracked
        self.conflicted = conflicted
    }

    /// Nothing changed.
    public static let none = WorkingChanges(staged: 0, unstaged: 0, untracked: 0, conflicted: 0)
}
