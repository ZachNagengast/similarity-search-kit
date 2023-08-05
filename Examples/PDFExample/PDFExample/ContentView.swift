//
//  ContentView.swift
//  PDFExample
//
//  Created by Zach Nagengast on 5/2/23.
//

import SwiftUI
import SimilaritySearchKit
import SimilaritySearchKitDistilbert
import UIKit
import MobileCoreServices
import PDFKit
import QuickLookThumbnailing

struct ContentView: View {
    @State private var documentText: String = ""
    @State private var fileName: String = ""
    @State private var fileIcon: UIImage? = nil
    @State private var totalCharacters: Int = 0
    @State private var totalTokens: Int = 0
    @State private var progress: Double = 0
    @State private var chunks: [String] = []
    @State private var embeddings: [[Float]] = []
    @State private var searchText: String = ""
    @State private var searchResults: [String] = []
    @State private var isLoading: Bool = false

    @State private var similarityIndex: SimilarityIndex?

    var body: some View {
        VStack {
            Text("🔍 PDF Search")
                .font(.largeTitle)
                .bold()
                .padding()

            Button(action: selectFromFiles) {
                Text("📂 Select PDF to Search")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 500)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding()

            if !fileName.isEmpty {
                HStack {
                    if let fileIcon = fileIcon {
                        Image(uiImage: fileIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading) {
                        Text("File: \(fileName)")
                            .font(.headline)
                        Text("🔡 Total Tokens: \(totalTokens)")
                    }
                }
                .padding()

                Button("🤖 Create Embedding Vectors") {
                    vectorizeChunks()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: 500)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
                .padding()
            }

            if !embeddings.isEmpty {
                Text("🔢 Total Embeddings: \(embeddings.count)")
                    .font(.headline)
                    .padding()

                if embeddings.count != chunks.count {
                    ProgressView(value: Double(embeddings.count), total: Double(chunks.count))
                        .frame(height: 10)
                        .frame(maxWidth: 500)
                        .padding()
                } else {
                    TextField("🔍 Search document", text: $searchText, onCommit: searchDocument)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .frame(maxWidth: 500)

                    List(searchResults, id: \.self) { result in
                        Text(result)
                    }
                    .frame(maxWidth: 500)
                    HStack {
                        Button("📋 Copy LLM Prompt") {
                            exportForLLM()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: 250)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                        .padding()

                        Button("💾 Save for Pinecone") {
                            exportForPinecone()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: 250)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                        .padding()
                    }
                }
            }
            Spacer()
        }
        .onAppear {
            loadIndex()
        }
    }

    func loadIndex() {
        Task {
            similarityIndex = await SimilarityIndex(name: "PDFIndex", model: DistilbertEmbeddings(), metric: DotProduct())
        }
    }

    func selectFromFiles() {
        let picker = DocumentPicker(document: $documentText, fileName: $fileName, fileIcon: $fileIcon, totalCharacters: $totalCharacters, totalTokens: $totalTokens)
        let hostingController = UIHostingController(rootView: picker)
        UIApplication.shared.connectedScenes
            .map { ($0 as? UIWindowScene)?.windows.first?.rootViewController }
            .compactMap { $0 }
            .first?
            .present(hostingController, animated: true, completion: nil)
    }

    func vectorizeChunks() {
        guard let index = similarityIndex else { return }

        Task {
            let splitter = RecursiveTokenSplitter(withTokenizer: BertTokenizer())
            let (splitText, _) = splitter.split(text: documentText)
            chunks = splitText

            embeddings = []
            let embeddingModel = index.indexModel
            for chunk in chunks {
                if let embedding = await embeddingModel.encode(sentence: chunk) {
                    embeddings.append(embedding)
                }
            }

            for (idx, chunk) in chunks.enumerated() {
                let vector = embeddings[idx]
                await index.addItem(id: "id\(idx)", text: chunk, metadata: ["source": fileName], embedding: vector)
            }
        }
    }

    func searchDocument() {
        guard let index = similarityIndex else { return }

        Task {
            let results = await index.search(searchText)

            searchResults = results.map { $0.text }
        }
    }

    func exportForLLM() {
        guard let index = similarityIndex else { return }

        Task {
            let results = await index.search(searchText, top: 6)
            let llmPrompt = SimilarityIndex.exportLLMPrompt(query: searchText, results: results)
            let pasteboard = UIPasteboard.general
            pasteboard.string = llmPrompt
        }
    }

    func exportForPinecone() {
        struct PineconeExport: Codable {
            let vectors: [PineconeIndexItem]
        }

        struct PineconeIndexItem: Codable {
            let id: String
            let metadata: [String: String]
            let values: [Float]
        }

        guard let index = similarityIndex else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        // Map items into Pinecone import structure
        var pineconeIndexItems: [PineconeIndexItem] = []
        for item in index.indexItems {
            let pineconeItem = PineconeIndexItem(
                id: item.id,
                metadata: [
                    "text": item.text,
                    "source": item.metadata["source"] ?? "",
                ],
                values: item.embedding
            )
            pineconeIndexItems.append(pineconeItem)
        }

        let pineconeExport = PineconeExport(vectors: pineconeIndexItems)

        do {
            let data = try encoder.encode(pineconeExport)
            let fileName = "\(index.indexName)_\(String(describing: index.indexModel))_\(index.dimension).json"

            if let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName) {
                try data.write(to: fileURL)

                let documentPicker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
                documentPicker.modalPresentationStyle = .fullScreen

                UIApplication.shared.connectedScenes
                    .map { ($0 as? UIWindowScene)?.windows.first?.rootViewController }
                    .compactMap { $0 }
                    .first?
                    .present(documentPicker, animated: true, completion: nil)
            }
        } catch {
            print("Error encoding index:", error)
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var document: String
    @Binding var fileName: String
    @Binding var fileIcon: UIImage?
    @Binding var totalCharacters: Int
    @Binding var totalTokens: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first, let _ = PDFDocument(url: url) else { return }
            let pdfText = Files.extractTextFromPDF(url: url) ?? ""

            parent.document = pdfText
            parent.fileName = url.lastPathComponent
            parent.totalCharacters = pdfText.count
            parent.totalTokens = BertTokenizer().tokenize(text: pdfText).count

            // Create the thumbnail
            let size: CGSize = CGSize(width: 60, height: 60)
            let scale = UIScreen.main.scale
            let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .all)
            let generator = QLThumbnailGenerator.shared
            generator.generateRepresentations(for: request) { thumbnail, _, error in
                DispatchQueue.main.async {
                    guard thumbnail?.uiImage != nil, error == nil else { return }
                    self.parent.fileIcon = thumbnail?.uiImage
                }
            }
        }
    }
}

// MARK: - Previews

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
