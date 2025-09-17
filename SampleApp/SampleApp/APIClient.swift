//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class APIClient: Sendable {
       @Awaitless(prefix: "sync_")
    func authenticate() async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000)
        return "Authenticated"
    }
}
