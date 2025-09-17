//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class IsolatedSafeState: Sendable {
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

    func incrementCounter() {
        counter += 1
    }

    func addItem(_ item: String) {
        items.append(item)
    }

    func getCurrentItems() -> [String] {
        return items
    }

    func updateCriticalData(_ data: Data) {
        criticalData = data
    }

    func cacheUser(id: String, name: String) {
        userCache[id] = name
    }

    func getCachedUser(id: String) -> String? {
        return userCache[id]
    }

    func getStats() -> (counter: Int, itemsCount: Int, hasData: Bool) {
        return (counter, items.count, criticalData != nil)
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
}