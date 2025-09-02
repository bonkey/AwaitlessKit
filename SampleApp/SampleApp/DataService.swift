//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

// MARK: - User

struct User {
    let name: String
}

// MARK: - DataService

@Awaitlessable
protocol DataService {
    func fetchUser(id: String) async throws -> User
}

// MARK: - MockDataService

class MockDataService: DataService {
    /// The async version required by the protocol
    func fetchUser(id: String) async throws -> User {
        try await Task.sleep(nanoseconds: 1_000_000)
        return User(name: "Mock User")
    }

    // The sync version is provided by the protocol extension above
}
