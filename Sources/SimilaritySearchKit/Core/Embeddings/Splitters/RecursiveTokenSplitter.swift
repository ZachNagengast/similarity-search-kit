//
//  RecursiveTokenSplitter.swift
//
//
//  Created by Zach Nagengast on 4/26/23.
//

import Foundation

/// Uses a progressively smaller set of text seperators to try to fit the goal chunk size in tokens without going over.
/// Ideal if you need to maintain punctuation or unknown tokens from original text
/// because it doesn't decode the final text.
public class RecursiveTokenSplitter: TextSplitterProtocol {
    let tokenizer: any TokenizerProtocol

    public required init(withTokenizer: any TokenizerProtocol) {
        self.tokenizer = withTokenizer
    }

    public func split(text: String, chunkSize: Int = 510, overlapSize _: Int = 0) -> ([String], [[String]]?) {
        let separators = ["\n\n", "\n", ".", " ", ""]

        let chunkSize = min(chunkSize, 510) // Account for [CLS] and [SEP] tokens

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

                        // Check if the currentChunkSplit has more tokens than the total
                        let currentSplitTokens = tokenizer.tokenize(text: currentChunkSplit)
                        if currentSplitTokens.count > currentChunkTokens.count {
                            currentChunkTokens = currentSplitTokens
                            currentChunkSize = currentSplitTokens.count
                        }

                    } else {
                        chunks.append(currentChunkSplit.trimmingCharacters(in: .whitespaces))
                        chunkTokens.append(currentChunkTokens)

                        // reset current
                        currentChunkTokens = tokens
                        currentChunkSize = tokensSize
                        currentChunkSplit = splits[idx] + separator
                    }
                }

                // Add the last chunk if it's not empty
                if !currentChunkSplit.isEmpty {
                    chunks.append(currentChunkSplit.trimmingCharacters(in: .whitespaces))
                    chunkTokens.append(currentChunkTokens)
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
            let tokens = tokenizer.tokenize(text: chunk)
            if tokens.count > maxChunkSize {
                return (false, [])
            }
            splitTokens.append(tokens)
        }

        return (true, splitTokens)
    }
}
