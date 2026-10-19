//
//  ReleaseCheck.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What GitHub has for the latest tag, from `gh release view`.
public struct ReleaseCheck: Codable, Sendable, Equatable {

    /// `owner/name` on github.com.
    public let repository: String

    /// The tag asked about.
    public let tag: String

    /// What GitHub said.
    public let state: ReleaseState

    /// How many assets the release carries; `nil` without a release.
    public let assets: Int?

    /// The release page.
    public let url: String?

    /// Why the state is ``ReleaseState/unknown``.
    public let error: String?

    public init(repository: String, tag: String, state: ReleaseState, assets: Int?, url: String?, error: String?) {
        self.repository = repository
        self.tag = tag
        self.state = state
        self.assets = assets
        self.url = url
        self.error = error
    }
}
