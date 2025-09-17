//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class AwaitlessFreestanding: Sendable {
    func getRandomNumber() async -> Int {
        await simulateProcessing()
        return Int.random(in: 1...100)
    }
    
    func computeHash(for data: String) async -> String {
        await simulateProcessing()
        return String(data.hashValue)
    }
    
    func getCurrentTimestamp() async -> Int {
        await simulateProcessing()
        return Int(Date().timeIntervalSince1970)
    }
    
    func processString(_ input: String) async -> String {
        await simulateProcessing()
        return input.uppercased()
    }
}

final class AwaitlessFreestandingUsage: Sendable {
    private let service = AwaitlessFreestanding()
    
    func syncMethodUsingAsyncCode() -> String {
        let randomNum = #awaitless(service.getRandomNumber())
        let hash = #awaitless(service.computeHash(for: "sample-data"))
        return "Random: \(randomNum), Hash: \(hash)"
    }
    
    func processDataSync() -> String {
        let processed = #awaitless(service.processString("hello world"))
        let timestamp = #awaitless(service.getCurrentTimestamp())
        return "Processed: \(processed), Time: \(timestamp)"
    }
    
    var computedProperty: Int {
        #awaitless(service.getRandomNumber())
    }
    
    func batchProcess(items: [String]) -> [String] {
        return items.map { item in
            #awaitless(service.computeHash(for: item))
        }
    }
    
    func mixedOperations() -> (hash: String, number: Int, processed: String) {
        let hash = #awaitless(service.computeHash(for: "test"))
        let number = #awaitless(service.getRandomNumber())
        let processed = #awaitless(service.processString("mixed"))
        return (hash, number, processed)
    }
}