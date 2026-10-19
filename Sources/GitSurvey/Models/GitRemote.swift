//
//  GitRemote.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A configured remote.
public struct GitRemote: Codable, Sendable, Equatable {

    /// Its name, e.g. `origin`.
    public let name: String

    /// Its fetch URL as configured.
    public let url: String

    public init(name: String, url: String) {
        self.name = name
        self.url = url
    }
}
