//
//  GitOperation.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// An operation git stopped in the middle of, waiting for someone to finish it.
public enum GitOperation: String, Codable, Sendable, CaseIterable {
    case rebase
    /// `git am`, applying mailed patches.
    case am
    case merge
    case cherryPick = "cherry-pick"
    case revert
    case bisect
}
