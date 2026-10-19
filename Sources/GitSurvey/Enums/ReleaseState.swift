//
//  ReleaseState.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What GitHub has for a tag.
public enum ReleaseState: String, Codable, Sendable, CaseIterable {
    /// A published release with at least one asset.
    case published
    /// A published release with no assets.
    case noAssets = "no_assets"
    /// A draft release: not visible to anyone else yet.
    case draft
    /// No release for the tag.
    case missing
    /// gh could not answer (timed out, no access, no such repository).
    case unknown
}
