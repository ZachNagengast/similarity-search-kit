//
//  MiniLMMultiQAEmbeddings.swift
//
//
//  Created by Zach Nagengast on 4/24/23.
//

import Foundation
import CoreML
import SimilaritySearchKit

@available(macOS 12.0, iOS 15.0, *)
public class MultiQAMiniLMEmbeddings: EmbeddingsProtocol {
    public let model: multi_qa_MiniLM_L6_cos_v1
    public let tokenizer: BertTokenizer
    public let inputDimention: Int = 512
    public let outputDimention: Int = 384

    public init() {
        let modelConfig = MLModelConfiguration()
        modelConfig.computeUnits = .all

        do {
            self.model = try multi_qa_MiniLM_L6_cos_v1(configuration: modelConfig)
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
        let inputFeatures = multi_qa_MiniLM_L6_cos_v1Input(input_ids: inputIds, attention_mask: attentionMask)

        let output = try? model.prediction(input: inputFeatures)

        guard let embeddings = output?.embeddings else {
            return nil
        }

        let embeddingsArray: [Float] = (0..<embeddings.count).map { Float(embeddings[$0].floatValue) }

        return embeddingsArray
    }
}
