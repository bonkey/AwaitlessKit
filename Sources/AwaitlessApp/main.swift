//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit

// import AwaitlessKitMacros
import Foundation

final class DataProcessor {
    @ForceSync
    func processData() async throws -> String {
        print("Starting async operation...")
        try await Task.sleep(for: .seconds(1))
        let result = "Processed data from async context"
        try await Task.sleep(for: .seconds(1))
        print("Async operation completed")
        return result
    }

    func baz() throws {
        let processedData = try forceSync_processData()

        print(processedData)
    }
}
