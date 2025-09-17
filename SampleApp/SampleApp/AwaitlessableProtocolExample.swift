//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

struct UserProfile {
    let id: String
    let name: String
    let email: String
}

struct ApiResponse {
    let data: Data
    let statusCode: Int
}

@Awaitlessable
protocol AwaitlessableProtocolExample: Sendable {
    func fetchUserProfile(id: String) async throws -> UserProfile
    func fetchRawData(endpoint: String) async throws -> ApiResponse
    func updateUserProfile(_ profile: UserProfile) async throws -> Bool
    func deleteUser(id: String) async -> Bool
}

final class MockRepositoryExample: AwaitlessableProtocolExample {
    func fetchUserProfile(id: String) async throws -> UserProfile {
        await simulateProcessing()
        return UserProfile(
            id: id,
            name: "Mock User \(id)",
            email: "user\(id)@example.com"
        )
    }
    
    func fetchRawData(endpoint: String) async throws -> ApiResponse {
        await simulateProcessing()
        let mockData = "Mock data from \(endpoint)".data(using: .utf8) ?? Data()
        return ApiResponse(data: mockData, statusCode: 200)
    }
    
    func updateUserProfile(_ profile: UserProfile) async throws -> Bool {
        await simulateProcessing()
        return true
    }
    
    func deleteUser(id: String) async -> Bool {
        await simulateProcessing()
        return id != "protected"
    }
}

final class RemoteRepositoryExample: AwaitlessableProtocolExample {
    func fetchUserProfile(id: String) async throws -> UserProfile {
        await simulateProcessing()
        return UserProfile(
            id: id,
            name: "Remote User \(id)",
            email: "remote\(id)@api.com"
        )
    }
    
    func fetchRawData(endpoint: String) async throws -> ApiResponse {
        await simulateProcessing()
        let remoteData = "Remote API response from \(endpoint)".data(using: .utf8) ?? Data()
        return ApiResponse(data: remoteData, statusCode: 200)
    }
    
    func updateUserProfile(_ profile: UserProfile) async throws -> Bool {
        await simulateProcessing()
        return true
    }
    
    func deleteUser(id: String) async -> Bool {
        await simulateProcessing()
        return true
    }
}