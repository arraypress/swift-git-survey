//
//  RemoteText.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  Reading `git config --get-regexp` for remote URLs and each branch's
//  remote, choosing which
//  remote to fetch, and recognising a github.com remote for gh.
//

import Foundation

enum RemoteText {

    /// The pattern for `git config --get-regexp`: remote URLs and branch remotes.
    static let configPattern = #"^(remote\..*\.url|branch\..*\.remote)$"#

    /// `git config -z --get-regexp` entries: `key\nvalue`, each ended by NUL.
    /// (Without -z, key and value are split by the first space, and a
    /// subsection may hold spaces.)
    static func entries(_ output: String) -> [(key: Substring, value: String)] {
        output.split(separator: "\0").compactMap { entry in
            guard let newline = entry.firstIndex(of: "\n") else { return (entry, "true") }
            return (entry[..<newline], String(entry[entry.index(after: newline)...]))
        }
    }

    /// `branch.main.remote` → `origin`, as branch → remote.
    static func branchRemotes(_ output: String) -> [String: String] {
        var map: [String: String] = [:]
        for (key, value) in entries(output) {
            guard key.hasPrefix("branch."), key.hasSuffix(".remote"), key.count > "branch..remote".count else { continue }
            map[String(key.dropFirst("branch.".count).dropLast(".remote".count))] = value
        }
        return map
    }

    /// `remote.origin.url` → `git@github.com:o/r.git`, as remotes in file
    /// order, the first URL of each. A remote's name may itself hold dots
    /// (`remote.my.fork.url`).
    static func parse(_ output: String) -> [GitRemote] {
        var remotes: [GitRemote] = []
        for (key, url) in entries(output) {
            guard key.hasPrefix("remote."), key.hasSuffix(".url"), key.count > "remote..url".count else { continue }
            let name = String(key.dropFirst("remote.".count).dropLast(".url".count))
            if !remotes.contains(where: { $0.name == name }) { remotes.append(GitRemote(name: name, url: url)) }
        }
        return remotes
    }

    /// The remote a fetch and the tag check use: the upstream's, else
    /// `origin`, else the first configured.
    static func primary(_ remotes: [GitRemote], upstream: String?) -> GitRemote? {
        if let upstream {
            // The longest name wins: with remotes "a" and "a/b", "a/b/main" is a/b's.
            if let match = remotes.filter({ upstream.hasPrefix($0.name + "/") }).max(by: { $0.name.count < $1.name.count }) {
                return match
            }
        }
        return remotes.first { $0.name == "origin" } ?? remotes.first
    }

    /// `owner/name` for a github.com URL in any of git's spellings; `nil` for
    /// anything else (another host, an ssh alias, a local path).
    static func gitHubSlug(_ url: String) -> String? {
        var rest: Substring
        if let range = url.range(of: "git@github.com:"), range.lowerBound == url.startIndex {
            rest = url[range.upperBound...]
        } else if let components = URLComponents(string: url), components.host?.lowercased() == "github.com",
                  ["https", "http", "ssh", "git"].contains(components.scheme?.lowercased() ?? "") {
            rest = Substring(components.path.drop { $0 == "/" })
        } else {
            return nil
        }
        if rest.hasSuffix("/") { rest = rest.dropLast() }
        if rest.hasSuffix(".git") { rest = rest.dropLast(4) }
        let parts = rest.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return "\(parts[0])/\(parts[1])"
    }
}
