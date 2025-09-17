//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

#if canImport(Combine)
import Combine
#endif

// Import PromiseKit integration for demonstration
#if canImport(AwaitlessKitPromiseKit)
@preconcurrency import AwaitlessKitPromiseKit
@preconcurrency import PromiseKit
#endif

@main
final class SampleApp {
    static func main() async throws {
        let app = SampleApp()
        try await app.run()
    }

    func run() async throws {
        print("=== AwaitlessKit Feature Demonstrations ===\n")

        try demonstrateAwaitlessBasic()
        try demonstrateAwaitlessableProtocol()
        #if canImport(Combine)
        demonstrateAwaitlessPublisher()
        #endif
        try demonstrateAwaitlessFreestanding()
        demonstrateIsolatedSafeState()
        try demonstrateAwaitlessCompletion()
        try await demonstrateAwaitlessPromise()
        try demonstrateAwaitlessConfig()

        print("\n=== All demonstrations completed ===")
    }

    private func demonstrateAwaitlessBasic() throws {
        print("1. @Awaitless Basic Usage")

        let service = AwaitlessBasicExample()
        let url = URL(string: "https://httpbin.org/json")!

        let data = try service.downloadFile(url: url)
        print("   Downloaded: \(data.count) bytes")

        let result = service.deprecated_processData(data)
        print("   Processed: \(result)")

        let isValid = try service.blocking_validateInput("test input")
        print("   Input valid: \(isValid)")

        // unavailable
        // let hash = service.unavailable_computeHash(data)
        // print("   Hash: \(hash)")
        // print()
    }

    private func demonstrateAwaitlessableProtocol() throws {
        print("2. @Awaitlessable Protocol Generation")

        let sample1: AwaitlessableProtocolExample = FirstAwaitlessableProtocolExample()
        let sample2: AwaitlessableProtocolExample = SecondAwaitlessableProtocolExample()

        let user1 = try sample1.fetchUserProfile(id: "123")
        print("   Mock user: \(user1.name) (\(user1.email))")

        let response = try sample2.fetchRawData(endpoint: "/api/data")
        print("   Remote response: \(response.statusCode), \(response.data.count) bytes")

        let updateSuccess = try sample1.updateUserProfile(user1)
        print("   Update success: \(updateSuccess)")

        let deleteSuccess = sample2.deleteUser(id: "user456")
        print("   Delete success: \(deleteSuccess)")
        print()
    }

    #if canImport(Combine)
    private func demonstrateAwaitlessPublisher() {
        print("3. @AwaitlessPublisher Generation")

        let service = AwaitlessPublisherExample()
        var cancellables = Set<AnyCancellable>()

        service.fetchItems()
            .sink { items in
                print("   Fetched items: \(items)")
            }
            .store(in: &cancellables)

        service.loadUserData(id: "user456")
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case let .failure(error):
                        print("   User data error: \(error.localizedDescription)")
                    }
                },
                receiveValue: { data in
                    print("   User data loaded: \(data)")
                })
            .store(in: &cancellables)

        let timestamp = service.stream_getCurrentTimestamp()
        timestamp
            .sink { time in
                print("   Current timestamp: \(time)")
            }
            .store(in: &cancellables)

        service.fetchConfig()
            .sink { config in
                print("   Config: \(config)")
            }
            .store(in: &cancellables)

        Thread.sleep(forTimeInterval: 0.2)
        print()
    }
    #endif

    private func demonstrateAwaitlessFreestanding() throws {
        print("4. #awaitless Freestanding Macro")

        let service = AwaitlessBasicExample()
        let url = URL(string: "https://httpbin.org/json")!

        // Use existing async functions with #awaitless
        let data = try #awaitless(try service.downloadFile(url: url))
        print("   Downloaded via #awaitless: \(data.count) bytes")

        // Chain operations
        let result = #awaitless(service.processData(data))
        print("   Chained processing: \(result)")

        // Use in conditional
        if try #awaitless(try service.validateInput("test")) {
            print("   Conditional validation: passed")
        }

        print()
    }

    private func demonstrateIsolatedSafeState() {
        print("5. @IsolatedSafe Thread-Safe State")

        let state = IsolatedSafeExample()

        state.incrementCounter()
        state.incrementCounter()
        state.addItem("First item")
        state.addItem("Second item")

        let stats = state.getStats()
        print("   Stats: counter=\(stats.counter), items=\(stats.itemsCount), hasData=\(stats.hasData)")

        state.cacheUser(id: "u1", name: "Alice")
        state.cacheUser(id: "u2", name: "Bob")

        if let cachedUser = state.getCachedUser(id: "u1") {
            print("   Cached user: \(cachedUser)")
        }

        state.updateCriticalData("critical info".data(using: .utf8)!)
        let updatedStats = state.getStats()
        print("   Updated stats: hasData=\(updatedStats.hasData)")

        state.bulkUpdateItems(["bulk1", "bulk2", "bulk3"])
        let finalStats = state.getStats()
        print("   Final items count: \(finalStats.itemsCount)")
        print()
    }

    private func demonstrateAwaitlessCompletion() throws {
        print("6. @AwaitlessCompletion Handler Generation")

        let service = AwaitlessCompletionExample()
        let semaphore = DispatchSemaphore(value: 0)

        service.fetchData { result in
            switch result {
            case let .success(data):
                print("   Completion result: \(data)")
            case let .failure(error):
                print("   Completion error: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()

        let semaphore2 = DispatchSemaphore(value: 0)

        service.callback_processRequest("test request") { result in
            switch result {
            case let .success(success):
                print("   Request processed: \(success)")
            case .failure:
                print("   Request processed: false")
            }
            semaphore2.signal()
        }

        semaphore2.wait()
        print()
    }

    private func demonstrateAwaitlessPromise() async throws {
        #if canImport(AwaitlessKitPromiseKit)
        print("7. @AwaitlessPromise & @Awaitable PromiseKit Integration")
        
        let service = AwaitlessPromiseExample()
        
        print("   a) @AwaitlessPromise demonstrates async->Promise generation")
        print("      - @AwaitlessPromise on fetchUserData() generates Promise<UserProfile> version")
        print("      - @AwaitlessPromise on downloadFile() with prefix generates promise_downloadFile()")
        print("      - @AwaitlessPromise on saveConfiguration() handles void async functions")
        
        print("   b) @Awaitable demonstrates Promise->async generation")
        print("      - @Awaitable on legacyFetchUser() generates async throws version")
        print("      - @Awaitable with prefix on legacyDownloadData() generates async_legacyDownloadData()")
        print("      - @Awaitable with deprecation messages provides migration guidance")
        
        // Demonstrate actual usage of the @Awaitable generated functions
        do {
            let user = try await service.legacyFetchUser(id: "demo")
            print("   c) Live @Awaitable demo - fetched user: \(user)")
        } catch {
            print("   c) Live @Awaitable demo - error: \(error.localizedDescription)")
        }
        
        let data = try await service.async_legacyDownloadData(endpoint: "/test")
        print("   d) Live @Awaitable with prefix demo - downloaded: \(data.count) bytes")
        
        try await service.legacyVoidOperation()
        print("   e) Live @Awaitable void demo - operation completed")
        
        let result = try await service.migrated_legacyComplexOperation(parameters: ["demo": "value"])
        print("   f) Live @Awaitable complex demo - result: \(result)")
        
        print("   g) Both macros provide bidirectional conversion:")
        print("      - Teams can gradually migrate from PromiseKit to async/await")
        print("      - Or integrate async/await code with existing PromiseKit infrastructure")
        print("      - Availability attributes guide developers during migration")
        
        print()
        #else
        print("7. @AwaitlessPromise & @Awaitable PromiseKit Integration")
        print("   PromiseKit integration not available (requires AwaitlessKit-PromiseKit import)")
        print()
        #endif
    }

    private func demonstrateAwaitlessConfig() throws {
        print("8. AwaitlessConfig Global Configuration")

        // Show current defaults
        let initialDefaults = AwaitlessConfig.currentDefaults
        print(
            "   Initial defaults: prefix=\(initialDefaults.prefix ?? "nil"), strategy=\(String(describing: initialDefaults.strategy))")

        // Set custom global defaults
        AwaitlessConfig.setDefaults(
            prefix: "blocking_",
            availability: .deprecated("Use async version instead"),
            delivery: .main,
            strategy: .concurrent)

        let updatedDefaults = AwaitlessConfig.currentDefaults
        print(
            "   Updated defaults: prefix=\(updatedDefaults.prefix ?? "nil"), strategy=\(String(describing: updatedDefaults.strategy))")

        // Reset to default configuration
        AwaitlessConfig.setDefaults()
        let resetDefaults = AwaitlessConfig.currentDefaults
        print(
            "   Reset defaults: prefix=\(resetDefaults.prefix ?? "nil"), strategy=\(String(describing: resetDefaults.strategy))")
        print()
    }
}
