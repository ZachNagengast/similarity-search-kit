//
//  RecursiveCharacterSplitter.swift
//
//  Created by Leszek Mielnikow on 03/07/2023.
//

import Foundation

public class RecursiveCharacterSplitter: TextSplitterProtocol {
    let characterSplitter: CharacterSplitter

    public init() {
        characterSplitter = CharacterSplitter()
    }

    public func split(text: String, chunkSize: Int = 100, overlapSize: Int = 0) -> ([String], [[String]]?) {
        let separators = ["\n\n", "\n", ".", " "]

        for separator in separators {
            let splits = text.components(separatedBy: separator)
            let (isValid, splitTokens) = isSplitValid(chunks: splits, maxChunkSize: chunkSize)

            if isValid {
                var chunks: [String] = []
                var chunkTokens: [[String]] = []

                var currentChunkTokens: [String] = []
                var currentChunkSize: Int = 0
                var currentChunkSplit: String = ""

                for (idx, tokens) in splitTokens.enumerated() {
                    let tokensSize = tokens.count

                    if currentChunkSize + tokensSize < chunkSize {
                        currentChunkTokens.append(contentsOf: tokens)
                        currentChunkSize += tokensSize
                        currentChunkSplit += splits[idx] + separator

                    } else {
                        chunks.append(currentChunkSplit.trimmingCharacters(in: .whitespaces))
                        chunkTokens.append(characterSplitter.split(text: currentChunkSplit, chunkSize: chunkSize).0)

                        // reset current
                        currentChunkTokens = tokens
                        currentChunkSize = tokensSize
                        currentChunkSplit = splits[idx] + separator
                    }
                }

                // Add the last chunk if it's not empty
                if !currentChunkSplit.isEmpty {
                    chunks.append(currentChunkSplit.trimmingCharacters(in: .whitespaces))
                    chunkTokens.append(characterSplitter.split(text: currentChunkSplit, chunkSize: chunkSize).0)
                }

                return (chunks, chunkTokens)
            }
        }

        return ([], [])
    }

    // MARK: - Helpers

    private func isSplitValid(chunks: [String], maxChunkSize: Int) -> (Bool, [[String]]) {
        var splitTokens: [[String]] = []

        for chunk in chunks {
            let tokens = characterSplitter.split(text: chunk, chunkSize: maxChunkSize).0
            if chunk.count > maxChunkSize {
                return (false, [])
            }
            splitTokens.append(tokens)
        }

        return (true, splitTokens)
    }
}
