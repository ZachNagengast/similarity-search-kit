//
//  CharacterSplitter.swift
//
//
//  Created by Zach Nagengast on 4/25/23.
//

import Foundation

public class CharacterSplitter: TextSplitterProtocol {
    let separator: String

    public init(withSeparator separator: String? = nil) {
        // Default separator is character breaks
        self.separator = separator ?? ""
    }

    // Split chunks based on seperator, append until the chunk size is reached
    public func split(text: String, chunkSize: Int = 100, overlapSize: Int = 0) -> ([String], [[String]]?) {
        let components = text.components(separatedBy: separator)
        var chunks: [String] = []
        var currentChunk: [String] = []
        var currentCount = 0

        for component in components {
            if currentCount < chunkSize {
                currentChunk.append(component)
                currentCount += 1
            } else {
                chunks.append(currentChunk.joined(separator: separator).trimmingCharacters(in: .whitespaces))
                let overlapStart = max(0, currentChunk.count - overlapSize)
                currentChunk = Array(currentChunk[overlapStart...])
                currentCount = currentChunk.count
                currentChunk.append(component)
                currentCount += 1
            }
        }

        // Add the last chunk
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: separator).trimmingCharacters(in: .whitespaces))
        }

        return (chunks, nil)
    }
}
