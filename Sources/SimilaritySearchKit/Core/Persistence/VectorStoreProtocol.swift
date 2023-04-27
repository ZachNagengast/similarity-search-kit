//
//  VectorStoreProtocol.swift
//
//
//  Created by Zach Nagengast on 4/26/23.
//

import Foundation

public protocol VectorStoreProtocol {
    func saveIndex(items: [IndexItem], to url: URL, as name: String) throws -> URL
    func loadIndex(from url: URL) throws -> [IndexItem]
    func listIndexes(at url: URL) -> [URL]
}
