//
//  TopK.swift
//
//
//  Created by Bernhard Eisvogel on 31.10.23.
//

import Foundation

public extension Collection {
    /// Helper function to sort distances and return the top K distances with their indices.
    ///
    /// The `by` parameter accepts a function of the following form:
    /// ```swift
    /// (Element, Element) throws -> Bool
    /// ```
    ///
    /// Adapted from [Stackoverflow](https://stackoverflow.com/questions/65746299/how-do-you-find-the-top-3-maximum-values-in-a-swift-dictionary)
    ///
    /// - Parameters:
    ///   - count:  the number of top distances to return.
    ///   - by: comparison function
    ///
    /// - Returns: ordered array containing the top K distances
    ///
    /// - Note: TopK and the standard swift implementations switch elements with equal value differently
    func topK(_ count: Int, by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows -> [Self.Element] {
        assert(count >= 0,
               """
               Cannot prefix with a negative amount of elements!
               """)

        guard count > 0 else {
            return []
        }

        let prefixCount = Swift.min(count, self.count)

        guard prefixCount < self.count / 10 else {
            return try Array(sorted(by: areInIncreasingOrder).prefix(prefixCount))
        }

        var result = try self.prefix(prefixCount).sorted(by: areInIncreasingOrder)

        for e in self.dropFirst(prefixCount) {
            if let last = result.last, try areInIncreasingOrder(last, e) {
                continue
            }
            let insertionIndex = try result.partition { try areInIncreasingOrder(e, $0) }
            let isLastElement = insertionIndex == result.endIndex
            result.removeLast()
            if isLastElement {
                result.append(e)
            } else {
                result.insert(e, at: insertionIndex)
            }
        }
        return result
    }
}
