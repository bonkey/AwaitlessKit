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
            throw ValidationError.userNotFound
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
    
    // MARK: - @AwaitablePromise Examples (Promise -> async)

    @AwaitablePromise
    func legacyFetchUser(id: String) -> Promise<UserProfile> {
        return Promise { seal in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                if id == "error" {
                    seal.reject(ValidationError.userNotFound)
                } else {
                    seal.fulfill(UserProfile(id: id, name: "Legacy User \(id)", email: "legacy.\(id)@example.com"))
                }
            }
        }
    }
    
    @AwaitablePromise(prefix: "async_")
    func legacyDownloadData(endpoint: String) -> Promise<Data> {
        return Promise.value("Legacy data from \(endpoint)".data(using: .utf8) ?? Data())
    }
    
    @AwaitablePromise(.deprecated("Migrate to async version"))
    func legacyProcessFile(path: String) -> Promise<String> {
        return Promise { seal in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                seal.fulfill("Legacy processed file: \(path)")
            }
        }
    }
    
    @AwaitablePromise(prefix: "modern_", .unavailable("Use the new async API"))
    func legacyComputeHash(_ data: Data) -> Promise<String> {
        return Promise.value(String(data.hashValue))
    }
    
    @AwaitablePromise
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
    
    @AwaitablePromise(prefix: "migrated_")
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

// MARK: - Individual @AwaitablePromise Class Example (Working Approach)
// Demonstrates using @AwaitablePromise on individual class methods (works perfectly)
class LegacyNetworkService {
    @AwaitablePromise(prefix: "async_")
    func fetchUserProfile(userId: String) -> Promise<UserProfile> {
        return Promise { seal in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                let profile = UserProfile(
                    id: userId,
                    name: "Network User \(userId)",
                    email: "network.\(userId)@example.com"
                )
                seal.fulfill(profile)
            }
        }
    }
    
    @AwaitablePromise(prefix: "async_")
    func uploadData(_ data: Data, to endpoint: String) -> Promise<String> {
        return Promise { seal in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                seal.fulfill("Uploaded \(data.count) bytes to \(endpoint)")
            }
        }
    }
    
    @AwaitablePromise(prefix: "async_")
    func deleteResource(id: String) -> Promise<Void> {
        return Promise { seal in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                if id == "forbidden" {
                    seal.reject(ValidationError.userNotFound)
                } else {
                    seal.fulfill(())
                }
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
        return "UserProfile(id: \(id), name: \(name), email: \(email))"
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
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Input cannot be empty"
        case .invalidConfig:
            return "Configuration is invalid"
        case .userNotFound:
            return "User not found"
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
