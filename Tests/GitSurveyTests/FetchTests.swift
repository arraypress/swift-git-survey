//
//  FetchTests.swift
//  GitSurveyTests
//
//  Created by David Sherlock on 2026.
//
//  `fetch: true` against its own fixture: behind counts move only after a
//  fetch, the remote's tags are compared, a failing or hanging remote is
//  that repository's problem and nobody else's, and the fetch touches
//  nothing but remote-tracking refs — no local tag, no FETCH_HEAD.
//

import Foundation
import Testing
@testable import GitSurvey

@Suite(.serialized) struct FetchTests {

    @Test func fetchUpdatesBehindComparesTagsAndContainsFailures() async throws {
        let layout = try Fixture.fetch.get()

        // Offline: the remote's new commit is not known yet, nor its tags.
        let offline = try await surveyed(layout.root)
        let lagging = try #require(offline["lagging"])
        #expect(lagging.behind == 0 && lagging.fetch == nil)
        #expect(lagging.latestTag == TagState(name: "v1.0", commitsSince: 0, onRemote: nil))
        #expect(offline["unreachable"]?.problems == [.noUpstream], "offline, a dead remote is not noticed")

        let headBefore = try Fixture.git(["rev-parse", "HEAD"], in: layout.lagging)
        let indexBefore = Snapshot.take((layout.lagging as NSString).appendingPathComponent(".git")).filter { $0.key == "index" }

        let started = Date()
        let fetched = try await surveyed(layout.root, SurveyOptions(fetch: true, fetchTimeout: 2))
        let seconds = Date().timeIntervalSince(started)

        let after = try #require(fetched["lagging"])
        #expect(after.fetch == FetchOutcome(remote: "origin", succeeded: true, error: nil))
        #expect(after.behind == 1)
        #expect(after.latestTag == TagState(name: "v1.0", commitsSince: 0, onRemote: true))
        #expect(after.problems == [.behind])

        let taggedHere = try #require(fetched["tagged-here"])
        #expect(taggedHere.latestTag == TagState(name: "v1.1", commitsSince: 0, onRemote: false))
        #expect(taggedHere.problems == [.unpushedTag])

        let unreachable = try #require(fetched["unreachable"])
        #expect(unreachable.fetch?.succeeded == false && unreachable.fetch?.remote == "origin")
        let reason = unreachable.fetch?.error ?? ""
        #expect(!reason.isEmpty)
        #expect(unreachable.problems == [.noUpstream, .fetchFailed])

        // The hanging remote is stopped at its timeout, ssh stand-in and all.
        let hanging = try #require(fetched["hanging"])
        #expect(hanging.fetch?.error == "git fetch timed out after 2 s")
        #expect(hanging.problems.contains(.fetchFailed))
        #expect(seconds < 15, "the whole run took \(seconds) s")

        // Only remote-tracking refs moved.
        #expect(try Fixture.git(["rev-parse", "HEAD"], in: layout.lagging) == headBefore)
        #expect(try Fixture.git(["tag", "-l"], in: layout.lagging) == "v1.0\n", "no tag was fetched")
        #expect(!FileManager.default.fileExists(atPath: (layout.lagging as NSString).appendingPathComponent(".git/FETCH_HEAD")))
        #expect(Snapshot.take((layout.lagging as NSString).appendingPathComponent(".git")).filter { $0.key == "index" } == indexBefore)
    }
}
