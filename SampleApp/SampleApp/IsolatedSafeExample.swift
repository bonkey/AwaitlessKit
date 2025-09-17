//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class IsolatedSafeExample: Sendable {
    func incrementCounter() {
        counter += 1
    }

    func addItem(_ item: String) {
        items.append(item)
    }

    func getCurrentItems() -> [String] {
        items
    }

    func updateCriticalData(_ data: Data) {
        criticalData = data
    }

    func cacheUser(id: String, name: String) {
        userCache[id] = name
    }

    func getCachedUser(id: String) -> String? {
        userCache[id]
    }

    func getStats() -> (counter: Int, itemsCount: Int, hasData: Bool) {
        (counter, items.count, criticalData != nil)
    }

    func resetAll() {
        counter = 0
        items.removeAll()
        criticalData = nil
        userCache.removeAll()
    }

    func bulkUpdateItems(_ newItems: [String]) {
        items = newItems
    }

    @IsolatedSafe(writable: true)
    private nonisolated(unsafe) var _unsafeCounter: Int = 0

    @IsolatedSafe(writable: true, strategy: .concurrent)
    private nonisolated(unsafe) var _unsafeItems: [String] = []

    @IsolatedSafe(writable: true, queueName: "criticalDataQueue")
    private nonisolated(unsafe) var _unsafeCriticalData: Data? = nil

    @IsolatedSafe(writable: false)
    private nonisolated(unsafe) var _unsafeReadOnlyConfig: String = "initial-config"

    @IsolatedSafe(writable: true, queueName: "userCacheQueue", strategy: .serial)
    private nonisolated(unsafe) var _unsafeUserCache: [String: String] = [:]
}
