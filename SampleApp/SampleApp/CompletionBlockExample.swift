//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

// MARK: - CompletionBlock Examples

class CompletionBlockExamples {
    
    // Basic completion block generation
    @CompletionBlock
    func fetchUserData(userId: String) async throws -> UserData {
        // Simulate network request
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return UserData(id: userId, name: "User \(userId)")
    }
    
    // Custom prefix example
    @CompletionBlock(prefix: "Callback")
    func downloadFile(url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    // Void return type example
    @CompletionBlock
    func performBackgroundTask() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        print("Background task completed")
    }
    
    // Non-throwing async function
    @CompletionBlock
    func generateReport() async -> String {
        await Task.sleep(nanoseconds: 2_000_000_000)
        return "Report generated at \(Date())"
    }
    
    // Deprecated completion block
    @CompletionBlock(.deprecated("Use async version for better performance"))
    func legacyDataFetch() async throws -> [String] {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return ["item1", "item2", "item3"]
    }
    
    // Example usage of generated completion block functions
    func demonstrateUsage() {
        // Using the generated completion block function
        fetchUserDataWithCompletion(userId: "123") { result in
            switch result {
            case .success(let userData):
                print("Fetched user: \(userData.name)")
            case .failure(let error):
                print("Failed to fetch user: \(error)")
            }
        }
        
        // Using custom prefix
        if let url = URL(string: "https://example.com/file.txt") {
            downloadFileCallback(url: url) { result in
                switch result {
                case .success(let data):
                    print("Downloaded \(data.count) bytes")
                case .failure(let error):
                    print("Download failed: \(error)")
                }
            }
        }
        
        // Using void return completion
        performBackgroundTaskWithCompletion { result in
            switch result {
            case .success:
                print("Background task completed successfully")
            case .failure(let error):
                print("Background task failed: \(error)")
            }
        }
        
        // Using non-throwing completion
        generateReportWithCompletion { result in
            switch result {
            case .success(let report):
                print("Report: \(report)")
            case .failure(let error):
                print("Unexpected error: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

struct UserData {
    let id: String
    let name: String
}

