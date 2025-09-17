//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class LegacyService: Sendable {
    @Awaitless(.deprecated("Use async version. Sync version will be removed in future releases."))
    func processData() async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000)
        return "Processed"
    }
}
