//
//  Discovery.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  Finding working trees: a folder holding a `.git` entry, directory or
//  file. Folders are read with readdir, whose entry types make it cheap to
//  tell a folder from a file without a stat each; symbolic links are never
//  followed, so a link cannot loop the walk or reach outside the roots.
//

import Darwin
import Foundation

enum Discovery {

    /// Every working tree under `roots`, by path, each once.
    static func find(roots: [String], nested: Bool, home: Bool) -> [FoundRepository] {
        var found: [String: FoundRepository] = [:]
        for root in roots {
            var stack: [(path: String, depth: Int)] = [(root, 0)]
            while let (folder, depth) = stack.popLast() {
                let listing = list(folder)
                if let gitFile = listing.git, found[folder] == nil {
                    found[folder] = FoundRepository(path: folder, root: root, gitFile: gitFile)
                    if !nested { continue }
                }
                for name in listing.folders where !SkipRules.skips(name, depth: depth + 1, home: home) {
                    stack.append(((folder as NSString).appendingPathComponent(name), depth + 1))
                }
            }
        }
        return found.values.sorted { $0.path < $1.path }
    }

    /// A folder's subfolders, and whether it has a `.git` (and if so, whether it is a file).
    private static func list(_ path: String) -> (folders: [String], git: Bool?) {
        guard let directory = opendir(path) else { return ([], nil) }
        defer { closedir(directory) }
        var folders: [String] = []
        var git: Bool?
        while let entry = readdir(directory) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) { String(cString: $0) }
            }
            if name == "." || name == ".." { continue }
            var type = entry.pointee.d_type
            if type == DT_UNKNOWN {
                var info = stat()
                guard lstat((path as NSString).appendingPathComponent(name), &info) == 0 else { continue }
                type = (info.st_mode & S_IFMT) == S_IFDIR ? UInt8(DT_DIR) : (info.st_mode & S_IFMT) == S_IFREG ? UInt8(DT_REG) : UInt8(DT_LNK)
            }
            if name == ".git" {
                if type == DT_DIR { git = false } else if type == DT_REG { git = true }
                continue
            }
            if type == DT_DIR { folders.append(name) }
        }
        return (folders, git)
    }

    /// The working tree holding `path`: the nearest folder at or above it
    /// with a `.git` entry.
    static func enclosing(_ path: String) -> FoundRepository? {
        var folder = path
        while true {
            if let git = list(folder).git { return FoundRepository(path: folder, root: folder, gitFile: git) }
            let parent = (folder as NSString).deletingLastPathComponent
            if parent == folder || parent.isEmpty { return nil }
            folder = parent
        }
    }
}
