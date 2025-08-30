//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

struct User {
    let name: String
}

@Awaitlessable
protocol DataService {
    func fetchUser(id: String) async throws -> User
}

extension DataService {
    // Default sync implementation using Noasync.run
    func fetchUser(id: String) throws -> User {
        try Noasync.run {
            try await fetchUser(id: id)
        }
    }
}

class MockDataService: DataService {
    // The async version required by the protocol
    func fetchUser(id: String) async throws -> User {
        try await Task.sleep(nanoseconds: 1_000_000)
        return User(name: "Mock User")
    }

    // The sync version is provided by the protocol extension above
}
