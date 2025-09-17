//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Combine
import Foundation

final class AwaitlessPublisherExample: Sendable {
    @AwaitlessPublisher(deliverOn: .main)
    func fetchItems() async -> [String] {
        await simulateProcessing()
        return ["Item 1", "Item 2", "Item 3"]
    }

    @AwaitlessPublisher
    func loadUserData(id: String) async throws -> String {
        await simulateProcessing()
        if id == "error" {
            throw NSError(domain: "Demo", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        return "User data for \(id)"
    }

    @AwaitlessPublisher(prefix: "stream_", deliverOn: .main)
    func getCurrentTimestamp() async -> Int {
        await simulateProcessing()
        return Int(Date().timeIntervalSince1970)
    }

    @AwaitlessPublisher(deliverOn: .current)
    func processInBackground() async throws -> String {
        await simulateProcessing()
        return "Background processing complete"
    }

    @AwaitlessPublisher
    func fetchConfig() async -> [String: String] {
        await simulateProcessing()
        return ["version": "1.0.0", "env": "production"]
    }
}
