//
//  ProtobufStore.swift
//
//
//  Created by Zach Nagengast on 4/20/23.
//

import Foundation
// TODO: import SwiftProtobuf

// let basePath = "/path/to/your/storage"
// let indexPath = "\(basePath)/chunk_index.json"
//
// struct VectorIndex: Codable {
//    var id: String
//    var collectionFile: String
// }
//
// func store(vectors: [Vector], collectionSize: Int) {
//    var collectionIndex = 0
//    var index: [VectorIndex] = []
//
//    for vector in vectors {
//        let collectionFile = "collection_\(collectionIndex).protobuf"
//        let collectionFilePath = "\(basePath)/\(collectionFile)"
//
//        var batch: Collection
//        if let data = try? Data(contentsOf: URL(fileURLWithPath: batchFilePath)) {
//            batch = try! Batch(serializedData: data)
//        } else {
//            batch = Batch()
//        }
//
//        batch.chunks.append(chunk)
//
//        if batch.chunks.count >= batchSize {
//            try! batch.serializedData().write(to: URL(fileURLWithPath: batchFilePath))
//            batch = Batch()
//            batchIndex += 1
//        }
//
//        index.append(ChunkIndex(id: chunk.id, batchFile: batchFile))
//    }
//
//    let encoder = JSONEncoder()
//    if let indexData = try? encoder.encode(index) {
//        try? indexData.write(to: URL(fileURLWithPath: indexPath))
//    }
// }
//
// func loadChunk(withId id: String) -> Chunk? {
//    guard let indexData = try? Data(contentsOf: URL(fileURLWithPath: indexPath)) else {
//        return nil
//    }
//
//    let decoder = JSONDecoder()
//    guard let index = try? decoder.decode([ChunkIndex].self, from: indexData) else {
//        return nil
//    }
//
//    guard let chunkIndex = index.first(where: { $0.id == id }) else {
//        return nil
//    }
//
//    let batchFilePath = "\(basePath)/\(chunkIndex.batchFile)"
//    guard let batchData = try? Data(contentsOf: URL(fileURLWithPath: batchFilePath)) else {
//        return nil
//    }
//
//    let batch = try! Batch(serializedData: batchData)
//    return batch.chunks.first(where: { $0.id == id })
// }
