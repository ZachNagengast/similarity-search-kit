//
//  MiniLMAllEmbeddings.swift
//
//
//  Created by Zach Nagengast on 4/20/23.
//

import CoreML
import Foundation
import SimilaritySearchKit

@available(macOS 12.0, iOS 15.0, *)
public class BGEEmbeddings: EmbeddingsProtocol {
  public let model: BGE_small
  public let tokenizer: BertTokenizer
  public let inputDimention: Int = 512
  public let outputDimention: Int = 384

  public init(tokenizer: BertTokenizer? = nil) {
    let modelConfig = MLModelConfiguration()
    modelConfig.computeUnits = .all
      print("INIT BGE", tokenizer == nil ? "NO TOKENIZER" : "tokenizer provided")
    do {
      self.model = try BGE_small(configuration: modelConfig)
        print("INIT BGE MODEL LOADED")

    } catch {
      fatalError("Failed to load the Core ML model. Error: \(error.localizedDescription)")
    }
      print("INIT BGE Tokenizer adding")

    self.tokenizer = tokenizer ?? BertTokenizer()
  }

  // MARK: - Dense Embeddings

  public func encode(sentence: String) async -> [Float]? {
    // Encode input text as bert tokens
    let inputTokens = Array(tokenizer.buildModelTokens(sentence: sentence))
    let (inputIds, attentionMask) = tokenizer.buildModelInputs(from: inputTokens)

    // Send tokens through the MLModel
    //      print(inputIds.count, inputIds[0])
    //      print(inputIds, attentionMask)
    let embeddings = generateEmbeddings(inputIds: inputIds, attentionMask: attentionMask)

    return embeddings
  }

  public func generateEmbeddings(inputIds: MLMultiArray, attentionMask: MLMultiArray) -> [Float]? {
    let inputFeatures = BGE_smallInput(input_ids: inputIds, attention_mask_1: attentionMask)
    //      print(inputFeatures)
    let output = try? model.prediction(input: inputFeatures)

    guard let embeddings = output?.var_1059 else {
      print("failed")
      print(output)
      return nil
    }
    //      print("EMBEDDINGS")
    //      print(embeddings)
    let embeddingsArray: [Float] = (0..<embeddings.count).map { Float(embeddings[$0].floatValue) }
    //      print(embeddingsArray)
    return embeddingsArray
  }
}
