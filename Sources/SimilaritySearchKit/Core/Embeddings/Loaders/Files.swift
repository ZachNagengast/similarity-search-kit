//
//  FileSystemManager.swift
//
//
//  Created by Zach Nagengast on 4/6/23.
//
import Foundation
import Dispatch
import PDFKit
import RegexBuilder

@available(macOS 13.0, iOS 16.0, *)
public class Files {
    public init() {}

    public class func isDirectory(url: URL) -> Bool {
        let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
        let isDirectory = resourceValues?.isDirectory ?? false
        return isDirectory
    }

    public func scanFile(url: URL) async -> DiskItem? {
        do {
            let resourceValues = try url.resourceValues(forKeys: Set([.isDirectoryKey, .fileSizeKey]))
            let isDirectory = resourceValues.isDirectory ?? false
            let fileSize = Int64(resourceValues.fileSize ?? 0)

            if !isDirectory {
                return try await DiskItem(url: url, isDirectory: isDirectory, fileSize: fileSize)
            } else {
                return nil
            }
        } catch {
            print("Error: \(error)")
            return nil
        }
    }

    // Scans the given directory and returns a DiskItem representing the directory structure
    public func scanDirectory(url: URL) async -> DiskItem? {
        do {
            let resourceValues = try url.resourceValues(forKeys: Set([.isDirectoryKey, .fileSizeKey]))
            let isDirectory = resourceValues.isDirectory ?? false
            let fileSize = Int64(resourceValues.fileSize ?? 0)

            let diskItem = try await DiskItem(url: url, isDirectory: isDirectory, fileSize: fileSize)
            return diskItem
        } catch {
            print("Error: \(error)")
            return nil
        }
    }

    public struct FileTextContents {
        public let id: UUID
        public let text: String
        public let fileUrl: URL

        public init(id: UUID, text: String, fileUrl: URL) {
            self.id = id
            self.text = text
            self.fileUrl = fileUrl
        }
    }

    public class func extractText(fromDiskItems diskItems: [DiskItem]) -> [FileTextContents] {
        var fileInfoList: [FileTextContents] = []

        for diskItem in diskItems {
            if let children = diskItem.children {
                let childFileInfo = extractText(fromDiskItems: children)
                fileInfoList.append(contentsOf: childFileInfo)
            } else {
                let fileExtension = diskItem.fileUrl.pathExtension.lowercased()
                if fileExtension == "txt" {
                    do {
                        let content = try String(contentsOf: diskItem.fileUrl, encoding: .utf8)
                        let metadata = FileTextContents(id: diskItem.fileId, text: content, fileUrl: diskItem.fileUrl)
                        fileInfoList.append(metadata)
                    } catch {
                        print("Error reading file: \(error)")
                    }
                } else if fileExtension == "pdf" {
                    if let content = extractTextFromPDF(url: diskItem.fileUrl) {
                        let metadata = FileTextContents(id: diskItem.fileId, text: content, fileUrl: diskItem.fileUrl)
                        fileInfoList.append(metadata)
                    }
                } else {
                    // Try to read arbitrary file types
                    if let content = readContentOfFile(fileURL: diskItem.fileUrl) {
                        let metadata = FileTextContents(id: diskItem.fileId, text: content, fileUrl: diskItem.fileUrl)
                        fileInfoList.append(metadata)
                    }
                }
            }
        }

        return fileInfoList
    }

    public class func readContentOfFile(fileURL: URL) -> String? {
        do {
            let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
            return containsWords(fileContent) ? fileContent : nil
        } catch {
            print("Error reading file content: \(error)")
            return nil
        }
    }

    public class func containsWords(_ text: String) -> Bool {
        let regex = Regex {
            Capture {
                One(.word)
            }
        }

        if text.firstMatch(of: regex) != nil {
            return true
        }

        return false
    }

    public class func extractTextFromPDF(url: URL) -> String? {
        let pdfDocument = PDFDocument(url: url)

        guard let document = pdfDocument else {
            print("Failed to load PDF document.")
            return nil
        }

        let pageCount = document.pageCount
        var extractedText = ""

        for pageIndex in 0..<pageCount {
            if let page = document.page(at: pageIndex) {
                if let pageContent = page.string {
                    extractedText += pageContent
                }
            }
        }

        return extractedText
    }

    // Function to write the CSV string to a file
    public class func writeStringsToFile(inputArray: [String], filename: String) {
        let csvString = inputArray.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",\n")

        let fileManager = FileManager.default
        let documentDirectoryURL = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)

        if let fileURL = documentDirectoryURL?.appendingPathComponent(filename).appendingPathExtension("csv") {
            do {
                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
                print("CSV file saved at: \(fileURL)")
            } catch {
                print("Error writing CSV file: \(error)")
            }
        }
    }

    public class func writeIndexItemsToFile(inputArray: [IndexItem], filename: String) {
        // Create the header for the CSV file
        let header = "id,text,embedding,metadata\n"

        // Create a CSV string for each IndexItem
        let csvString = inputArray.map { indexItem -> String in
            let id = "\"\(indexItem.id.replacingOccurrences(of: "\"", with: "\"\""))\""
            let text = "\"\(indexItem.text.replacingOccurrences(of: "\"", with: "\"\""))\""
            let embedding = indexItem.embedding.map { String($0) }.joined(separator: " ")
            let metadata = indexItem.metadata.map { "\($0.key): \($0.value)" }.joined(separator: "; ")

            return "\(id),\(text),\"\(embedding)\",\"\(metadata)\""
        }.joined(separator: "\n")

        let fileContent = header + csvString

        let fileManager = FileManager.default
        let documentDirectoryURL = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)

        if let fileURL = documentDirectoryURL?.appendingPathComponent(filename).appendingPathExtension("csv") {
            do {
                try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)
                print("CSV file saved at: \(fileURL)")
            } catch {
                print("Error writing CSV file: \(error)")
            }
        }
    }
}

@available(macOS 13.0, iOS 16.0, *)
public struct DiskItem: Identifiable, Hashable {
    public var id = UUID()
    public let fileId = UUID()
    public let name: String
    public let fileUrl: URL
    public let diskSize: Int64
    public var children: [DiskItem]?

    // Initializes a DiskItem from the given URL and resource values
    init(url: URL, isDirectory: Bool, fileSize: Int64, onProgress: ((Int64, Int, Int, String?) -> Void)? = nil) async throws {
        self.fileUrl = url
        self.name = url.lastPathComponent

        if isDirectory {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])

            let (childItems, currentSize, files, folders) = try await Self.processTaskGroup(contents: contents, onProgress: onProgress)

            children = childItems.sorted { $0.diskSize > $1.diskSize }
            diskSize = Int64(currentSize)

            onProgress?(currentSize, files, folders + 1, name)
        } else {
            self.children = nil
            self.diskSize = fileSize
            onProgress?(diskSize, 1, 0, nil)
        }
    }

    private init(url: URL, diskSize: Int64, children: [DiskItem]?) {
        self.name = url.lastPathComponent
        self.fileUrl = url
        self.diskSize = diskSize
        self.children = children
    }

    public init(name: String, fileUrl: URL, diskSize: Int64, children: [DiskItem]?) {
        self.name = name
        self.fileUrl = fileUrl
        self.diskSize = diskSize
        self.children = children
    }

    public init(withoutChildren diskItem: DiskItem) {
        self.init(name: diskItem.name, fileUrl: diskItem.fileUrl, diskSize: diskItem.diskSize, children: nil)
    }

    // Processes the task group for the given directory contents
    private static func processTaskGroup(contents: [URL], onProgress: ((Int64, Int, Int, String?) -> Void)? = nil) async throws -> ([DiskItem], Int64, Int, Int) {
        var childItems: [DiskItem] = []
        var currentSize: Int64 = 0
        var files: Int = 0
        var folders: Int = 0

        try await withThrowingTaskGroup(of: DiskItem?.self) { taskGroup in
            for content in contents {
                taskGroup.addTask(priority: .high) {
                    do {
                        let path = content.path
                        var statBuf = stat()

                        if lstat(path, &statBuf) == -1 {
                            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
                        }

                        let isDirectory = statBuf.st_mode & S_IFMT == S_IFDIR
                        let fileSize = statBuf.st_size

                        if isDirectory {
                            return try await DiskItem(url: content, isDirectory: isDirectory, fileSize: Int64(fileSize), onProgress: onProgress)
                        } else {
                            let diskSize = Int64(fileSize)
                            let diskItem = DiskItem(url: content, diskSize: diskSize, children: nil)
                            onProgress?(diskSize, 1, 0, nil)
                            return diskItem
                        }
                    } catch {
                        if let cocoaError = error as? CocoaError, cocoaError.code == .fileReadNoPermission {
                            print("Error: No permission to read: \(content)")
                            return nil
                        } else {
                            throw error
                        }
                    }
                }
            }

            for try await childItemOrNil in taskGroup {
                if let childItem = childItemOrNil {
                    childItems.append(childItem)
                    currentSize += childItem.diskSize
                    files += childItem.children == nil ? 1 : 0
                    folders += childItem.children != nil ? 1 : 0
                }
            }
        }

        return (childItems, currentSize, files, folders)
    }
}
