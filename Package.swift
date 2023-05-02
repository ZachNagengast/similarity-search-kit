// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SimilaritySearchKit",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "SimilaritySearchKit",
            targets: ["SimilaritySearchKit"]
        ),
        .library(
            name: "SimilaritySearchKitDistilbert",
            targets: ["SimilaritySearchKitDistilbert"]
        ),
        .library(
            name: "SimilaritySearchKitMiniLMAll",
            targets: ["SimilaritySearchKitMiniLMAll"]
        ),
        .library(
            name: "SimilaritySearchKitMiniLMMultiQA",
            targets: ["SimilaritySearchKitMiniLMMultiQA"]
        ),
    ],
    targets: [
        .target(
            name: "SimilaritySearchKit",
            dependencies: [],
            path: "Sources/SimilaritySearchKit/Core",
            resources: [.process("Resources")]
        ),
        .target(
            name: "SimilaritySearchKitDistilbert",
            dependencies: ["SimilaritySearchKit"],
            path: "Sources/SimilaritySearchKit/AddOns/Embeddings/Distilbert",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-target", "x86_64-apple-ios16.0-macabi"], .when(platforms: [.iOS])),
                .unsafeFlags(["-Xfrontend", "-target", "x86_64-apple-macosx13.0"], .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "SimilaritySearchKitMiniLMAll",
            dependencies: ["SimilaritySearchKit"],
            path: "Sources/SimilaritySearchKit/AddOns/Embeddings/MiniLMAll"
        ),
        .target(
            name: "SimilaritySearchKitMiniLMMultiQA",
            dependencies: ["SimilaritySearchKit"],
            path: "Sources/SimilaritySearchKit/AddOns/Embeddings/MiniLMMultiQA"
        ),
        .testTarget(
            name: "SimilaritySearchKitTests",
            dependencies: [
                "SimilaritySearchKit",
                "SimilaritySearchKitDistilbert",
                "SimilaritySearchKitMiniLMAll",
                "SimilaritySearchKitMiniLMMultiQA",
            ],
            path: "Tests/SimilaritySearchKitTests",
            resources: [.process("Resources")]
        ),
    ]
)
