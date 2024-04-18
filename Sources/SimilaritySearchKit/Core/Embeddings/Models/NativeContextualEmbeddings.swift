//
//  NativeContextualEmbeddings.swift
//  
//
//  Created by Zach Nagengast on 10/11/23.
//

import Foundation
import NaturalLanguage
import CoreML

#if canImport(NaturalLanguage.NLContextualEmbedding)
@available(macOS 14.0, iOS 17.0, *)
public class NativeContextualEmbeddings: EmbeddingsProtocol {
    public let model: ModelActor
    public let tokenizer: any TokenizerProtocol

    // Initialize with a language
    public init(language: NLLanguage = .english) {
        self.tokenizer = NativeTokenizer()
        guard let nativeModel = NLContextualEmbedding(language: language) else {
            fatalError("Failed to load the Core ML model.")
        }
        Self.initializeModel(nativeModel)
        self.model = ModelActor(model: nativeModel)
    }

    // Initialize with a script
    public init(script: NLScript) {
        self.tokenizer = NativeTokenizer()
        guard let nativeModel = NLContextualEmbedding(script: script) else {
            fatalError("Failed to load the Core ML model.")
        }
        Self.initializeModel(nativeModel)
        self.model = ModelActor(model: nativeModel)
    }

    // Common model initialization logic
    private static func initializeModel(_ nativeModel: NLContextualEmbedding) {
        if !nativeModel.hasAvailableAssets {
            nativeModel.requestAssets { result, error in
                guard result == .available else {
                    return
                }

                try? nativeModel.load()
            }
        } else {
            try? nativeModel.load()
        }
    }

    // MARK: - Dense Embeddings

    public actor ModelActor {
        private let model: NLContextualEmbedding

        init(model: NLContextualEmbedding) {
            self.model = model
        }

        func vector(for sentence: String) -> [Float]? {
            // Obtain embedding result for the given sentence
            // Shape is [1, embedding.sequenceLength, model.dimension]
            let embedding = try! model.embeddingResult(for: sentence, language: nil)

            // Initialize an array to store the total embedding values and set the count
            var meanPooledEmbeddings: [Float] = Array(repeating: 0.0, count: model.dimension)
            let sequenceLength = embedding.sequenceLength

            // Mean pooling: Loop through each token vector in the embedding and sum the values
            embedding.enumerateTokenVectors(in: sentence.startIndex ..< sentence.endIndex) { (embedding, _) -> Bool in
                for tokenEmbeddingIndex in 0 ..< embedding.count {
                    meanPooledEmbeddings[tokenEmbeddingIndex] += Float(embedding[tokenEmbeddingIndex])
                }
                return true
            }

            // Mean pooling: Get the average embedding from totals
            if sequenceLength > 0 {
                for index in 0 ..< sequenceLength {
                    meanPooledEmbeddings[index] /= Float(sequenceLength)
                }
            }

            // Return the mean-pooled vector
            return meanPooledEmbeddings
        }
    }

    public func encode(sentence: String) async -> [Float]? {
        return await model.vector(for: sentence)
    }
}
#endif

