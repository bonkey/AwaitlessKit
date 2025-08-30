//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

struct User {
    let name: String
}

@Awaitless
protocol DataService {
    func fetchUser(id: String) async throws -> User
}

class MockDataService: DataService {
    // The async version required by the protocol
    func fetchUser(id: String) async throws -> User {
        try await Task.sleep(nanoseconds: 1_000_000)
        return User(name: "Mock User")
    }

    // The sync version is automatically synthesized in the protocol extension
    // by @Awaitless on the protocol. We can call it directly on any
    // type conforming to DataService.
}
