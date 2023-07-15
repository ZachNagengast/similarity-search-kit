//
//  SimilarityIndex.swift
//
//
//  Created by Zach Nagengast on 4/10/23.
//

import Foundation

// MARK: - Type Aliases

public typealias IndexItem = SimilarityIndex.IndexItem
public typealias SearchResult = SimilarityIndex.SearchResult
public typealias EmbeddingModelType = SimilarityIndex.EmbeddingModelType
public typealias SimilarityMetricType = SimilarityIndex.SimilarityMetricType
public typealias TextSplitterType = SimilarityIndex.TextSplitterType
public typealias VectorStoreType = SimilarityIndex.VectorStoreType

@available(macOS 11.0, iOS 15.0, *)
public class SimilarityIndex {
    // MARK: - Properties

    /// The items stored in the index.
    public var indexItems: [IndexItem] = []

    /// The dimension of the embeddings in the index.
    /// Used to validate emebdding updates
    public private(set) var dimension: Int = 0

    /// The name of the index.
    public var indexName: String

    public let indexModel: any EmbeddingsProtocol
    public var indexMetric: any DistanceMetricProtocol
    public let vectorStore: any VectorStoreProtocol

    /// An object representing an item in the index.
    public struct IndexItem: Codable {
        /// The unique identifier of the item.
        public let id: String

        /// The text associated with the item.
        public var text: String

        /// The embedding vector of the item.
        public var embedding: [Float]

        /// A dictionary containing metadata for the item.
        public var metadata: [String: String]
    }

    /// An Identifiable object containing information about a search result.
    public struct SearchResult: Identifiable {
        /// The unique identifier of the associated index item
        public let id: String

        /// The similarity score between the query and the result.
        public let score: Float

        /// The text associated with the result.
        public let text: String

        /// A dictionary containing metadata for the result.
        public let metadata: [String: String]
    }

    /// An enumeration of available embedding models.
    public enum EmbeddingModelType {
        /// DistilBERT, a small version of BERT model fine tuned for questing-answering.
        case distilbert

        /// MiniLM All, a smaller but faster model.
        case minilmAll

        /// Multi-QA MiniLM, a fast model fine-tuned for question-answering tasks.
        case minilmMultiQA

        /// A native model provided by Apple's NaturalLanguage library.
        case native
    }

    public enum SimilarityMetricType {
        case dotproduct
        case cosine
        case euclidian
    }

    public enum TextSplitterType {
        case token
        case character
        case recursive
    }

    public enum VectorStoreType {
        case json
        // TODO:
        // case mlmodel
        // case protobuf
        // case sqlite
    }

    // MARK: - Initializers

    public init(name: String? = nil, model: (any EmbeddingsProtocol)? = nil, metric: (any DistanceMetricProtocol)? = nil, vectorStore: (any VectorStoreProtocol)? = nil) async {
        // Setup index with defaults
        self.indexName = name ?? "SimilaritySearchKitIndex"
        self.indexModel = model ?? NativeEmbeddings()
        self.indexMetric = metric ?? CosineSimilarity()
        self.vectorStore = vectorStore ?? JsonStore()

        // Run the model once to discover dimention size
        await setupDimension()
    }

    private func setupDimension() async {
        if let testVector = await indexModel.encode(sentence: "Test sentence") {
            dimension = testVector.count
        } else {
            fatalError("Failed to generate a test input vector.")
        }
    }

    // MARK: - Encoding

    public func getEmbedding(for text: String, embedding: [Float]? = nil) async -> [Float] {
        if let embedding = embedding, embedding.count == dimension {
            // Valid embedding, no encoding needed
            return embedding
        } else {
            // Encoding needed before adding to index
            guard let encoded = await indexModel.encode(sentence: text) else {
                print("Failed to encode text. \(text)")
                return Array(repeating: Float(0), count: dimension)
            }
            return encoded
        }
    }

    // MARK: - Search

    public func search(_ query: String, top resultCount: Int? = nil, metric: DistanceMetricProtocol? = nil) async -> [SearchResult] {
        let resultCount = resultCount ?? 5
        guard let queryEmbedding = await indexModel.encode(sentence: query) else {
            print("Failed to generate query embedding for '\(query)'.")
            return []
        }

        var indexIds: [String] = []
        var indexEmbeddings: [[Float]] = []

        indexItems.forEach { item in
            indexIds.append(item.id)
            indexEmbeddings.append(item.embedding)
        }

        // Calculate distances and find nearest neighbors
        if let customMetric = metric {
            // Allow custom metrics at time of query
            indexMetric = customMetric
        }
        let searchResults = indexMetric.findNearest(for: queryEmbedding, in: indexEmbeddings, resultsCount: resultCount)

        // Map results to index ids
        return searchResults.compactMap { result in
            let (score, index) = result
            let id = indexIds[index]

            if let item = getItem(id: id) {
                return SearchResult(id: item.id, score: score, text: item.text, metadata: item.metadata)
            } else {
                print("Failed to find item with id '\(id)' in indexItems.")
                return SearchResult(id: "000000", score: 0.0, text: "fail", metadata: [:])
            }
        }
    }

    public class func combinedResultsString(_ results: [SearchResult]) -> String {
        let combinedResults = results.map { result -> String in
            let metadataString = result.metadata.map { key, value in
                "\(key.uppercased()): \(value)"
            }.joined(separator: "\n")

            return "\(result.text)\n\(metadataString)"
        }.joined(separator: "\n\n")

        return combinedResults
    }

    public class func exportLLMPrompt(query: String, results: [SearchResult]) -> String {
        let sourcesText = combinedResultsString(results)
        let prompt =
            """
            Given the following extracted parts of a long document and a question, create a final answer with references ("SOURCES").
            If you don't know the answer, just say that you don't know. Don't try to make up an answer.
            ALWAYS return a "SOURCES" part in your answer.

            QUESTION: \(query)
            =========
            \(sourcesText)
            =========
            FINAL ANSWER:
            """
        return prompt
    }
}

// MARK: - CRUD

@available(macOS 11.0, iOS 15.0, *)
extension SimilarityIndex {
    // MARK: Create

    // Add an item with optional pre-computed embedding
    public func addItem(id: String, text: String, metadata: [String: String], embedding: [Float]? = nil) async {
        let embeddingResult = await getEmbedding(for: text, embedding: embedding)

        let item = IndexItem(id: id, text: text, embedding: embeddingResult, metadata: metadata)
        indexItems.append(item)
    }

    public func addItems(ids: [String], texts: [String], metadata: [[String: String]], embeddings: [[Float]?]? = nil, onProgress: ((String) -> Void)? = nil) async {
        // Check if all input arrays have the same length
        guard ids.count == texts.count, texts.count == metadata.count else {
            fatalError("Input arrays must have the same length.")
        }

        if let embeddings = embeddings, embeddings.count != ids.count {
            fatalError("Embeddings array length must be the same as ids array length. \(embeddings.count) vs \(ids.count)")
        }

        await withTaskGroup(of: Void.self) { taskGroup in
            for i in 0..<ids.count {
                let id = ids[i]
                let text = texts[i]
                let embedding = embeddings?[i]
                let meta = metadata[i]

                taskGroup.addTask(priority: .userInitiated) {
                    // Add the item using the addItem method
                    await self.addItem(id: id, text: text, metadata: meta, embedding: embedding)
                    onProgress?(id)
                }
            }
            await taskGroup.next()
        }
    }

    public func addItems(_ items: [IndexItem]) {
        Task {
            for item in items {
                await self.addItem(id: item.id, text: item.text, metadata: item.metadata, embedding: item.embedding)
            }
        }
    }

    // MARK: Read

    public func getItem(id: String) -> IndexItem? {
        return indexItems.first { $0.id == id }
    }

    public func sample(_ count: Int) -> [IndexItem]? {
        return Array(indexItems.prefix(upTo: count))
    }

    // MARK: Update

    public func updateItem(id: String, text: String? = nil, embedding: [Float]? = nil, metadata: [String: String]? = nil) {
        // Check if the provided embedding has the correct dimension
        if let embedding = embedding, embedding.count != dimension {
            fatalError("Dimension mismatch, expected \(dimension), saw \(embedding.count)")
        }

        // Find the item with the specified id
        if let index = indexItems.firstIndex(where: { $0.id == id }) {
            // Update the text if provided
            if let text = text {
                indexItems[index].text = text
            }

            // Update the embedding if provided
            if let embedding = embedding {
                indexItems[index].embedding = embedding
            }

            // Update the metadata if provided
            if let metadata = metadata {
                indexItems[index].metadata = metadata
            }
        }
    }

    // MARK: Delete

    public func removeItem(id: String) {
        indexItems.removeAll { $0.id == id }
    }

    public func removeAll() {
        indexItems.removeAll()
    }
}

// MARK: - Persistence

@available(macOS 13.0, iOS 16.0, *)
extension SimilarityIndex {
    public func saveIndex(toDirectory path: URL? = nil, name: String? = nil) throws -> URL {
        let indexName = name ?? self.indexName
        let basePath: URL

        if let specifiedPath = path {
            basePath = specifiedPath
        } else {
            // Default local path
            basePath = try getDefaultStoragePath()
        }

        let savedVectorStore = try vectorStore.saveIndex(items: indexItems, to: basePath, as: indexName)

        print("Saved \(indexItems.count) index items to \(savedVectorStore.absoluteString)")

        return savedVectorStore
    }

    public func loadIndex(fromDirectory path: URL? = nil, name: String? = nil) throws -> [IndexItem]? {
        let indexName = name ?? self.indexName
        let basePath: URL

        if let specifiedPath = path {
            basePath = specifiedPath
        } else {
            // Default local path
            basePath = try getDefaultStoragePath()
        }

        if let vectorStorePath = vectorStore.listIndexes(at: basePath).first(where: { $0.lastPathComponent.contains(indexName) }) {
            let loadedIndexItems = try vectorStore.loadIndex(from: vectorStorePath)
            addItems(loadedIndexItems)
            print("Loaded \(indexItems.count) index items from \(vectorStorePath.absoluteString)")
            return loadedIndexItems
        }

        return nil
    }

    private func getDefaultStoragePath() throws -> URL {
        let appName = Bundle.main.bundleIdentifier ?? "SimilaritySearchKit"
        let fileManager = FileManager.default
        let appSupportDirectory = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

        let appSpecificDirectory = appSupportDirectory.appendingPathComponent(appName)

        if !fileManager.fileExists(atPath: appSpecificDirectory.path) {
            try fileManager.createDirectory(at: appSpecificDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        return appSpecificDirectory
    }

    public func estimatedSizeInBytes() -> Int {
        var totalSize = 0

        for item in indexItems {
            // Calculate the size of 'id' property
            let idSize = item.id.utf8.count

            // Calculate the size of 'text' property
            let textSize = item.text.utf8.count

            // Calculate the size of 'embedding' property
            let floatSize = MemoryLayout<Float>.size
            let embeddingSize = item.embedding.count * floatSize

            // Calculate the size of 'metadata' property
            let metadataSize = item.metadata.reduce(0) { (size, keyValue) -> Int in
                let keySize = keyValue.key.utf8.count
                let valueSize = keyValue.value.utf8.count
                return size + keySize + valueSize
            }

            totalSize += idSize + textSize + embeddingSize + metadataSize
        }

        return totalSize
    }
}
