//
//  ContentView.swift
//  BasicExample
//
//  Created by Zach Nagengast on 4/25/23.
//

import SwiftUI
import SimilaritySearchKit
import SimilaritySearchKitMiniLMAll

struct ContentView: View {
    @State private var indexSentence1: String = "This is a test sentence"
    @State private var indexSentence2: String = "This is also a similar test sentence"
    @State private var indexSentence3: String = "Unrelated junk which should score low"
    @State private var querySentence: String = ""
    @State private var similarityResults: [SearchResult] = []
    @State private var similarityIndex: SimilarityIndex?
    @State private var similarityIndexComparison: SimilarityIndex?

    func loadIndex() async {
        var model: any EmbeddingsProtocol = MiniLMEmbeddings()

        similarityIndex = await SimilarityIndex(
            model: model,
            metric: CosineSimilarity()
        )
    }

    private func searchSimilarity() async {
        guard let index = similarityIndex else { return }
        index.indexItems = []

        await index.addItem(id: "id1", text: indexSentence1, metadata: ["source": "BasicExample"])
        await index.addItem(id: "id2", text: indexSentence2, metadata: ["source": "BasicExample"])
        await index.addItem(id: "id3", text: indexSentence3, metadata: ["source": "BasicExample"])

        let results = await index.search(querySentence)
        similarityResults = results
    }

    var body: some View {
        VStack {
            TextField("Index sentence 1", text: $indexSentence1)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextField("Index sentence 2", text: $indexSentence2)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextField("Index sentence 3", text: $indexSentence3)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextField("Query sentence", text: $querySentence)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .background(Color.green.opacity(0.2))
                .cornerRadius(5)

            Button("Run Similarity Search") {
                Task {
                    await searchSimilarity()
                }
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
            .padding()

            List(similarityResults, id: \.id) { result in
                Text("Score: \(result.score)\nText: \(result.text)")
            }
            .padding()
            .onAppear {
                Task {
                    await loadIndex()
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
