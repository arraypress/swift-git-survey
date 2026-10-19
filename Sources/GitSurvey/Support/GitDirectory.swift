//
//  GitDirectory.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  Where a working tree's git directory is, what kind of tree that makes it,
//  and whether an operation was left half done — all read from files, so
//  none of it costs a process. A `.git` file says `gitdir: <path>`, relative
//  to the working tree when not absolute. A linked worktree's git directory
//  sits in its main repository's `worktrees/`, a submodule's in the
//  superproject's `modules/`. Rebase and merge state lives in the
//  per-worktree git directory, so a worktree's half-done rebase is its own.
//

import Foundation

enum GitDirectory {

    /// The path a `.git` file points at, resolved against the working tree.
    static func target(ofGitFile contents: String, workTree: String) -> String? {
        guard let line = contents.split(whereSeparator: \.isNewline).first, line.hasPrefix("gitdir:") else { return nil }
        let path = line.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return nil }
        let absolute = path.hasPrefix("/") ? path : (workTree as NSString).appendingPathComponent(path)
        return (absolute as NSString).standardizingPath
    }

    /// What kind of tree a git directory at `path` makes.
    static func kind(gitDirectory path: String, gitFile: Bool) -> RepositoryKind {
        guard gitFile else { return .repository }
        let parent = ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent
        if parent == "worktrees" { return .worktree }
        if path.contains("/modules/") { return .submodule }
        return .repository
    }

    /// The half-done operation, from the marker files in the git directory.
    /// `exists` answers for a name inside it.
    static func operation(exists: (String) -> Bool) -> GitOperation? {
        if exists("rebase-merge") { return .rebase }
        if exists("rebase-apply") { return exists("rebase-apply/applying") ? .am : .rebase }
        if exists("MERGE_HEAD") { return .merge }
        if exists("CHERRY_PICK_HEAD") { return .cherryPick }
        if exists("REVERT_HEAD") { return .revert }
        if exists("BISECT_LOG") { return .bisect }
        return nil
    }
}
