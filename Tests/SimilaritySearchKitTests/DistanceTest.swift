//
//  DistanceTest.swift
//  
//
//  Created by Bernhard Eisvogel on 31.10.23.
//

import XCTest
@testable import SimilaritySearchKit

final class DistanceTest: XCTestCase {
    override func setUpWithError() throws {
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    func testExampleInt() throws {
        let data = Array(0...10000).shuffled()
        let k = 10

        func sort(a:Int, b:Int) throws -> Bool {
            return a<b
        }
    
        let topKcorrect = try Array(data.sorted(by: sort).prefix(k))
        let topKfast    = try data.topK(k, by: sort)
        XCTAssertEqual(topKcorrect, topKfast)
    }
}
