//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class SharedState: Sendable {
    @IsolatedSafe
    private nonisolated(unsafe) var _unsafeCounter: Int = 0
    
    func incrementCounter() {
        accessQueueCounter.async(flags: .barrier) {
            self._unsafeCounter += 1
        }
    }

    // Generates:
    //
    // internal var counter: Int {
    //     get {
    //         accessQueueCounter.sync {
    //             self._unsafeCounter
    //         }
    //     }
    // }

    @IsolatedSafe(writable: true)
    private nonisolated(unsafe) var _unsafeItems: [String] = []

    // Generates:
    //
    // var counter: Int { get }
    // internal var items: [String] {
    //     get {
    //         accessQueueItems.sync {
    //             self._unsafeItems
    //         }
    //     }
    //     set {
    //         accessQueueItems.async(flags: .barrier) {
    //             self._unsafeItems = newValue
    //         }
    //     }
    // }
}
