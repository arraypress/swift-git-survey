//
//  SurveyReport.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The result of surveying one or more roots.
public struct SurveyReport: Codable, Sendable, Equatable {

    /// The folders searched, resolved.
    public let roots: [String]

    /// Every repository found, by path.
    public let repositories: [RepoStatus]

    /// Whether remotes were fetched first.
    public let fetched: Bool

    /// Whether GitHub releases were checked (false when asked but gh could not run).
    public let releasesChecked: Bool

    /// Seconds spent finding repositories.
    public let discoverySeconds: Double

    /// Seconds for the whole survey.
    public let seconds: Double

    /// Things worth knowing: a skipped release check, and why.
    public let notes: [String]

    public init(roots: [String], repositories: [RepoStatus], fetched: Bool, releasesChecked: Bool,
                discoverySeconds: Double, seconds: Double, notes: [String]) {
        self.roots = roots
        self.repositories = repositories
        self.fetched = fetched
        self.releasesChecked = releasesChecked
        self.discoverySeconds = discoverySeconds
        self.seconds = seconds
        self.notes = notes
    }
}
