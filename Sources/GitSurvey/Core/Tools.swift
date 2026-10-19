//
//  Tools.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  Finding git and gh, and the environment they run in. PATH is searched
//  first, then the usual install folders, because a process started by
//  launchd or an MCP host often has a PATH of /usr/bin:/bin alone.
//

import Foundation

enum Tools {

    private static let fallbackFolders = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]

    /// The first executable called `name` on PATH, then in the usual folders.
    static func locate(_ name: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        let path = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        for folder in path + fallbackFolders where !folder.isEmpty {
            let candidate = (folder as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    /// This process's environment with nothing able to ask a person anything:
    /// no terminal prompt for credentials, no askpass helper (an empty
    /// GIT_ASKPASS stops git falling back to core.askPass or SSH_ASKPASS), no
    /// credential-manager dialog, no ssh askpass; and no optional index locks,
    /// so `git status` never writes the index another process may be using.
    static let quietEnvironment: [String: String] = {
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_ASKPASS"] = ""
        environment["SSH_ASKPASS_REQUIRE"] = "never"
        environment["GCM_INTERACTIVE"] = "never"
        environment["GH_PROMPT_DISABLED"] = "1"
        environment["GH_NO_UPDATE_NOTIFIER"] = "1"
        environment["NO_COLOR"] = "1"
        environment["GIT_PAGER"] = "cat"
        environment["PAGER"] = "cat"
        return environment
    }()
}
