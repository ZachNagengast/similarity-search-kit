//
//  BinaryStore.swift
//
//
//  Created by Michael Jelly on 7/14/23.
//
import Compression
import Foundation

public class BinaryStore: VectorStoreProtocol {
    public init() {
         print("Initted new BinaryStore")
    }
    public func saveIndex(items: [IndexItem], to url: URL, as name: String) throws -> URL {
        let fileURL = url.appendingPathComponent("\(name).dat")
        var data = Data()

        for item in items {
            let encoder = JSONEncoder()
            let itemData = try encoder.encode(item)
            var length = Int32(itemData.count)
            var lengthData = Data()
            lengthData.append(UnsafeBufferPointer(start: &length, count: 1))
            data.append(lengthData)
            data.append(itemData)
        }
        let nsdata = data as NSData
        let compressedData = try nsdata.compressed(using: .lzma)

        do {
            try compressedData.write(to: fileURL, options: .atomic)
        } catch {
            throw error
        }

        return fileURL
    }

    public func loadIndex(from url: URL) throws -> [IndexItem] {
        let compressedData = try Data(contentsOf: url)
        let decompressedData = compressedData.withUnsafeBytes { ptr -> Data in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: compressedData.count * 5) // assuming the compressed data is at most 5 times smaller than the original data
            let decompressedSize = compression_decode_buffer(buffer, compressedData.count * 5, ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), compressedData.count, nil, COMPRESSION_LZMA)
            return Data(bytes: buffer, count: decompressedSize)
        }

        var items: [IndexItem] = []
        var start = decompressedData.startIndex

        while start < decompressedData.endIndex {
            let lengthData = decompressedData[start..<(start+4)]
            let length: Int32 = lengthData.withUnsafeBytes { $0.pointee }
            start += 4
            let end = start + Int(length)
            let itemData = decompressedData[start..<end]
            let decoder = JSONDecoder()
            let item = try decoder.decode(IndexItem.self, from: itemData)
            items.append(item)
            start = end
        }

        return items
    }


  public func listIndexes(at url: URL) -> [URL] {
    let fileManager = FileManager.default
    do {
      let files = try fileManager.contentsOfDirectory(
        at: url, includingPropertiesForKeys: nil, options: [])
      let datFiles = files.filter { $0.pathExtension == "dat" }
      return datFiles
    } catch {
      print("Error listing indexes: \(error)")
      return []
    }
  }
}
