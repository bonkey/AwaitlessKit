//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

// MARK: - UserProfileExample

struct UserProfileExample {
    let id: String
    let name: String
    let email: String
}

// MARK: - ApiResponseExample

struct ApiResponseExample {
    let data: Data
    let statusCode: Int
}

// MARK: - AwaitlessableProtocolExample

@Awaitlessable
protocol AwaitlessableProtocolExample: Sendable {
    func fetchUserProfile(id: String) async throws -> UserProfileExample
    func fetchRawData(endpoint: String) async throws -> ApiResponseExample
    func updateUserProfile(_ profile: UserProfileExample) async throws -> Bool
    func deleteUser(id: String) async -> Bool
}

// MARK: - FirstAwaitlessableProtocolExample

final class FirstAwaitlessableProtocolExample: AwaitlessableProtocolExample {
    func fetchUserProfile(id: String) async throws -> UserProfileExample {
        await simulateProcessing()
        return UserProfileExample(
            id: id,
            name: "Mock User \(id)",
            email: "user\(id)@example.com")
    }

    func fetchRawData(endpoint: String) async throws -> ApiResponseExample {
        await simulateProcessing()
        let mockData = "Mock data from \(endpoint)".data(using: .utf8) ?? Data()
        return ApiResponseExample(data: mockData, statusCode: 200)
    }

    func updateUserProfile(_ profile: UserProfileExample) async throws -> Bool {
        await simulateProcessing()
        return true
    }

    func deleteUser(id: String) async -> Bool {
        await simulateProcessing()
        return id != "protected"
    }
}

// MARK: - SecondAwaitlessableProtocolExample

final class SecondAwaitlessableProtocolExample: AwaitlessableProtocolExample {
    func fetchUserProfile(id: String) async throws -> UserProfileExample {
        await simulateProcessing()
        return UserProfileExample(
            id: id,
            name: "Remote User \(id)",
            email: "remote\(id)@api.com")
    }

    func fetchRawData(endpoint: String) async throws -> ApiResponseExample {
        await simulateProcessing()
        let remoteData = "Remote API response from \(endpoint)".data(using: .utf8) ?? Data()
        return ApiResponseExample(data: remoteData, statusCode: 200)
    }

    func updateUserProfile(_ profile: UserProfileExample) async throws -> Bool {
        await simulateProcessing()
        return true
    }

    func deleteUser(id: String) async -> Bool {
        await simulateProcessing()
        return true
    }
}
