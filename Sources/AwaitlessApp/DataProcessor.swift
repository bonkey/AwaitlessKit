//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class DataProcessor: Sendable {
    func run() throws {
        for string in strings {
            print(string)
        }

        #awaitless(processSomething())
        
        let processedRiskyData1 = try #awaitless(try processRiskyData())
        let processedRiskyData2 = try awaitless_processRiskyData()
        
        let processedSafeData1 = #awaitless(processSafeData())
        let processedSafeData2 = awaitless_processSafeData()

        print(processedRiskyData1)
        print(processedRiskyData2)
        print(processedSafeData1)
        print(processedSafeData2)
    }

    @IsolatedSafe
    private nonisolated(unsafe) var _unsafeStrings: [String] = ["Hello", "World"]
    
    @IsolatedSafe(writable: true)
    private nonisolated(unsafe) var _unsafeProcessCount: Int = 0

    @Awaitless
    private func processSomething() async {
        _ = try? await processData()
    }

    @Awaitless
    private func processRiskyData() async throws -> String {
        try await processData()
    }

    @Awaitless
    private func processSafeData() async -> String {
        await (try? processData()) ?? "NO DATA"
    }

    @discardableResult
    private func processData() async throws -> String {
        processCount += 1
        let waitTime = round(Double.random(in: 0...0.7) * 10) / 10
        
        print("🚥 Starting async operation #\(processCount)... (\(waitTime)s)")
        try await Task.sleep(for: .seconds(waitTime))
        let result = "👍 Processed data from processData (count: \(processCount))"
        print("🏁 Async operation #\(processCount) completed")
        return result
    }
}
