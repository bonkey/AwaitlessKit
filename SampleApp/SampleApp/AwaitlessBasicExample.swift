//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class AwaitlessBasicExample: Sendable {
    @Awaitless
    func downloadFile(url: URL) async throws -> Data {
        await simulateProcessing()
        let content = "Mock file content from \(url.absoluteString)"
        return content.data(using: .utf8) ?? Data()
    }

    @Awaitless(prefix: "deprecated_", .deprecated("Use async version instead"))
    func processData(_ data: Data) async -> String {
        await simulateProcessing()
        return "Processed \(data.count) bytes"
    }

    @Awaitless(prefix: "blocking_")
    func validateInput(_ input: String) async throws -> Bool {
        await simulateProcessing()
        return !input.isEmpty && input.count >= 3
    }

    @Awaitless(prefix: "unavailable_", .unavailable("This method is no longer available in sync form"))
    func computeHash(_ data: Data) async -> String {
        await simulateProcessing()
        return String(data.hashValue)
    }
}
