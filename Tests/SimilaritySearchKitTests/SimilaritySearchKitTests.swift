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

@available(macOS 13.0, *)
class SimilaritySearchKitTests: XCTestCase {
    func testSavingIndex() async {
        let similarityIndex = await SimilarityIndex(model: DistilbertEmbeddings(), vectorStore: JsonStore())

        await similarityIndex.addItem(id: "1", text: "Example text", metadata: ["source": "test source"], embedding: [0.1, 0.2, 0.3])

        let successPath = try! similarityIndex.saveIndex(name: "TestIndexForSaving")

        XCTAssertNotNil(successPath)
    }

    func testLoadingIndex() async {
        let similarityIndex = await SimilarityIndex(model: DistilbertEmbeddings(), vectorStore: JsonStore())

        await similarityIndex.addItem(id: "1", text: "Example text", metadata: ["source": "test source"])

        let successPath = try! similarityIndex.saveIndex(name: "TestIndexForLoading")

        XCTAssertNotNil(successPath)

        let similarityIndex2 = await SimilarityIndex(model: DistilbertEmbeddings(), vectorStore: JsonStore())

        let loadedItems = try! similarityIndex2.loadIndex(name: "TestIndexForLoading")

        XCTAssertNotNil(loadedItems)
    }
}
