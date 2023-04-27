//
//  JsonStore.swift
//
//
//  Created by Zach Nagengast on 4/26/23.
//

import Foundation

public class JsonStore: VectorStoreProtocol {
    public func saveIndex(items: [IndexItem], to url: URL, as name: String) throws -> URL {
        let encoder = JSONEncoder()
        let data = try encoder.encode(items)

        let fileURL = url.appendingPathComponent("\(name).json")

        do {
            try data.write(to: fileURL)
        } catch {
            throw error
        }

        return fileURL
    }

    public func loadIndex(from url: URL) throws -> [IndexItem] {
        do {
            let data = try Data(contentsOf: url)

            let decoder = JSONDecoder()
            let items = try decoder.decode([IndexItem].self, from: data)

            return items
        } catch {
            throw error
        }
    }

    public func listIndexes(at url: URL) -> [URL] {
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            let jsonFiles = files.filter { $0.pathExtension == "json" }
            return jsonFiles
        } catch {
            print("Error listing indexes: \(error)")
            return []
        }
    }
}
