//
//  TokenSplitter.swift
//
//
//  Created by Zach Nagengast on 4/25/23.
//

import Foundation

/// Encodes input text and return chunks based on chunk size
/// Ideal for speed if you don't mind losing some information to unknown tokens
/// during the encode/decode process
public class TokenSplitter: TextSplitterProtocol {
    let tokenizer: any TokenizerProtocol

    public required init(withTokenizer: any TokenizerProtocol) {
        self.tokenizer = withTokenizer
    }

    public func split(text: String, chunkSize: Int = 510, overlapSize _: Int = 0) -> ([String], [[String]]?) {
        // Return an empty list if the text is empty or whitespace
        if text.isEmpty || text.trimmingCharacters(in: .whitespaces).isEmpty {
            return ([], [])
        }

        let chunkSize = min(chunkSize, 510)

        // Tokenize the text
        let tokens = tokenizer.tokenize(text: text)

        // Initialize an empty list of chunks
        var chunks: [String] = []
        var chunkTokens: [[String]] = []

        // Initialize a counter for the number of chunks
        var numChunks = 0

        // Create a variable to store the remaining tokens
        var remainingTokens = tokens

        // Loop until all tokens are consumed
        while !remainingTokens.isEmpty {
            // Take the first chunkSize tokens as a chunk
            let chunk = Array(remainingTokens.prefix(chunkSize))

            // Decode the chunk into text
            let chunkText = tokenizer.detokenize(tokens: chunk)

            // Skip the chunk if it is empty or whitespace
            if chunkText.isEmpty || chunkText.trimmingCharacters(in: .whitespaces).isEmpty {
                // Remove the tokens corresponding to the chunk text from the remaining tokens
                remainingTokens.removeFirst(chunk.count)
                // Continue to the next iteration of the loop
                continue
            }

            // Find the last period or punctuation mark in the chunk
            let punctuationMarks: [Character] = [".", "?", "!", "\n"]
            let lastPunctuation = punctuationMarks.compactMap { chunkText.lastIndex(of: $0)?.utf16Offset(in: chunkText) }.max() ?? -1

            var chunkTextToAppend = chunkText

            // If there is a punctuation mark
            if lastPunctuation != -1 {
                // Ensure the index is within the chunkText bounds
                let safeIndex = min(chunkText.count - 1, lastPunctuation + 1)
                // Truncate the chunk text at the punctuation mark
                chunkTextToAppend = String(chunkText[..<chunkText.index(chunkText.startIndex, offsetBy: safeIndex)])
            }

            // Remove any newline characters and strip any leading or trailing whitespace
            chunkTextToAppend = chunkTextToAppend.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)

            // Append the chunk text to the list of chunks
            chunks.append(chunkTextToAppend)
            chunkTokens.append(chunk)

            // Remove the tokens corresponding to the chunk text from the remaining tokens
            remainingTokens.removeFirst(tokenizer.tokenize(text: chunkTextToAppend).count)

            // Increment the number of chunks
            numChunks += 1
        }

        // Handle the remaining tokens
        if !remainingTokens.isEmpty {
            let remainingText = tokenizer.detokenize(tokens: remainingTokens).replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)

            chunks.append(remainingText)
            chunkTokens.append(remainingTokens)
        }

        return (chunks, chunkTokens)
    }
}
