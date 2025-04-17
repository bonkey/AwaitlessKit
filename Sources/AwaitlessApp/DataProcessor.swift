import AwaitlessKit
import Foundation

final class DataProcessor {
    @ForceSync
    private func processRiskyData() async throws -> String {
        print("Starting async operation...")
        try await Task.sleep(for: .seconds(0.3))
        let result = "👍 Processed data from processRiskyData"
        try await Task.sleep(for: .seconds(0.5))
        print("Async operation completed")
        return result
    }

    @ForceSync
    private func processSafeData() async -> String {
        print("Starting async operation...")
        try? await Task.sleep(for: .seconds(0.3))
        let result = "👍 Processed data from processSafeData"
        try? await Task.sleep(for: .seconds(0.5))
        print("Async operation completed")
        return result
    }

    func run() throws {
        let processedRiskyData = try forceSync_processRiskyData()
        let processedSafeData = forceSync_processSafeData()

        print(processedRiskyData)
        print(processedSafeData)
    }
}
