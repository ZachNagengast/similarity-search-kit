# SimilaritySearchKit

![ssk-logo](https://user-images.githubusercontent.com/1981179/234468591-cda2871d-cb29-4b3e-bef4-77e0702123e1.png)

**SimilaritySearchKit** is a Swift package providing *local-first* text embeddings and semantic search functionality for iOS and macOS applications. Emphasizing speed, flexibility, and privacy, it supports a variety of built-in distance metrics and metal-accelerated machine learning models, in addition to seamless integration with bring-your-own options.

<details>
<summary>Chat with Files Example Video</summary>
<img src="https://user-images.githubusercontent.com/1981179/234986127-8fa5daac-d041-4f1e-b7e5-175ff49271bb.gif">
</details>

<details>
<summary>iOS Basic Example Video</summary>
<img src="https://user-images.githubusercontent.com/1981179/234986166-e48a543b-2d11-4a78-9fc8-d348c3d436b4.gif">
</details>

## Motivation

This project was inspired by the rapid expansion in NLP services and applications with the advent of ChatGPT. While these services have empowered a broad spectrum of powerful text-based applications, they also pose significant privacy concerns. Specifically, many "Chat with X" services require users to upload their data to remote servers for processing and storage. Although this may be an acceptable trade-off for some, it is less ideal for those handling confidential or sensitive information. With this in mind, **SimilaritySearchKit** aims to provide a robust, local-first solution that enables developers to create state-of-the-art  NLP applications within the Apple ecosystem without compromising user privacy.

## Use Cases

Some potential use cases for **SimilaritySearchKit** include:

- **Privacy-focused document search engines:** Create a search engine that processes sensitive documents locally, without exposing user data to external services. (See example project "ChatWithFiles" in the `Examples` directory.)

- **Document clustering and organization:** Automatically group and organize documents based on their textual content, all on-device.

- **Question-answering systems:** Implement a question-answering system that finds the most relevant answers to a user's query within a local dataset.

By leveraging **SimilaritySearchKit**, developers can easily create powerful applications that prioritize user privacy without major tradeoffs in functionality or performance.

## Installation

To install **SimilaritySearchKit**, simply add it as a dependency to your Swift project using the Swift Package Manager. Add the following line to your dependencies array in your Package.swift file:

```swift
.package(url: "https://github.com/ZachNagengast/SimilaritySearchKit.git", from: "0.0.1")
```

Then, add the appropriate target dependency to the desired target:

```swift
.target(name: "YourTarget", dependencies: [
    "SimilaritySearchKit", 
    "SimilaritySearchKitDistilbert", 
    "SimilaritySearchKitMiniLMMultiQA", 
    "SimilaritySearchKitMiniLMAll"
])
```

If you only want to use a subset of the available models, you can omit the corresponding dependency. This will reduce the size of your final binary.

## Usage

To use SimilaritySearchKit in your project, first import the framework:

```swift
import SimilaritySearchKit
```

Next, create an instance of SimilarityIndex with your desired distance metric and [embedding model](#available-models) (see below for options):

```swift
let similarityIndex = await SimilarityIndex(
    model: NativeEmbeddings(),
    metric: CosineSimilarity()
)
```

Then, add your text that you want to make searchable to the index:

```swift
await similarityIndex.addItem(
    id: "id1", 
    text: "Metal was released in June 2014.", 
    metadata: ["source": "example.pdf"]
)
```

Finally, query the index for the most similar items to a given query:

```swift
let results = await similarityIndex.search("When was metal released?")
print(results)
```

Which outputs a **SearchResult** array:

`[SearchResult(id: "id1", score: 0.86216, metadata: ["source": "example.pdf"])]`

## Available Models

| Model | Use Case | Size | Source |
| --- | --- | --- | --- |
| `NaturalLanguage` | Text similarity, faster inference | Built-in | [Apple](https://developer.apple.com/documentation/naturallanguage/nlembedding) |
| `MiniLMAll` | Text similarity, fastest inference | 46 MB | [HuggingFace](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2) |
| `Distilbert` | Q&A search, high accuracy | 86 MB (quantized) | [HuggingFace](https://huggingface.co/msmarco-distilbert-base-tas-b) |
| `MiniLMMultiQA` | Q&A search, fastest inference | 46 MB | [HuggingFace](https://huggingface.co/sentence-transformers/multi-qa-MiniLM-L6-cos-v1) |

Models conform the the `EmbeddingProtocol` and can be used interchangeably with the `SimilarityIndex` class.

## Available Metrics

| Metric | Description |
| --- | --- |
| `DotProduct` | Measures the similarity between two vectors as the product of their magnitudes |
| `CostineSimilarity` | Calculates similarity by measuring the cosine of the angle between two vectors |
| `EuclideanDistance` | Computes the straight-line distance between two points in Euclidean space |
| `NLDistance` | Built-in cosine similarity |

Metrics conform to the `DistanceMetricProtocol` and can be used interchangeably with the `SimilarityIndex` class.

## Bring Your Own

All the main parts of the `SimilarityIndex` can be overriden with custom implementations that conform to the following protocols:

### EmbeddingProtocol

Accepts a string and returns an array of floats representing the embedding of the input text.

```swift
func encode(sentence: String) async -> [Float]?
```

### DistanceMetricProtocol

Accepts a query embedding vector and a list of embeddings vectors and returns a tuple of the distance metric score and index of the nearest neighbor.

```swift
func findNearest(for queryEmbedding: [Float], in neighborEmbeddings: [[Float]], resultsCount: Int) -> [(Float, Int)]
```

### VectorStoreProtocol

Save and load index items. The default implementation uses JSON files, but this can be overriden to use any storage mechanism.

```swift
func saveIndex(items: [IndexItem], to url: URL, as name: String) throws -> URL
func loadIndex(from url: URL) throws -> [IndexItem]
func listIndexes(at url: URL) -> [URL]
```

## Acknowledgements

Many parts of this project were derived from the existing code, either already in swift, or translated into swift thanks to ChatGPT. These are some of the main projects that were referenced:

- HuggingFace Transformers
  - https://github.com/huggingface/transformers
  - https://github.com/huggingface/swift-coreml-transformers
- Sentence Transformers https://github.com/UKPLab/sentence-transformers
- LangChain https://github.com/hwchase17/langchain
- Chroma https://github.com/chroma-core/chroma
- Pinecone https://github.com/pinecone-io/examples
- OpenAI Plugins https://github.com/openai/chatgpt-retrieval-plugin

## Future Work

Here's a short list of some features that are planned for future releases:

- [x] In-memory indexing
- [ ] Disk-backed indexing
  - For large datasets that don't fit in memory
- [ ] All around performance improvements
- [ ] Swift-DocC website
- [ ] HSNW / Annoy indexing options
- [ ] Querying filters
  - Only return results with specific metadata
- [ ] Sparse/Dense hybrid search
  - Use sparse search to find candidate results, then rerank with dense search
  - More info [here](https://weaviate.io/blog/hybrid-search-explained)
- [ ] More embedding models
- [ ] Summarization models
  - Can be used to merge several query results into one, and clean up irrelevant text
- [ ] Metal acceleration for distance calcs

## Contributing

If you have any ideas, suggestions, or bugs to report, please open an issue or submit a pull request from your fork. Contributions are always welcome!

Notes on the file structure:

- `Sources/SimilaritySearchKit/Core` contains the main similarity search logic and helper methods that run 100% natively (i.e. *no dependencies*).
- `Sources/SimilaritySearchKit/AddOns` contains optional embedding models, and any other logic that *require external dependencies* and should be added as separate targets and imports. This is intended to reduce the size of the binary for users who don't need them.

I'm curious to see how people use this library and what other features would be useful, so please don't hesitate to reach out over twitter [@ZachNagengast](https://twitter.com/zachnagengast) or email znagengast (at) gmail (dot) com.
