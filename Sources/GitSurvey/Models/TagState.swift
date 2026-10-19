//
//  TagState.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The nearest tag reachable from HEAD, and how far HEAD has moved past it.
public struct TagState: Codable, Sendable, Equatable {

    /// The tag's name. Authored text.
    public let name: String

    /// Commits on HEAD since the tag; 0 when HEAD is the tagged commit.
    public let commitsSince: Int

    /// Whether the remote has a tag of that name: `nil` when unknown — always
    /// so without a fetch, since only the remote can say.
    public let onRemote: Bool?

    public init(name: String, commitsSince: Int, onRemote: Bool?) {
        self.name = name
        self.commitsSince = commitsSince
        self.onRemote = onRemote
    }
}
