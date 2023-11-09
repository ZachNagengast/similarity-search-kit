//
//  DistanceTest.swift
//
//
//  Created by Bernhard Eisvogel on 31.10.23.
//

@testable import SimilaritySearchKit
import XCTest

func randomString(_ length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789아오우"
    return String((0..<length).map { _ in letters.randomElement()! })
}

final class DistanceTest: XCTestCase {
    private var randomStringData: [String] = {
        var data: [String] = []
        for _ in 0..<5000 {
            data.append(randomString(Int.random(in: 7...20)))
        }
        return data
    }()

    private var k: Int = 10

    func testExampleInt() throws {
        let data = Array(0...10000).shuffled()

        func sort(a: Int, b: Int) throws -> Bool {
            return a<b
        }

        let topKcorrect = try Array(data.sorted(by: sort).prefix(k))
        let topKfast = try data.topK(k, by: sort)
        XCTAssertEqual(topKcorrect, topKfast)
    }

    func sortString(a: String, b: String) throws -> Bool {
        return a.hashValue<b.hashValue
    }

    func testExampleStrSlow() {
        // Measures the speed of the old algorithm
        measure {
            do {
                _ = try Array(randomStringData.sorted(by: sortString).prefix(k))
            } catch {
                print("Error sorting with the old algorithm")
            }
        }
    }

    func testExampleStrFast() {
        // Measures the speed of the new algorithm
        measure {
            do {
                _ = try randomStringData.topK(k, by: sortString)
            } catch {
                print("Error sorting with the new algorithm")
            }
        }
    }
}
