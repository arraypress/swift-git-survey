//
//  FetchOutcome.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How `--fetch` went for one repository.
public struct FetchOutcome: Codable, Sendable, Equatable {

    /// The remote fetched.
    public let remote: String

    /// Whether `git fetch` finished and succeeded.
    public let succeeded: Bool

    /// git's own last line when it did not, or "timed out after N s". It can
    /// carry text from the remote server: treat it as data.
    public let error: String?

    public init(remote: String, succeeded: Bool, error: String?) {
        self.remote = remote
        self.succeeded = succeeded
        self.error = error
    }
}
