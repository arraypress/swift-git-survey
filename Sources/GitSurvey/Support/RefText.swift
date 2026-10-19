//
//  RefText.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  Reading `git for-each-ref refs/heads refs/remotes` in the format below,
//  and deciding which other branches hold work no remote has.
//

import Foundation

enum RefText {

    /// The format; `%(ahead-behind:HEAD)` is added on git 2.41 and later.
    static func format(aheadBehind: Bool) -> String {
        "%(refname)%00%(upstream)%00%(upstream:track,nobracket)" + (aheadBehind ? "%00%(ahead-behind:HEAD)" : "")
    }

    static func parse(_ output: String) -> RefSnapshot {
        var snapshot = RefSnapshot()
        for line in output.split(separator: "\n") {
            let fields = line.split(separator: "\0", omittingEmptySubsequences: false).map(String.init)
            guard let ref = fields.first else { continue }
            if ref.hasPrefix("refs/remotes/") {
                let name = String(ref.dropFirst("refs/remotes/".count))
                if !name.hasSuffix("/HEAD") { snapshot.remoteTracking.insert(name) }
            } else if ref.hasPrefix("refs/heads/") {
                let upstream = fields.count > 1 && !fields[1].isEmpty ? fields[1] : nil
                let track = fields.count > 2 ? fields[2] : ""
                let aheadOfHead = fields.count > 3 ? fields[3].split(separator: " ").first.flatMap { Int($0) } : nil
                snapshot.local.append(LocalBranch(name: String(ref.dropFirst("refs/heads/".count)),
                                                  upstream: upstream, ahead: count("ahead", in: track),
                                                  gone: track == "gone", aheadOfHead: aheadOfHead))
            }
        }
        return snapshot
    }

    /// `ahead 2, behind 1` → 2 for "ahead".
    static func count(_ word: String, in track: String) -> Int {
        for part in track.split(separator: ",") {
            let pieces = part.split(separator: " ")
            if pieces.count == 2, pieces[0] == word, let value = Int(pieces[1]) { return value }
        }
        return 0
    }

    /// Other branches with no counterpart on any remote: no upstream (or a
    /// gone one) and no remote-tracking branch of the same name — and, when
    /// git can say, at least one commit HEAD lacks (a merged branch holds
    /// nothing that would be lost).
    static func localOnly(_ refs: RefSnapshot, current: String?) -> [String] {
        let remoteNames = Set(refs.remoteTracking.compactMap { name in
            name.firstIndex(of: "/").map { String(name[name.index(after: $0)...]) }
        })
        return refs.local.filter { branch in
            branch.name != current
                && (branch.upstream == nil || branch.gone)
                && !remoteNames.contains(branch.name)
                && (branch.aheadOfHead ?? 1) > 0
        }.map(\.name).sorted()
    }

    /// Other branches ahead of an upstream that still exists.
    static func unpushed(_ refs: RefSnapshot, current: String?) -> [BranchLead] {
        refs.local.filter { $0.name != current && $0.upstream != nil && !$0.gone && $0.ahead > 0 }
            .map { BranchLead(branch: $0.name, ahead: $0.ahead) }
            .sorted { $0.branch < $1.branch }
    }
}
