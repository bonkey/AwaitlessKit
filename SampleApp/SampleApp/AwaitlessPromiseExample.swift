//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation
@preconcurrency import PromiseKit

// Import the PromiseKit integration - this would be used by consumers
#if canImport(AwaitlessKitPromiseKit)
@preconcurrency import AwaitlessKitPromiseKit
#endif

final class AwaitlessPromiseExample: Sendable {
    
    // MARK: - @AwaitlessPromise Examples (async -> Promise)
    
    @AwaitlessPromise
    func fetchUserData(id: String) async throws -> UserProfile {
        await simulateProcessing()
        if id == "error" {
            throw NSError(domain: "Demo", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        return UserProfile(id: id, name: "User \(id)", email: "\(id)@example.com")
    }
    
    @AwaitlessPromise(prefix: "promise_")
    func downloadFile(url: URL) async throws -> Data {
        await simulateProcessing()
        // Simulate download with mock content
        let content = "Mock file content from \(url.absoluteString)"
        return content.data(using: .utf8) ?? Data()
    }
    
    @AwaitlessPromise(prefix: "legacy_", .deprecated("Use async version instead"))
    func processData(_ data: Data) async -> String {
        await simulateProcessing()
        return "Processed \(data.count) bytes with PromiseKit compatibility"
    }
    
    @AwaitlessPromise
    func validateInput(_ input: String) async throws -> Bool {
        await simulateProcessing()
        if input.isEmpty {
            throw ValidationError.emptyInput
        }
        return input.count >= 3
    }
    
    @AwaitlessPromise(prefix: "void_")
    func saveConfiguration(_ config: [String: String]) async throws -> Void {
        await simulateProcessing()
        // Simulate save operation
        if config.isEmpty {
            throw ValidationError.invalidConfig
        }
    }
    
    // MARK: - @Awaitable Examples (Promise -> async)
    
    @Awaitable
    func legacyFetchUser(id: String) -> Promise<UserProfile> {
        return Promise { seal in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                if id == "error" {
                    seal.reject(NSError(domain: "LegacyDemo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Legacy user not found"]))
                } else {
                    seal.fulfill(UserProfile(id: id, name: "Legacy User \(id)", email: "legacy.\(id)@example.com"))
                }
            }
        }
    }
    
    @Awaitable(prefix: "async_")
    func legacyDownloadData(endpoint: String) -> Promise<Data> {
        return Promise.value("Legacy data from \(endpoint)".data(using: .utf8) ?? Data())
    }
    
    @Awaitable(.deprecated("Migrate to async version"))
    func legacyProcessFile(path: String) -> Promise<String> {
        return Promise { seal in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                seal.fulfill("Legacy processed file: \(path)")
            }
        }
    }
    
    @Awaitable(prefix: "modern_", .unavailable("Use the new async API"))
    func legacyComputeHash(_ data: Data) -> Promise<String> {
        return Promise.value(String(data.hashValue))
    }
    
    @Awaitable
    func legacyVoidOperation() -> Promise<Void> {
        return Promise { seal in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) {
                seal.fulfill(())
            }
        }
    }
    
    // MARK: - Complex scenarios demonstrating both directions
    
    @AwaitlessPromise(prefix: "hybrid_")
    func complexAsyncOperation(input: String, retries: Int) async throws -> ComplexResult {
        await simulateProcessing()
        
        if input == "fail" && retries == 0 {
            throw ProcessingError.operationFailed
        }
        
        return ComplexResult(
            data: "Complex result for: \(input)",
            metadata: ["retries": String(retries), "timestamp": String(Date().timeIntervalSince1970)],
            isSuccess: true
        )
    }
    
    @Awaitable(prefix: "migrated_")
    func legacyComplexOperation(parameters: [String: String]) -> Promise<ComplexResult> {
        return Promise { seal in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                let result = ComplexResult(
                    data: "Legacy complex result",
                    metadata: parameters,
                    isSuccess: true
                )
                seal.fulfill(result)
            }
        }
    }
}

// MARK: - Supporting Types

struct UserProfile: Codable, CustomStringConvertible {
    let id: String
    let name: String
    let email: String
    
    var description: String {
        return "\(name) (\(email))"
    }
}

struct ComplexResult: CustomStringConvertible {
    let data: String
    let metadata: [String: String]
    let isSuccess: Bool
    
    var description: String {
        return "ComplexResult(data: \(data), success: \(isSuccess), metadata: \(metadata.count) items)"
    }
}

enum ValidationError: Error, LocalizedError {
    case emptyInput
    case invalidConfig
    
    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Input cannot be empty"
        case .invalidConfig:
            return "Configuration is invalid"
        }
    }
}

enum ProcessingError: Error, LocalizedError {
    case operationFailed
    
    var errorDescription: String? {
        switch self {
        case .operationFailed:
            return "Operation failed after retries"
        }
    }
}