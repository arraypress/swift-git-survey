//
//  BranchLead.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A local branch, other than the current one, with commits its upstream lacks.
public struct BranchLead: Codable, Sendable, Equatable {

    /// The branch. Authored text.
    public let branch: String

    /// Commits ahead of its upstream.
    public let ahead: Int

    public init(branch: String, ahead: Int) {
        self.branch = branch
        self.ahead = ahead
    }
}
