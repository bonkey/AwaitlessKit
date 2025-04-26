//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class DataProcessor: Sendable {
    @Awaitless(.deprecated())
    func asyncFunctionWithAwaitlessDeprecated() async {
        _ = try? await processData()
    }

    func custom_asyncThrowingFunction() throws -> String {
        try Noasync.run {
            try await asyncThrowingFunctionWithAwaitlessCustomPrefix()
        }
    }

    @Awaitless(prefix: "awaitless_")
    func asyncThrowingFunctionWithAwaitlessCustomPrefix() async throws -> String {
        try await processData()
    }

    @Awaitless
    func asyncFunctionWithAwaitlessDefault() async -> String {
        await (try? processData()) ?? "NO DATA"
    }

    @IsolatedSafe
    private nonisolated(unsafe) var _unsafeStrings: [String] = ["Hello", "World"]

    @IsolatedSafe(writable: true)
    private nonisolated(unsafe) var _unsafeProcessCount: Int = 0

    @discardableResult
    private func processData() async throws -> String {
        processCount += 1
        let waitTime = round(Double.random(in: 0 ... 0.7) * 10) / 10

        print("🚥 Starting async operation #\(processCount)... (\(waitTime)s)")
        try await Task.sleep(for: .seconds(waitTime))
        let result = "👍 Processed data from processData (count: \(processCount))"
        print("🏁 Async operation #\(processCount) completed")
        return result
    }
}
