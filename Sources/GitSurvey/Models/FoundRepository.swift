//
//  FoundRepository.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A working tree found on disk, before git has been asked anything.
public struct FoundRepository: Codable, Sendable, Equatable, Hashable {

    /// The working tree's top folder.
    public let path: String

    /// The root it was found under.
    public let root: String

    /// Whether `.git` is a file (a worktree, a submodule, a separate git dir).
    public let gitFile: Bool

    public init(path: String, root: String, gitFile: Bool) {
        self.path = path
        self.root = root
        self.gitFile = gitFile
    }
}
