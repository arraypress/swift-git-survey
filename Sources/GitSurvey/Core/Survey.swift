//
//  Survey.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  The entry point: find the working trees under some folders and ask git
//  about each, a bounded number at a time. Nothing here writes to a
//  repository; with `fetch` on, `git fetch` updates remote-tracking refs and
//  objects only (no tags, no FETCH_HEAD, no maintenance, no submodules).
//

import Foundation

/// Surveys git working trees.
///
/// ```swift
/// let report = try await Survey.run(roots: ["/Users/me/code"])
/// report.repositories.filter(\.needsAttention)
/// let here = try await Survey.inspect(path: FileManager.default.currentDirectoryPath)
/// here.repositories[0].problems        // [.dirty, .ahead]
/// ```
public enum Survey {

    /// Every working tree under `roots`, without asking git anything.
    ///
    /// - Throws: ``GitSurveyError/noSuchRoot(_:)`` for a root that is not a folder.
    public static func discover(roots: [String], options: SurveyOptions = SurveyOptions()) throws -> [FoundRepository] {
        Discovery.find(roots: try resolve(roots), nested: options.nested, home: options.home)
    }

    /// Finds and inspects every working tree under `roots`.
    ///
    /// A repository that cannot be read comes back with ``RepoStatus/error``
    /// set rather than failing the survey; a fetch that fails or times out is
    /// that repository's ``RepoStatus/fetch``.
    ///
    /// - Throws: ``GitSurveyError/noSuchRoot(_:)``, ``GitSurveyError/gitNotFound``,
    ///   ``GitSurveyError/gitTooOld(_:)``.
    public static func run(roots: [String], options: SurveyOptions = SurveyOptions()) async throws -> SurveyReport {
        let started = Date()
        let resolved = try resolve(roots)
        let git = try await Git.locate()
        let found = Discovery.find(roots: resolved, nested: options.nested, home: options.home)
        let discovered = Date()
        var repositories = await found.concurrentMap(limit: options.effectiveJobs) { repository in
            await Inspector.inspect(repository, git: git, options: options)
        }
        var notes: [String] = []
        var releasesChecked = false
        if options.releases {
            (repositories, releasesChecked, notes) = await checkReleases(repositories, options: options)
        }
        return SurveyReport(roots: resolved, repositories: repositories, fetched: options.fetch,
                            releasesChecked: releasesChecked,
                            discoverySeconds: discovered.timeIntervalSince(started),
                            seconds: Date().timeIntervalSince(started), notes: notes)
    }

    /// Inspects the working tree holding `path` (any folder inside it): a
    /// report of one, whose root is that working tree.
    ///
    /// - Throws: ``GitSurveyError/notARepository(_:)`` outside a working tree.
    public static func inspect(path: String, options: SurveyOptions = SurveyOptions()) async throws -> SurveyReport {
        let started = Date()
        guard let folder = try resolve([path]).first, let found = Discovery.enclosing(folder) else {
            throw GitSurveyError.notARepository(path)
        }
        let git = try await Git.locate()
        var repositories = [await Inspector.inspect(found, git: git, options: options)]
        var notes: [String] = []
        var releasesChecked = false
        if options.releases {
            (repositories, releasesChecked, notes) = await checkReleases(repositories, options: options)
        }
        return SurveyReport(roots: [found.path], repositories: repositories, fetched: options.fetch,
                            releasesChecked: releasesChecked, discoverySeconds: 0,
                            seconds: Date().timeIntervalSince(started), notes: notes)
    }

    /// Absolute, symlink-free folders; each must exist.
    static func resolve(_ roots: [String]) throws -> [String] {
        var resolved: [String] = []
        for root in roots {
            let expanded = (root as NSString).expandingTildeInPath
            let absolute = expanded.hasPrefix("/") ? expanded
                : (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent(expanded)
            var isFolder: ObjCBool = false
            guard FileManager.default.fileExists(atPath: absolute, isDirectory: &isFolder), isFolder.boolValue,
                  let real = realpath(absolute, nil) else { throw GitSurveyError.noSuchRoot(root) }
            let path = String(cString: real)
            free(real)
            if !resolved.contains(path) { resolved.append(path) }
        }
        return resolved
    }

    private static func checkReleases(_ repositories: [RepoStatus], options: SurveyOptions) async
        -> (repositories: [RepoStatus], checked: Bool, notes: [String]) {
        let gh = await Releases.gh(timeout: options.releaseTimeout)
        guard let executable = gh.executable else { return (repositories, false, gh.note.map { [$0] } ?? []) }
        let checked = await repositories.concurrentMap(limit: min(options.effectiveJobs, 8)) { status in
            guard status.error == nil,
                  let check = await Releases.check(status, gh: executable, timeout: options.releaseTimeout) else { return status }
            return status.with(release: check)
        }
        return (checked, true, [])
    }
}
