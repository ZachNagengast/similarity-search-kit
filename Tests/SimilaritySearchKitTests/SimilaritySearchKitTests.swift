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
class SimilaritySearchKitTests: XCTestCase {

    override func setUp() {
        executionTimeAllowance = 60
        continueAfterFailure = true
    }

    func testSavingJsonIndex() async {
        let similarityIndex = await SimilarityIndex(model: DistilbertEmbeddings(), vectorStore: JsonStore())

        await similarityIndex.addItem(id: "1", text: "Example text", metadata: ["source": "test source"], embedding: [0.1, 0.2, 0.3])

        let successPath = try! similarityIndex.saveIndex(name: "TestIndexForSaving")

        XCTAssertNotNil(successPath)
    }
    
    func testLoadingJsonIndex() async {
        let similarityIndex = await SimilarityIndex(model: DistilbertEmbeddings(), vectorStore: JsonStore())

        await similarityIndex.addItem(id: "1", text: "Example text", metadata: ["source": "test source"])

        let successPath = try! similarityIndex.saveIndex(name: "TestIndexForLoading")

        XCTAssertNotNil(successPath)

        let similarityIndex2 = await SimilarityIndex(model: DistilbertEmbeddings(), vectorStore: JsonStore())

        let loadedItems = try! similarityIndex2.loadIndex(name: "TestIndexForLoading")

        XCTAssertNotNil(loadedItems)
    }

    func testSavingBinaryIndex() async {
        let similarityIndex = await SimilarityIndex(model: DistilbertEmbeddings(), vectorStore: BinaryStore())

        await similarityIndex.addItem(id: "1", text: "Example text", metadata: ["source": "test source"], embedding: [0.1, 0.2, 0.3])

        let successPath = try! similarityIndex.saveIndex(name: "TestIndexForSaving")

        XCTAssertNotNil(successPath)
    }

    func testLoadingBinaryIndex() async {
        let similarityIndex = await SimilarityIndex(model: DistilbertEmbeddings(), vectorStore: BinaryStore())

        await similarityIndex.addItem(id: "1", text: "Example text", metadata: ["source": "test source"])

        let successPath = try! similarityIndex.saveIndex(name: "TestIndexForLoading")

        XCTAssertNotNil(successPath)

        let similarityIndex2 = await SimilarityIndex(model: DistilbertEmbeddings(), vectorStore: BinaryStore())

        let loadedItems = try! similarityIndex2.loadIndex(name: "TestIndexForLoading")

        XCTAssertNotNil(loadedItems)
    }
}
