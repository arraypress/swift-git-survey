//
//  ReleaseJSON.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  Reading `gh release view <tag> --json tagName,isDraft,assets,url`, and
//  telling "no such release" apart from gh failing.
//

import Foundation

enum ReleaseJSON {

    static func check(repository: String, tag: String, result: ChildResult, timeout: Double) -> ReleaseCheck {
        if result.timedOut {
            return ReleaseCheck(repository: repository, tag: tag, state: .unknown, assets: nil, url: nil,
                                error: "gh timed out after \(Int(timeout)) s")
        }
        guard result.status == 0 else {
            let reason = result.reason
            // gh's words for a tag without a release; a missing repository is
            // "Could not resolve to a Repository", which is not ours to call missing.
            if reason.lowercased().contains("release not found") {
                return ReleaseCheck(repository: repository, tag: tag, state: .missing, assets: nil, url: nil, error: nil)
            }
            return ReleaseCheck(repository: repository, tag: tag, state: .unknown, assets: nil, url: nil,
                                error: reason.isEmpty ? "gh exited \(result.status)" : reason)
        }
        guard let object = try? JSONSerialization.jsonObject(with: result.stdout) as? [String: Any] else {
            return ReleaseCheck(repository: repository, tag: tag, state: .unknown, assets: nil, url: nil,
                                error: "gh's answer was not JSON")
        }
        let assets = (object["assets"] as? [Any])?.count ?? 0
        let draft = object["isDraft"] as? Bool ?? false
        let state: ReleaseState = draft ? .draft : assets > 0 ? .published : .noAssets
        return ReleaseCheck(repository: repository, tag: tag, state: state, assets: assets,
                            url: object["url"] as? String, error: nil)
    }
}
