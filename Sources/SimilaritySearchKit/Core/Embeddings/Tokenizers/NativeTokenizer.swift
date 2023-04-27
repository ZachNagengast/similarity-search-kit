//
//  NativeTokenizer.swift
//
//
//  Created by Zach Nagengast on 4/26/23.
//

import Foundation
import NaturalLanguage
import CoreML

public class NativeTokenizer: TokenizerProtocol {
    public init() {}

    public func tokenize(text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        let tokenRanges = tokenizer.tokens(for: text.startIndex..<text.endIndex).map { text[$0] }
        let tokens = tokenRanges.map { String($0) }
        return tokens
    }

    public func detokenize(tokens: [String]) -> String {
        return tokens.joined(separator: " ")
    }
}
