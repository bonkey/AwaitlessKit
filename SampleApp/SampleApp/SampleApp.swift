//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Combine
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
        try protocolExample()
        combineExample()
        freestandingMacroExample()
    }

    // MARK: - Basic Sync Wrapper Generation

    private func basicUsageExample() throws {
        let fileURL = URL(string: "https://example.com")!
        let data = try NetworkManager().downloadFile(url: fileURL)
        print("Basic Usage - downloaded data size: \(data.count)")
    }

    // MARK: - Deprecation Strategy for Legacy Code

    private func migrationWithDeprecationExample() throws {
        let service = LegacyService()
        let result = try service.processData()
        print("Migration with Deprecation - result: \(result)")
    }

    // MARK: - Custom Function Prefixes

    private func customNamingExample() throws {
        let token = try APIClient().sync_authenticate()
        print("Custom Naming - token: \(token)")
    }

    // MARK: - Actor-Safe Property Access

    private func threadSafePropertiesExample() {
        let state = SharedState()
        print("Thread-Safe Properties - counter: \(state.counter)")
        state.incrementCounter()
        print("Thread-Safe Properties - counter: \(state.counter)")
        state.items.append("Item1")
        print("Thread-Safe Properties - items: \(state.items)")
    }

    // MARK: - Protocol Extension Generation

    private func protocolExample() throws {
        let dataService: DataService = MockDataService()
        // Call the synchronous version of the method, available via the @Awaitless macro on the protocol
        let user = try dataService.fetchUser(id: "123")
        print("Protocol Example - user: \(user.name)")
    }

    // MARK: - Publisher Generation from Async Functions

    private func combineExample() {
        let combineService = CombineService()
        var cancellables = Set<AnyCancellable>()

        print("Combine Example - Subscribing to fetchItems publisher...")
        combineService.fetchItems()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("Combine Example - Publisher finished.")
                case let .failure(error):
                    print("Combine Example - Publisher failed with error: \(error)")
                }
            }, receiveValue: { items in
                print("Combine Example - Received items: \(items)")
            })
            .store(in: &cancellables)

        // In a real app, you'd manage the lifecycle of cancellables.
        // Here we just let it run. A sleep is needed to see output in a simple command-line tool.
        Thread.sleep(forTimeInterval: 0.1)
    }

    // MARK: - Expression-Level Sync Conversion

    private func freestandingMacroExample() {
        let service = FreestandingMacroService()
        let number = #awaitless(service.getNumber())
        print("Freestanding Macro Example - number: \(number)")
    }
}
