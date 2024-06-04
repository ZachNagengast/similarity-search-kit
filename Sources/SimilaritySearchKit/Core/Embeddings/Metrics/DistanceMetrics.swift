//
//  DistanceMetrics.swift
//
//
//  Created by Zach Nagengast on 4/7/23.
//

import Accelerate
import Foundation

/// A struct implementing the `DistanceMetricProtocol` using the dot product.
///
/// Dot product is a similarity metric that measures the similarity between two vectors by calculating the sum of their corresponding products. It is well-suited for dense embeddings and when the magnitude of the embeddings does not impact the similarity.
///
/// - Note: Use this metric when the magnitudes of the embeddings are not significant in your use case.
public struct DotProduct: DistanceMetricProtocol {
    public init() {}

    public func findNearest(for queryEmbedding: [Float], in neighborEmbeddings: [[Float]], resultsCount: Int) -> [(Float, Int)] {
        let scores = neighborEmbeddings.map { distance(between: queryEmbedding, and: $0) }
        return sortedScores(scores: scores, topK: resultsCount)
    }

    public func distance(between firstEmbedding: [Float], and secondEmbedding: [Float]) -> Float {
        // Ensure the embeddings have the same length
        if firstEmbedding.count != secondEmbedding.count {
            print("Embeddings must have the same length")
            return -Float.greatestFiniteMagnitude
        }

        var dotProduct: Float = 0

        // Calculate dot product using Accelerate
        vDSP_dotpr(firstEmbedding, 1, secondEmbedding, 1, &dotProduct, vDSP_Length(firstEmbedding.count))

        return dotProduct
    }
}

/// A struct implementing the `DistanceMetricProtocol` using cosine similarity.
///
/// Cosine similarity is a metric that measures the cosine of the angle between two vectors. It is well-suited for sparse embeddings and when the magnitude of the embeddings impacts the similarity.
///
/// - Note: Use this metric when the magnitudes of the embeddings are significant in your use case and for sparse embeddings.
public struct CosineSimilarity: DistanceMetricProtocol {
    public init() {}

    public func findNearest(for queryEmbedding: [Float], in neighborEmbeddings: [[Float]], resultsCount: Int) -> [(Float, Int)] {
        let scores = neighborEmbeddings.map { distance(between: queryEmbedding, and: $0) }
        return sortedScores(scores: scores, topK: resultsCount)
    }

    public func distance(between firstEmbedding: [Float], and secondEmbedding: [Float]) -> Float {
        // Ensure the embeddings have the same length
        if firstEmbedding.count != secondEmbedding.count {
            print("Embeddings must have the same length")
            return -1
        }

        var dotProduct: Float = 0
        var firstMagnitude: Float = 0
        var secondMagnitude: Float = 0

        // Calculate dot product and magnitudes using Accelerate
        vDSP_dotpr(firstEmbedding, 1, secondEmbedding, 1, &dotProduct, vDSP_Length(firstEmbedding.count))
        vDSP_svesq(firstEmbedding, 1, &firstMagnitude, vDSP_Length(firstEmbedding.count))
        vDSP_svesq(secondEmbedding, 1, &secondMagnitude, vDSP_Length(secondEmbedding.count))

        // Take square root of magnitudes
        firstMagnitude = sqrt(firstMagnitude)
        secondMagnitude = sqrt(secondMagnitude)

        // Return cosine similarity
        return dotProduct / (firstMagnitude * secondMagnitude)
    }
}

/// A struct implementing the `DistanceMetricProtocol` using Euclidean distance.
///
/// Euclidean distance is a metric that measures the distance between two points in a Euclidean space. It is well-suited for cases where the embeddings are well-distributed in the vector space and when magnitudes of the embeddings impact the similarity.
///
/// - Note: Use this metric when the magnitudes of the embeddings are significant in your use case, and the embeddings are distributed in a Euclidean space.
public struct EuclideanDistance: DistanceMetricProtocol {
    public init() {}

    public func findNearest(for queryEmbedding: [Float], in neighborEmbeddings: [[Float]], resultsCount: Int) -> [(Float, Int)] {
        let distances = neighborEmbeddings.map { distance(between: queryEmbedding, and: $0) }
        return sortedDistances(distances: distances, topK: resultsCount)
    }

    public func distance(between firstEmbedding: [Float], and secondEmbedding: [Float]) -> Float {
        // Ensure the embeddings have the same length
        if firstEmbedding.count != secondEmbedding.count {
            print("Embeddings must have the same length")
            return Float.greatestFiniteMagnitude
        }

        var distance: Float = 0

        // Calculate squared differences and sum them using Accelerate
        vDSP_distancesq(firstEmbedding, 1, secondEmbedding, 1, &distance, vDSP_Length(firstEmbedding.count))

        // Return the square root of the summed squared differences
        return sqrt(distance)
    }
}

// MARK: - Helpers

/// Helper function to sort scores and return the top K scores with their indices.
///
/// - Parameters:
///   - scores: An array of Float values representing scores.
///   - topK: The number of top scores to return.
///
/// - Returns: An array of tuples containing the top K scores and their corresponding indices.
public func sortedScores(scores: [Float], topK: Int) -> [(Float, Int)] {
    // Combine indices & scores
    let indexedScores = scores.enumerated().map { index, score in (score, index) }

    // Sort by decreasing score
    func compare(a: (Float, Int), b: (Float, Int)) throws -> Bool {
        return a.0 > b.0
    }

    // Take top k neighbors
    do {
        return try indexedScores.topK(topK, by: compare)
    } catch {
        print("There has been an error comparing elements in sortedScores")
        return []
    }
}

/// Helper function to sort distances and return the top K distances with their indices.
///
/// - Parameters:
///   - distances: An array of Float values representing distances.
///   - topK: The number of top distances to return.
///
/// - Returns: An array of tuples containing the top K distances and their corresponding indices.
public func sortedDistances(distances: [Float], topK: Int) -> [(Float, Int)] {
    // Combine indices & distances
    let indexedDistances = distances.enumerated().map { index, score in (score, index) }

    // Sort by increasing distance
    func compare(a: (Float, Int), b: (Float, Int)) throws -> Bool {
        return a.0 < b.0
    }

    // Take top k neighbors
    do {
        return try indexedDistances.topK(topK, by: compare)
    } catch {
        print("There has been an error comparing elements in sortedDistances")
        return []
    }
}
