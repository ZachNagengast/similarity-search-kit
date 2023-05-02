//
//  MiniLMAllEmbeddings.swift
//
//
//  Created by Zach Nagengast on 4/20/23.
//

import Foundation
import CoreML
import SimilaritySearchKit

@available(macOS 12.0, iOS 15.0, *)
public class MiniLMEmbeddings: EmbeddingsProtocol {
    public let model: all_MiniLM_L6_v2
    public let tokenizer: BertTokenizer
    public let inputDimention: Int = 512
    public let outputDimention: Int = 384

    public init() {
        let modelConfig = MLModelConfiguration()
        modelConfig.computeUnits = .all

        do {
            self.model = try all_MiniLM_L6_v2(configuration: modelConfig)
        } catch {
            fatalError("Failed to load the Core ML model. Error: \(error.localizedDescription)")
        }

        self.tokenizer = BertTokenizer()
    }

    // MARK: - Dense Embeddings

    public func encode(sentence: String) async -> [Float]? {
        // Encode input text as bert tokens
        let inputTokens = tokenizer.buildModelTokens(sentence: sentence)
        let (inputIds, attentionMask) = tokenizer.buildModelInputs(from: inputTokens)

        // Send tokens through the MLModel
        let embeddings = generateEmbeddings(inputIds: inputIds, attentionMask: attentionMask)

        return embeddings
    }

    public func generateEmbeddings(inputIds: MLMultiArray, attentionMask: MLMultiArray) -> [Float]? {
        let inputFeatures = all_MiniLM_L6_v2Input(input_ids: inputIds, attention_mask: attentionMask)

        let output = try? model.prediction(input: inputFeatures)

        guard let embeddings = output?.embeddings else {
            return nil
        }

        let embeddingsArray: [Float] = (0..<embeddings.count).map { Float(embeddings[$0].floatValue) }

        return embeddingsArray
    }
}
