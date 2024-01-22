//
//  DistilbertEmbeddings.swift
//
//
//  Created by Zach Nagengast on 4/12/23.
//

import Foundation
import CoreML
import SimilaritySearchKit

@available(macOS 13.0, iOS 16.0, *)
public class DistilbertEmbeddings: EmbeddingsProtocol {
    public let model: msmarco_distilbert_base_tas_b_512_single_quantized
    public let tokenizer: BertTokenizer
    public let inputDimention: Int = 512
    public let outputDimention: Int = 768

    public init() {
        let modelConfig = MLModelConfiguration()
        modelConfig.computeUnits = .all

        do {
            self.model = try msmarco_distilbert_base_tas_b_512_single_quantized(configuration: modelConfig)
        } catch {
            fatalError("Failed to load the Core ML model. Error: \(error.localizedDescription)")
        }

        self.tokenizer = BertTokenizer()
    }

    // MARK: - Dense Embeddings

    public func encode(sentence: String) async -> [Float]? {
        // Encode input text as bert tokens
        let inputTokens = tokenizer.buildModelTokens(sentence: sentence)
        let (inputIds, _, attentionMask) = tokenizer.buildModelInputs(from: inputTokens)

        // Send tokens through the MLModel
        let embeddings = generateDistilbertEmbeddings(inputIds: inputIds, attentionMask: attentionMask)

        return embeddings
    }

    public func generateDistilbertEmbeddings(inputIds: MLMultiArray, attentionMask: MLMultiArray) -> [Float]? {
        let inputFeatures = msmarco_distilbert_base_tas_b_512_single_quantizedInput(
            input_ids: inputIds,
            attention_mask: attentionMask
        )

        let output = try? model.prediction(input: inputFeatures)

        guard let embeddings = output?.embeddings else {
            return nil
        }

        let embeddingsArray: [Float] = (0..<embeddings.count).map { Float(embeddings[$0].floatValue) }

        return embeddingsArray
    }
}
