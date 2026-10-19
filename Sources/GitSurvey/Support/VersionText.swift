//
//  VersionText.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  `git version 2.39.5 (Apple Git-154)` → (2, 39).
//

import Foundation

enum VersionText {

    static func parse(_ output: String) -> (major: Int, minor: Int)? {
        guard let word = output.split(separator: " ").first(where: { $0.first?.isNumber == true }) else { return nil }
        let numbers = word.split(separator: ".").map { Int($0) }
        guard numbers.count >= 2, let major = numbers[0], let minor = numbers[1] else { return nil }
        return (major, minor)
    }

    /// Whether `version` is at least `major.minor`.
    static func atLeast(_ version: (major: Int, minor: Int), _ major: Int, _ minor: Int) -> Bool {
        version.major > major || (version.major == major && version.minor >= minor)
    }
}
