//
//  SurveyOptions.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How to search and what to ask.
public struct SurveyOptions: Sendable, Equatable {

    /// Look inside repositories for nested ones (submodules, vendored clones).
    public var nested: Bool

    /// The roots are home folders: also skip `~/Library`, `~/Applications`,
    /// the media folders and cloud-storage folders at their top level.
    public var home: Bool

    /// `git fetch` each repository's remote first, and ask it which tags it has.
    public var fetch: Bool

    /// Seconds each repository's fetch may take.
    public var fetchTimeout: Double

    /// Ask GitHub, through `gh`, whether the latest tag has a release with an asset.
    public var releases: Bool

    /// Seconds each `gh` call may take.
    public var releaseTimeout: Double

    /// Seconds each local git call may take.
    public var gitTimeout: Double

    /// Repositories inspected at once; `nil` for ``defaultJobs``, or
    /// ``defaultFetchJobs`` with a fetch.
    public var jobs: Int?

    public init(nested: Bool = false, home: Bool = false, fetch: Bool = false, fetchTimeout: Double = 30,
                releases: Bool = false, releaseTimeout: Double = 20, gitTimeout: Double = 30,
                jobs: Int? = nil) {
        self.nested = nested
        self.home = home
        self.fetch = fetch
        self.fetchTimeout = fetchTimeout
        self.releases = releases
        self.releaseTimeout = releaseTimeout
        self.gitTimeout = gitTimeout
        self.jobs = jobs
    }

    /// One repository per core, between 4 and 16: local git is bound by
    /// process start-up, and more at once gained nothing on 523 repositories.
    public static var defaultJobs: Int { min(16, max(4, ProcessInfo.processInfo.activeProcessorCount)) }

    /// With a fetch: each repository waits on its remote, not the CPU, so
    /// more run at once. Measured on 523 GitHub repositories over ssh:
    /// 104 s at 14, 47 s at 32, 24 s at 64.
    public static let defaultFetchJobs = 32

    /// The concurrency this survey uses.
    public var effectiveJobs: Int { max(1, jobs ?? (fetch ? Self.defaultFetchJobs : Self.defaultJobs)) }
}
