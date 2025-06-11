//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Darwin
import Foundation

@main
final class SampleApp {
    static func main() throws {
        let app = SampleApp()
        try app.run()
    }

    func run() throws {
        try basicUsageExample()
        try migrationWithDeprecationExample()
        try customNamingExample()
        threadSafePropertiesExample()
    }

    // MARK: - Basic Usage

    private func basicUsageExample() throws {
        let fileURL = URL(string: "https://example.com")!
        let data = try NetworkManager().downloadFile(url: fileURL)
        print("Basic Usage - downloaded data size: \(data.count)")
    }

    // MARK: - Migration with Deprecation

    private func migrationWithDeprecationExample() throws {
        let service = LegacyService()
        let result = try service.processData()
        print("Migration with Deprecation - result: \(result)")
    }

    // MARK: - Custom Naming

    private func customNamingExample() throws {
        let token = try APIClient().sync_authenticate()
        print("Custom Naming - token: \(token)")
    }

    // MARK: - Thread-Safe Properties

    private func threadSafePropertiesExample() {
        let state = SharedState()
        print("Thread-Safe Properties - counter: \(state.counter)")
        state.incrementCounter()
        print("Thread-Safe Properties - counter: \(state.counter)")
        state.items.append("Item1")
        print("Thread-Safe Properties - items: \(state.items)")
    }
}
