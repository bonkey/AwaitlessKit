//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class AwaitlessBasic: Sendable {
    @Awaitless
    func downloadFile(url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    @Awaitless(.deprecated("Use async version instead"))
    func processData(_ data: Data) async -> String {
        await simulateProcessing()
        return "Processed \(data.count) bytes"
    }
    
    @Awaitless(prefix: "blocking_")
    func validateInput(_ input: String) async throws -> Bool {
        await simulateProcessing()
        return !input.isEmpty && input.count >= 3
    }
    
    @Awaitless(prefix: "sync_", .unavailable("This method is no longer available in sync form"))
    func computeHash(_ data: Data) async -> String {
        await simulateProcessing()
        return String(data.hashValue)
    }
}