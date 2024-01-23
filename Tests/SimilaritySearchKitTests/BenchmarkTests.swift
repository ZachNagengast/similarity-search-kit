//
//  BenchmarkTests.swift
//
//
//  Created by Zach Nagengast on 4/13/23.
//

import XCTest
import CoreML
@testable import SimilaritySearchKit
@testable import SimilaritySearchKitDistilbert
@testable import SimilaritySearchKitMiniLMAll
@testable import SimilaritySearchKitMiniLMMultiQA

@available(macOS 13.0, iOS 16.0, *)
class BenchmarkTests: XCTestCase {
    func testDistilbertTokenization() {
        let passageText = MSMarco.testPassage.text
        let tokenizer = BertTokenizer()

        let tokenIds = tokenizer.buildModelTokens(sentence: passageText)
        let (inputIds, attentionMask, tokenTypeIds) = tokenizer.buildModelInputsWithTypeIds(from: tokenIds)

        XCTAssertEqual(MLMultiArray.toIntArray(inputIds), MSMarco.testPassage.tokens)
        XCTAssertEqual(MLMultiArray.toIntArray(tokenTypeIds), MSMarco.testPassage.tokenTypeIds)
        XCTAssertEqual(MLMultiArray.toIntArray(attentionMask), MSMarco.testPassage.attentionMask)
    }

    func testDistilbertEmbeddings() async {
        let text = MSMarco.testPassage.text
        let model = DistilbertEmbeddings()

        let embeddings = await model.encode(sentence: text)

        XCTAssertNotNil(embeddings)
    }

    func testDistilbertSearch() {
        let searchPassage = MSMarco.testPassage

        let expectation = XCTestExpectation(description: "Encoding passage texts")

        Task {
            let similarityIndex = await SimilarityIndex(model: DistilbertEmbeddings())
            await similarityIndex.addItems(
                ids: [UUID().uuidString],
                texts: [searchPassage.text],
                metadata: [searchPassage.metadata]
            )

            let top_k = await similarityIndex.search("test query")
            let searchResult: SimilarityIndex.SearchResult = top_k.first!
            XCTAssertEqual(searchResult.text, searchPassage.text)
            XCTAssertEqual(searchResult.metadata, searchPassage.metadata)
            XCTAssertNotEqual(searchResult.score, 0)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 60)
    }

    func testDistilbertPerformanceTokenization() {
        let passageTexts = MSMarco.passageTexts[0..<10]
        let tokenizer = BertTokenizer()

        print("Tokenizing \(passageTexts.count) passage texts")
        for passageText in passageTexts {
            _ = tokenizer.tokenize(text: passageText)
        }
    }

    func testDistilbertPerformanceEmbeddingsSync() {
        let model = DistilbertEmbeddings()
        let tokenizer = model.tokenizer
        let passageTexts = MSMarco.passageTexts[0..<10]
        var inputs = [(MLMultiArray, MLMultiArray)]()

        // Do 10 Sync
        for passageText in passageTexts {
            let tokens = tokenizer.buildModelTokens(sentence: passageText)
            let (input_id, attention_mask) = tokenizer.buildModelInputs(from: tokens)
            inputs.append((input_id, attention_mask))
        }

        print("Generating embeddings for \(inputs.count) pre-tokenized inputs")
        for input in inputs {
            _ = model.generateDistilbertEmbeddings(inputIds: input.0, attentionMask: input.1)
        }
    }

    func testDistilbertPerformanceEncodingAsync() {
        let model = DistilbertEmbeddings()
        let passageTexts = MSMarco.passageTexts[0..<10]

        let expectation = XCTestExpectation(description: "Encoding passage texts")

        Task {
            print("\nEncoding \(passageTexts.count) passage texts ")
            let startTime = CFAbsoluteTimeGetCurrent()
            await withTaskGroup(of: Void.self) { taskGroup in
                for passageText in passageTexts {
                    taskGroup.addTask {
                        _ = await model.encode(sentence: passageText)
                    }
                }
            }
            let endTime = CFAbsoluteTimeGetCurrent()
            let elapsedTime = endTime - startTime
            let timePerPassageText = elapsedTime / Double(passageTexts.count) * 1000 // Convert to milliseconds
            print("\nTime per passage text: \(timePerPassageText) ms each, \(elapsedTime) s total")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 60.0)
    }

    func testDistilbertPerformanceSearch() {
        let testAmount = 2
        let passageIds = Array(0..<testAmount).map { _ in UUID().uuidString }
        let passageTexts = Array(MSMarco.passageTexts[0..<testAmount])
        let passageUrls = MSMarco.passageUrls[0..<testAmount].map { url in ["source": url] }

        let expectation = XCTestExpectation(description: "Searching passage texts")

        Task {
            print("\nGenerating similarity index for \(testAmount) passages")
            let similarityIndex = await SimilarityIndex(model: DistilbertEmbeddings())

            var startTime = CFAbsoluteTimeGetCurrent()
            await similarityIndex.addItems(
                ids: passageIds,
                texts: passageTexts,
                metadata: passageUrls
            )
            var endTime = CFAbsoluteTimeGetCurrent()
            var elapsedTime = endTime - startTime
            print("\nGenerating index took \(elapsedTime) s")

            print("\nSearching \(passageTexts.count) passage texts")
            startTime = CFAbsoluteTimeGetCurrent()

            let top_k = await similarityIndex.search("what is bitcoin?", top: 100)

            XCTAssertNotNil(top_k)

            endTime = CFAbsoluteTimeGetCurrent()
            elapsedTime = endTime - startTime
            let timePerPassageText = elapsedTime / Double(testAmount)
            print("\nSeach time per passage text: \(timePerPassageText) s each, \(elapsedTime) s total\n")

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 60)
    }

    func testNativePerformanceTokenization() {}

    func testNativePerformanceEmbeddings() {}

    func testNativePerformanceSearch() {}
}
