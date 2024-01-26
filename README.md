# SimilaritySearchKit
[![](https://img.shields.io/github/actions/workflow/status/ZachNagengast/similarity-search-kit/swift.yml?branch=main)](https://github.com/ZachNagengast/similarity-search-kit/actions/workflows/swift.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FZachNagengast%2Fsimilarity-search-kit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ZachNagengast/similarity-search-kit)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FZachNagengast%2Fsimilarity-search-kit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ZachNagengast/similarity-search-kit)
[![](https://img.shields.io/badge/Examples-yes-red)](#examples)
![License](https://img.shields.io/github/license/ZachNagengast/similarity-search-kit?color=red)

![ssk-logo](https://user-images.githubusercontent.com/1981179/234468591-cda2871d-cb29-4b3e-bef4-77e0702123e1.png)

**SimilaritySearchKit** is a Swift package enabling *on-device* text embeddings and semantic search functionality for iOS and macOS applications in just a few lines. Emphasizing speed, extensibility, and privacy, it supports a variety of built-in state-of-the-art NLP models and similarity metrics, in addition to seamless integration for bring-your-own options.

[![Chat With Files Example](https://user-images.githubusercontent.com/1981179/235818327-05ed993d-1faf-4023-a3bb-6ef3f0440cc4.gif)](https://youtu.be/yYfQX4QdNJI)

## Use Cases

Some potential use cases for **SimilaritySearchKit** include:

- **Privacy-focused document search engines:** Create a search engine that processes sensitive documents locally, without exposing user data to external services. (See example project "ChatWithFilesExample" in the [Examples](#examples) directory.)

- **Offline question-answering systems:** Implement a question-answering system that finds the most relevant answers to a user's query within a local dataset.

- **Document clustering and recommendation engines:** Automatically group and organize documents based on their textual content on the edge.


By leveraging **SimilaritySearchKit**, developers can easily create powerful applications that keep data close to home without major tradeoffs in functionality or performance.

## Installation

To install **SimilaritySearchKit**, simply add it as a dependency to your Swift project using the Swift Package Manager. I recommend using the Xcode method personally via:

`File` → `Add Packages...` → `Search or Enter Package Url` → `https://github.com/ZachNagengast/similarity-search-kit.git`

Xcode should give you the following options to choose which model you'd like to add (see [available models](#available-models) below for help choosing):

![Xcode Swift Package Manager Import](https://user-images.githubusercontent.com/1981179/235577729-eae29187-8d3b-40cb-b7d7-f6470a80b141.png)

If you want to add it via `Package.swift`, add the following line to your dependencies array:

```swift
.package(url: "https://github.com/ZachNagengast/similarity-search-kit.git", from: "0.0.1")
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

## Examples

The `Examples` directory contains multple sample iOS and macOS applications that demonstrates how to use **SimilaritySearchKit** to it's fullest extent.

| Example | Description | Requirements |
| --- | --- | --- |
| `BasicExample` | A basic multiplatform application that indexes and compares similarity of a small set of hardcoded strings. | iOS 16.0+, macOS 13.0+ |
| `PDFExample` | A mac-catalyst application that enables semantic search on the contents of individual PDF files. | iOS 16.0+ |
| `ChatWithFilesExample` | An advanced macOS application that indexes any/all text files on your computer. | macOS 13.0+ |


## Available Models

| Model | Use Case | Size | Source |
| --- | --- | --- | --- |
| `NaturalLanguage` | Text similarity, faster inference | Built-in | [Apple](https://developer.apple.com/documentation/naturallanguage/nlembedding) |
| `MiniLMAll` | Text similarity, fastest inference | 46 MB | [HuggingFace](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2) |
| `Distilbert` | Q&A search, highest accuracy | 86 MB (quantized) | [HuggingFace](https://huggingface.co/sentence-transformers/msmarco-distilbert-base-tas-b) |
| `MiniLMMultiQA` | Q&A search, fastest inference | 46 MB | [HuggingFace](https://huggingface.co/sentence-transformers/multi-qa-MiniLM-L6-cos-v1) |

Models conform the the `EmbeddingProtocol` and can be used interchangeably with the `SimilarityIndex` class.

A small but growing list of pre-converted models can be found in this repo on [HuggingFace](https://huggingface.co/ZachNagengast/similarity-search-coreml-models/tree/main). If you have a model that you would like to see added to the list, please open an issue or submit a pull request.

## Available Metrics

| Metric | Description |
| --- | --- |
| `DotProduct` | Measures the similarity between two vectors as the product of their magnitudes |
| `CosineSimilarity` | Calculates similarity by measuring the cosine of the angle between two vectors |
| `EuclideanDistance` | Computes the straight-line distance between two points in Euclidean space |

Metrics conform to the `DistanceMetricProtocol` and can be used interchangeably with the `SimilarityIndex` class.

## Bring Your Own

All the main parts of the `SimilarityIndex` can be overriden with custom implementations that conform to the following protocols:

### EmbeddingsProtocol

Accepts a string and returns an array of floats representing the embedding of the input text.

```swift
func encode(sentence: String) async -> [Float]?
```

### DistanceMetricProtocol

Accepts a query embedding vector and a list of embeddings vectors and returns a tuple of the distance metric score and index of the nearest neighbor.

```swift
func findNearest(for queryEmbedding: [Float], in neighborEmbeddings: [[Float]], resultsCount: Int) -> [(Float, Int)]
```

### TextSplitterProtocol

Splits a string into chunks of a given size, with a given overlap. This is useful for splitting long documents into smaller chunks for embedding. It returns the list of chunks and an optional list of tokensIds for each chunk.

```swift
func split(text: String, chunkSize: Int, overlapSize: Int) -> ([String], [[String]]?)
```

### TokenizerProtocol

Tokenizes and detokenizes text. Use this for custom models that use different tokenizers than are available in the current list.

```swift
func tokenize(text: String) -> [String]
func detokenize(tokens: [String]) -> String
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


## Motivation

This project has been inspired by the incredible advancements in natural language services and applications that have come about with the emergence of ChatGPT. While these services have unlocked a whole new world of powerful text-based applications, they often rely on cloud services. Specifically, many "Chat with Data" services necessitate users to upload their data to remote servers for processing and storage. Although this works for some, it might not be the best fit for those in low connectivity environments, or handling confidential or sensitive information. While Apple does have bundled library `NaturalLanguage` for similar tasks, the CoreML model conversion process opens up a much wider array of models and use cases. With this in mind, **SimilaritySearchKit** aims to provide a robust, on-device solution that enables developers to create state-of-the-art NLP applications within the Apple ecosystem.

## Future Work

Here's a short list of some features that are planned for future releases:

- [x] In-memory indexing
- [x] Disk-backed indexing
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

I'm curious to see how people use this library and what other features would be useful, so please don't hesitate to reach out over twitter [@ZachNagengast](https://twitter.com/zachnagengast) or email znagengast (at) gmail (dot) com.
