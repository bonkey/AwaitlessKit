//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class SharedState: Sendable {
    func incrementCounter() {
        counter += 1
    }

    @IsolatedSafe(writable: true)
    private nonisolated(unsafe) var _unsafeCounter: Int = 0

    @IsolatedSafe(writable: true)
    private nonisolated(unsafe) var _unsafeItems: [String] = []
}
}
