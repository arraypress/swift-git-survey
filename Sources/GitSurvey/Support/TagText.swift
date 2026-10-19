//
//  TagText.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  `git ls-remote --tags --refs` lines, `<hash>\trefs/tags/<name>`, → names.
//

import Foundation

enum TagText {

    static func names(_ output: String) -> Set<String> {
        Set(output.split(separator: "\n").compactMap { line in
            guard let tab = line.firstIndex(of: "\t") else { return nil }
            let ref = line[line.index(after: tab)...]
            return ref.hasPrefix("refs/tags/") ? String(ref.dropFirst("refs/tags/".count)) : nil
        })
    }
}
