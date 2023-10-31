//
//  File.swift
//  
//
//  Created by Bernhard Eisvogel on 31.10.23.
//

import Foundation

extension Collection {
  /// Adapted from https://stackoverflow.com/questions/65746299/how-do-you-find-the-top-3-maximum-values-in-a-swift-dictionary
    /// TopK and the standard swift implementations switch elements with equal value differently
  public func topK(_ count: Int, by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows -> [Self.Element] {
      assert(count >= 0,
             """
             Cannot prefix with a negative amount of elements!
             """)

    guard count > 0 else {
      return []
    }

    let prefixCount = Swift.min(count, self.count)

    guard prefixCount < (self.count / 10) else {
      return Array(try sorted(by: areInIncreasingOrder).prefix(prefixCount))
    }

    var result = try self.prefix(prefixCount).sorted(by: areInIncreasingOrder)

    for e in self.dropFirst(prefixCount) {
      if let last = result.last, try areInIncreasingOrder(last, e) {
        continue
      }
      let insertionIndex = try result.partition{ try areInIncreasingOrder(e, $0) }
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
