//
//  Array+ConcurrentMap.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  A map that runs at most `limit` transforms at once and keeps the order.
//

import Foundation

extension Array where Element: Sendable {

    func concurrentMap<T: Sendable>(limit: Int, _ transform: @escaping @Sendable (Element) async -> T) async -> [T] {
        await withTaskGroup(of: (Int, T).self) { group in
            var results = [T?](repeating: nil, count: count)
            var next = 0
            func add() {
                let index = next, element = self[index]
                group.addTask { (index, await transform(element)) }
                next += 1
            }
            while next < Swift.min(limit, count) { add() }
            for await (index, value) in group {
                results[index] = value
                if next < count { add() }
            }
            return results.map { $0! }
        }
    }
}
