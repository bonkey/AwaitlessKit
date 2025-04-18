//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class DataProcessor: Sendable {
    func run() throws {
        awaitless_processSomething()

        for string in strings {
            print(string)
        }

        let processedRiskyData = try awaitless_processRiskyData()
        let processedSafeData = awaitless_processSafeData()

        print(processedRiskyData)
        print(processedSafeData)
    }

    @IsolatedSafe
    private nonisolated(unsafe) var _unsafeStrings: [String] = ["Hello", "World"]

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
        print("🚥 Starting async operation...")
        try await Task.sleep(for: .seconds(0.3))
        let result = "👍 Processed data from processSafeData"
        print("🏁 Async operation completed")
        return result
    }
}
