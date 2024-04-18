//
//  ChatWithFilesExampleSwiftUIView.swift
//  ChatWithFilesExample
//
//  Created by Zach Nagengast on 4/17/23.
//

import SwiftUI
import SimilaritySearchKit
import SimilaritySearchKitDistilbert
import SimilaritySearchKitMiniLMAll
import SimilaritySearchKitMiniLMMultiQA

#if os(macOS)
    import AppKit
#endif

struct ChatWithFilesExampleSwiftUIView: View {
    @State private var columnVisibility =
        NavigationSplitViewVisibility.all

    @State private var currentModel: EmbeddingModelType = .distilbert
    @State private var comparisonAlgorithm: SimilarityMetricType = .dotproduct
    @State private var chunkMethod: TextSplitterType = .character
    @State private var storage: VectorStoreType = .json

    @State private var searchQuery: String = ""
    @State private var searchResultsCount: Int = 5
    @State private var searchResults: [SimilarityIndex.SearchResult]?

    @State private var chunkSize: Int = 100
    @State private var chunkOverlap: Int = 20
    @State private var filePickerURLs: [URL] = []
    @State private var folderItem: DiskItem?
    @State private var folderContents: [DiskItem]?
    @State private var folderTextIds: [String]?
    @State private var folderTextChunks: [String]?
    @State private var folderTextMetadata: [[String: String]]?
    @State private var folderTokensCount: Int?
    @State private var folderCharactersCount: Int?

    @State private var clock = ContinuousClock()
    @State private var folderScanTime: Duration = Duration(secondsComponent: 0, attosecondsComponent: 0)
    @State private var scanProgress: Int = 0
    @State private var scanTotal: Int = 100

    @State private var textSplitTime: Duration = Duration(secondsComponent: 0, attosecondsComponent: 0)
    @State private var embeddingElapsedTime: Duration = Duration(secondsComponent: 0, attosecondsComponent: 0)
    @State private var searchElapsedTime: Duration = Duration(secondsComponent: 0, attosecondsComponent: 0)

    @State private var isLoading: Bool = false
    @State private var isSearching: Bool = false
    @State private var progressStage: String = ""
    @State private var progressCurrent: Double = 0
    @State private var progressTotal: Double = 100

    @State private var embeddingModel: any EmbeddingsProtocol = DistilbertEmbeddings()
    @State private var distanceMetric: any DistanceMetricProtocol = CosineSimilarity()
    @State private var currentTokenizer: any TokenizerProtocol = BertTokenizer()
    @State private var currentSplitter: any TextSplitterProtocol = TokenSplitter(withTokenizer: BertTokenizer())

    @State private var similarityIndex: SimilarityIndex?

    var files = Files()

    var body: some View {
        NavigationSplitView(columnVisibility: Binding.constant(.all)) {
            Form {
                Section(header: Text("Embeddings")) {
                    Picker("Model:", selection: $currentModel) {
                        Text("Distilbert").tag(EmbeddingModelType.distilbert)
                        Text("MiniLM All").tag(EmbeddingModelType.minilmAll)
                        Text("MiniLM MultiQA").tag(EmbeddingModelType.minilmMultiQA)
                        Text("Apple NaturalLanguage").tag(EmbeddingModelType.native)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: currentModel) { _ in
                        folderContents = nil
                        folderTextChunks = nil
                        similarityIndex = nil
                        updateIndexComponents()
                    }

                    Picker("Scoring Function:", selection: $comparisonAlgorithm) {
                        Text("Dot Product").tag(SimilarityMetricType.dotproduct)
                        Text("Cosine Similarity").tag(SimilarityMetricType.cosine)
                        Text("Euclidean Distance").tag(SimilarityMetricType.euclidian)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: comparisonAlgorithm) { _ in
                        updateIndexComponents()
                    }
                }

                Section(header: Text("Splitting")) {
                    Picker("Chunk Method:", selection: $chunkMethod) {
                        Text("Tokens").tag(TextSplitterType.token)
                        Text("Words").tag(TextSplitterType.character)
                        Text("Recursive").tag(TextSplitterType.recursive)
                    }
                    .onChange(of: chunkMethod) { _ in
                        updateIndexComponents()
                    }

                    TextField("Chunk Size:", value: $chunkSize, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    TextField("Overlap:", value: $chunkOverlap, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled([.recursive].contains(chunkMethod))
                }

                Section(header: Text("Vector Storage")) {
                    Picker("Storage Type", selection: $storage) {
                        Text("Json").tag(VectorStoreType.json)
                        Text("MLModel (coming soon)").tag("tbd").disabled(true)
                    }
                }

                Section(header: Text("Benchmarks")) {
                    HStack {
                        Text("Folder Scanning:")
                        Spacer()
                        Text(String(describing: folderScanTime))
                    }
                    HStack {
                        Text("Text Splitting:")
                        Spacer()
                        Text(String(describing: textSplitTime))
                    }
                    HStack {
                        Text("Embeddings:")
                        Spacer()
                        Text(String(describing: embeddingElapsedTime))
                    }
                    HStack {
                        Text("Semantic Search:")
                        Spacer()
                        Text(String(describing: searchElapsedTime))
                    }
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 300, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
        } content: {
            HStack {
                VStack(alignment: .leading) {
                    Text("Choose a folder with the content\nyou would like make searchable.")
                    HStack {
                        Button("Select Folder/Files") {
                            let openPanel = NSOpenPanel()
                            openPanel.canChooseFiles = true
                            openPanel.canChooseDirectories = true
                            openPanel.allowsMultipleSelection = true

                            openPanel.begin { response in
                                if response == .OK {
                                    let urls = openPanel.urls
                                    filePickerURLs = urls
                                    Task {
                                        await fetchFolderContents()
                                    }
                                }
                            }
                        }
                        Button("Refresh Folder") {
                            Task {
                                await fetchFolderContents()
                            }
                        }.disabled(folderContents == nil)
                    }

                    Button("Split Text") {
                        Task {
                            await splitTextFromFiles()
                        }
                    }.disabled(folderContents == nil)
                    Button("Build Similarity Index") {
                        Task {
                            await generateIndexFromChunks()
                        }
                    }.disabled(folderContents == nil || folderTextChunks == nil)
                    Text("Index Count: \(similarityIndex?.indexItems.count ?? 0) vectors")
                    Text("Index Dimentions: \(similarityIndex?.dimension ?? 0)")
                    Text("Estimated Size: \(ByteCountFormatter.string(fromByteCount: Int64(similarityIndex?.estimatedSizeInBytes() ?? 0), countStyle: .file))")
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Total Characters: \(folderCharactersCount ?? 0)")
                    Text("Total Tokens: \(folderTokensCount ?? 0)")
                    Text("Total Chunks: \(folderTextChunks?.count ?? 0)")
                }
            }
            .padding()
            .frame(minWidth: 500, maxWidth: .infinity)

            Spacer()
            if isLoading {
                ProgressView("\(progressStage): \(Int(progressCurrent)) of \(Int(progressTotal))", value: progressCurrent / progressTotal * progressTotal, total: progressTotal)
                    .frame(maxWidth: 400, maxHeight: .infinity)
                    .padding()
            } else {
                DiskItemTableView(folderContents: $folderContents)
            }

        } detail: {
            VStack {
                HStack {
                    VStack {
                        Text("Search Query")

                        TextField("Enter your search query here", text: $searchQuery)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 300)
                    }
                    VStack {
                        Text("Top Results")
                        TextField("Top Results", value: $searchResultsCount, formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    Button("Search") {
                        Task {
                            await searchIndexWithQuery(query: searchQuery, top: searchResultsCount)
                        }
                    }
                    .disabled(folderContents == nil || folderTextChunks == nil || similarityIndex == nil)
                    .keyboardShortcut(.return)
                }

                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    SearchResultTableView(searchResults: $searchResults, searchQuery: $searchQuery)
                }
            }

            .frame(minWidth: 400)
            .padding()
        }
        .navigationTitle("SimilaritySearchKit Example: Chat With Files")
        .onAppear {
            columnVisibility = .all
            updateIndexComponents()
        }
        .toolbar {
            ToolbarItem(id: "export") {
                HStack {
                    Button("Export Index For Pinecone") {
                        print("Export Index For Pinecone")
                        guard let index = similarityIndex else { return }
                        exportIndex(index)
                    }
                    .disabled(similarityIndex == nil)
                }
            }
        }
    }

    private func updateIndexComponents() {
        switch currentModel {
        case .distilbert:
            embeddingModel = DistilbertEmbeddings()
            currentTokenizer = BertTokenizer()
        case .minilmAll:
            embeddingModel = MiniLMEmbeddings()
            currentTokenizer = BertTokenizer()
        case .minilmMultiQA:
            embeddingModel = MultiQAMiniLMEmbeddings()
            currentTokenizer = BertTokenizer()
        case .native:
            embeddingModel = NativeContextualEmbeddings()
            currentTokenizer = NativeTokenizer()
        }

        switch comparisonAlgorithm {
        case .dotproduct:
            distanceMetric = DotProduct()
        case .cosine:
            distanceMetric = CosineSimilarity()
        case .euclidian:
            distanceMetric = EuclideanDistance()
        }

        switch chunkMethod {
        case .token:
            currentSplitter = TokenSplitter(withTokenizer: currentTokenizer)
        case .character:
            currentSplitter = CharacterSplitter(withSeparator: " ")
        case .recursive:
            currentSplitter = RecursiveTokenSplitter(withTokenizer: currentTokenizer)
        }
    }

    private func fetchFolderContents() async {
        guard !filePickerURLs.isEmpty else { return }
        isLoading = true
        progressStage = "Scanning"
        progressTotal = Double(filePickerURLs.count)
        progressCurrent = 0
        var folderContentsToShow: [DiskItem] = []
        let elapsedTime = await clock.measure {
            for url in filePickerURLs {
                progressCurrent += 1
                let isDirectory = Files.isDirectory(url: url)
                if isDirectory {
                    folderItem = await files.scanDirectory(url: url)
                    if let folder = folderItem {
                        folderContentsToShow.append(folder)
                    }
                } else {
                    if let childItem = await files.scanFile(url: url) {
                        folderContentsToShow.append(childItem)
                    }
                }
            }
        }
        folderScanTime = elapsedTime
        folderContents = folderContentsToShow.sorted(by: { item1, item2 in
            item1.diskSize > item2.diskSize
        })
        isLoading = false
    }

    func getTokenLength(_ text: String) -> Int {
        // Arbitrary code to get the token length of the given text
        return BertTokenizer().tokenize(text: text).count
    }

    private func splitTextFromFiles() async {
        isLoading = true
        progressStage = "Splitting"
        progressCurrent = 0

        let elapsedTime = clock.measure {
            guard let folderContents = folderContents else { return }
            let fileInfoArray: [Files.FileTextContents] = Files.extractText(fromDiskItems: folderContents)

            // Create an empty array to store the chunked FileTextContents objects
            var chunkedFileInfoArray: [Files.FileTextContents] = []
            var chunkTextArray: [String] = []
            var chunkTokensArray: [[String]] = []
            var chunkTextIds: [UUID] = []
            var chunkTextMetadata: [[String: String]] = []

            progressTotal = Double(fileInfoArray.count)
            for fileInfo in fileInfoArray {
                progressCurrent += 1
                let (chunks, tokens) = currentSplitter.split(text: fileInfo.text, chunkSize: chunkSize, overlapSize: chunkOverlap)
                for (idx, chunk) in chunks.enumerated() {
                    // needs a fixed UUID every time
                    let uuid = UUID()
                    let newFileInfo = Files.FileTextContents(id: uuid, text: chunk, fileUrl: fileInfo.fileUrl)
                    chunkedFileInfoArray.append(newFileInfo)
                    chunkTextArray.append(chunk)
                    chunkTokensArray.append(tokens?[idx] ?? currentTokenizer.tokenize(text: chunk))
                    chunkTextIds.append(uuid)
                    chunkTextMetadata.append(["source": fileInfo.fileUrl.absoluteString])
                }
            }

            // Calculate the total number of characters and tokens
            var totalCharacters = 0
            var totalTokens = 0
            for chunk in chunkTextArray {
                totalCharacters += chunk.count
            }
            for tokens in chunkTokensArray {
                totalTokens += tokens.count
            }

            // Calculate the average chunk text length
            let averageChunkTextLength = Double(totalCharacters) / Double(chunkTextArray.count)
            let averageChunkTokenLength = Double(totalTokens) / Double(chunkTokensArray.count)
            print("Average chunk character length: \(averageChunkTextLength)")
            print("Average chunk token length: \(averageChunkTokenLength)")

            print("Total characters: \(totalCharacters)")
            print("Total tokens: \(totalTokens)")

            folderCharactersCount = totalCharacters
            folderTokensCount = totalTokens

            print("Split \(fileInfoArray.count) files into \(chunkTextArray.count) chunks")

            folderTextIds = chunkTextIds.map { $0.uuidString }
            folderTextChunks = chunkTextArray
            folderTextMetadata = chunkTextMetadata
        }

        textSplitTime = elapsedTime

        isLoading = false
    }

    private func generateIndexFromChunks() async {
        guard let folderTextIds = folderTextIds,
            let folderTextChunks = folderTextChunks,
            let folderTextMetadata = folderTextMetadata else { return }

        isLoading = true
        progressStage = "Vectorizing"
        progressCurrent = 0.0
        progressTotal = Double(folderTextChunks.count)
        // Loads the model, can be done ahead of time
        let elapsedTime = await clock.measure {
            let index = await SimilarityIndex(model: embeddingModel, metric: distanceMetric)

            await index.addItems(ids: folderTextIds, texts: folderTextChunks, metadata: folderTextMetadata) { _ in
                progressCurrent += 1
            }

            print("Built index with \(index.indexItems.count) items")

            similarityIndex = index
        }

        embeddingElapsedTime = elapsedTime

        isLoading = false
    }

    private func searchIndexWithQuery(query: String, top: Int) async {
        isSearching = true

        let elapsedTime = await clock.measure {
            let results = await similarityIndex?.search(query, top: top, metric: distanceMetric)
            searchResults = results
        }

        searchElapsedTime = elapsedTime

        isSearching = false
    }

    struct PineconeExport: Codable {
        let vectors: [PineconeIndexItem]
    }

    struct PineconeIndexItem: Codable {
        let id: String
        let metadata: [String: String]
        let values: [Float]
    }

    func exportIndex(_ index: SimilarityIndex) {
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
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = "\(index.indexName)_\(String(describing: currentModel))_\(index.dimension).json"
            savePanel.allowedContentTypes = [.json]
            savePanel.allowsOtherFileTypes = false
            savePanel.canCreateDirectories = true

            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    do {
                        try data.write(to: url)
                    } catch {
                        print("Error writing index to file:", error)
                    }
                }
            }
        } catch {
            print("Error encoding index:", error)
        }
    }
}

struct DiskItemTableView: View {
    @Binding var folderContents: [DiskItem]?
    var folderContentsSize: UInt64 {
        return folderContents?.reduce(UInt64(0)) { totalSize, diskItem in
            totalSize + UInt64(diskItem.diskSize)
        } ?? 0
    }

    var body: some View {
        let folderChildren: [DiskItem] = folderContents ?? []
        Table(folderChildren) {
            TableColumn("Name", value: \.fileUrl.lastPathComponent)
            TableColumn("Size") { diskItem in
                Text("\(ByteCountFormatter.string(fromByteCount: diskItem.diskSize, countStyle: .file))  (\(String(format: "%.1f", (Double(diskItem.diskSize) / Double(folderContentsSize)) * 100))%)")
            }.width(200)
        }
    }
}

struct SearchResultTableView: View {
    @Binding var searchResults: [SimilarityIndex.SearchResult]?
    @Binding var searchQuery: String
    @State private var selectedResult: SimilarityIndex.SearchResult?
    @State private var selectedResultId: SimilarityIndex.SearchResult.ID?
    @State private var sortOrder = [KeyPathComparator(\SimilarityIndex.SearchResult.score)]
    @State private var showPopover: Bool = false

    var body: some View {
        VStack {
            Table(searchResults ?? [], selection: $selectedResultId, sortOrder: $sortOrder) {
                TableColumn("Score") { result in
                    Text("\(result.score)")
                }.width(100)
                TableColumn("Text") { result in
                    Text(result.text)
                }
                TableColumn("Source") { result in
                    Text(URL(fileURLWithPath: result.metadata["source"]!).lastPathComponent)
                }
            }
            .onChange(of: selectedResultId) { _ in
                if let result = searchResults?.first(where: { $0.id == selectedResultId }) {
                    showPopover = true
                    selectedResult = result
                }
            }
            .popover(isPresented: $showPopover, attachmentAnchor: .point(.trailing)) {
                VStack {
                    Text(selectedResult?.text ?? "")
                        .lineLimit(nil)
                        .padding()
                    Spacer()
                    HStack {
                        Button("Close") {
                            showPopover = false
                        }
                        Button("Copy") {
                            showPopover = false
                            let text = selectedResult?.text ?? ""
                            let pasteboard = NSPasteboard.general
                            pasteboard.declareTypes([.string], owner: nil)
                            pasteboard.setString(text, forType: .string)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: 1200)
            }
            HStack {
                Button("Copy All Text") {
                    let allText = searchResults?.map { $0.text }.joined(separator: "\n") ?? ""
                    let pasteboard = NSPasteboard.general
                    pasteboard.declareTypes([.string], owner: nil)
                    pasteboard.setString(allText, forType: .string)
                }
                .disabled(searchResults == nil)

                Button("Copy LLM Prompt") {
                    let allText = searchResults?.map { "\($0.text)\nSOURCES: \($0.metadata["source"] ?? "")" }.joined(separator: "\n") ?? ""
                    let prompt =
                        """
                        Given the following extracted parts of a long document and a question, create a final answer with references ("SOURCES").
                        If you don't know the answer, just say that you don't know. Don't try to make up an answer.
                        ALWAYS return a "SOURCES" part in your answer.

                        QUESTION: \(searchQuery)
                        =========
                        \(allText)
                        =========
                        FINAL ANSWER:
                        """
                    let pasteboard = NSPasteboard.general
                    pasteboard.declareTypes([.string], owner: nil)
                    pasteboard.setString(prompt, forType: .string)
                }
                .disabled(searchResults == nil)
            }
        }
    }
}

struct SimilaritySearchExampleSwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        ChatWithFilesExampleSwiftUIView()
    }
}
