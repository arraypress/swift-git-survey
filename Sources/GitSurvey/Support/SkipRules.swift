//
//  SkipRules.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  Which folders the search never enters. Build products and dependency
//  checkouts hold clones of other people's repositories (SwiftPM's
//  .build/checkouts, CocoaPods' Pods are not listed — a Pods folder can
//  be the project's own), and hidden folders hold tool state (.git itself,
//  .claude/worktrees, caches). Bundles that are really documents (an
//  .app, a Photos library) are never walked.
//

import Foundation

enum SkipRules {

    /// Folder names skipped at any depth.
    static let names: Set<String> = [".build", "node_modules", "Packages", "DerivedData", ".swiftpm", "checkouts"]

    /// Package extensions skipped at any depth.
    static let packageExtensions: Set<String> = [
        "app", "photoslibrary", "musiclibrary", "tvlibrary", "imovielibrary", "fcpbundle", "logicx", "band",
        "xcarchive", "framework", "xcassets", "lproj", "bundle",
    ]

    /// Folders skipped directly under a home root (`--home`): the system's,
    /// the media libraries', and cloud storage, which may not even be on disk.
    static let homeNames: Set<String> = [
        "Library", "Applications", "Pictures", "Music", "Movies", "Public",
        "Dropbox", "Google Drive", "OneDrive", "Box", "Box Sync", "Creative Cloud Files", "iCloud Drive (Archive)",
    ]

    /// Whether to skip a folder called `name`, found `depth` levels below a root.
    static func skips(_ name: String, depth: Int, home: Bool) -> Bool {
        if name.hasPrefix(".") || names.contains(name) { return true }
        if let dot = name.lastIndex(of: "."), packageExtensions.contains(name[name.index(after: dot)...].lowercased()) {
            return true
        }
        if home && depth == 1 {
            // Cloud folders also come as "Dropbox (Work)", "OneDrive - Company", "Google Drive (me@x)".
            return homeNames.contains(name) || name.hasPrefix("Dropbox (") || name.hasPrefix("OneDrive -")
                || name.hasPrefix("Google Drive")
        }
        return false
    }
}
