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
        print("AwaitlessKit Demo\n")

        try demonstrateAwaitlessBasic()
        try demonstrateAwaitlessableProtocol()
        demonstrateAwaitlessPublisher()
        try demonstrateAwaitlessFreestanding()
        demonstrateIsolatedSafeState()
        try demonstrateAwaitlessCompletion()
        try await demonstrateAwaitlessPromise()
        try demonstrateAwaitlessConfig()

        print("Demo completed")
    }

    private func demonstrateAwaitlessBasic() throws {
        print("1. @Awaitless")

        let service = AwaitlessBasicExample()
        let url = URL(string: "https://example.com/test")!

        let data = try service.downloadFile(url: url)
        print("   Downloaded: \(data.count) bytes")

        let result = service.deprecated_processData(data)
        print("   Processed: \(result)")

        let isValid = try service.blocking_validateInput("test input")
        print("   Valid: \(isValid)")
        print()
    }

    private func demonstrateAwaitlessableProtocol() throws {
        print("2. @Awaitlessable Protocol")

        let sample1: AwaitlessableProtocolExample = FirstAwaitlessableProtocolExample()
        let sample2: AwaitlessableProtocolExample = SecondAwaitlessableProtocolExample()

        let user1 = try sample1.fetchUserProfile(id: "123")
        print("   User: \(user1.name)")

        let response = try sample2.fetchRawData(endpoint: "/api/data")
        print("   Status: \(response.statusCode)")

        let updateSuccess = try sample1.updateUserProfile(user1)
        print("   Updated: \(updateSuccess)")

        let deleteSuccess = sample2.deleteUser(id: "user456")
        print("   Deleted: \(deleteSuccess)")
        print()
    }

    private func demonstrateAwaitlessPublisher() {
        #if canImport(Combine)
        print("3. @AwaitlessPublisher")

        let service = AwaitlessPublisherExample()
        var cancellables = Set<AnyCancellable>()

        service.fetchItems()
            .sink { items in
                print("   Items: \(items.count)")
            }
            .store(in: &cancellables)

        service.loadUserData(id: "user456")
            .sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("   Error: \(error.localizedDescription)")
                    }
                },
                receiveValue: { data in
                    print("   Loaded: \(data)")
                })
            .store(in: &cancellables)

        service.fetchConfig()
            .sink { config in
                print("   Config: \(config.keys.count) keys")
            }
            .store(in: &cancellables)

        Thread.sleep(forTimeInterval: 0.1)
        print()
        #else
        print("3. @AwaitlessPublisher")
        print("   Combine not available")
        print()
        #endif
    }

    private func demonstrateAwaitlessFreestanding() throws {
        print("4. #awaitless Macro")

        let service = AwaitlessBasicExample()
        let url = URL(string: "https://example.com/test")!

        let data = try #awaitless(try service.downloadFile(url: url))
        print("   Downloaded: \(data.count) bytes")

        let result = #awaitless(service.processData(data))
        print("   Processed: \(result)")

        let isValid = try #awaitless(try service.validateInput("test"))
        print("   Valid: \(isValid)")
        print()
    }

    private func demonstrateIsolatedSafeState() {
        print("5. @IsolatedSafe")

        let state = IsolatedSafeExample()

        state.incrementCounter()
        state.addItem("Test item")
        state.cacheUser(id: "u1", name: "Alice")

        let stats = state.getStats()
        print("   Counter: \(stats.counter)")
        print("   Items: \(stats.itemsCount)")

        if let user = state.getCachedUser(id: "u1") {
            print("   Cached: \(user)")
        }
        print()
    }

    private func demonstrateAwaitlessCompletion() throws {
        print("6. @AwaitlessCompletion")

        let service = AwaitlessCompletionExample()
        let semaphore = DispatchSemaphore(value: 0)

        service.fetchData { result in
            switch result {
            case let .success(data):
                print("   Success: \(data)")
            case let .failure(error):
                print("   Error: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()

        service.callback_processRequest("test request") { result in
            switch result {
            case let .success(success):
                print("   Processed: \(success)")
            case .failure:
                print("   Failed")
            }
        }
        print()
    }

    private func demonstrateAwaitlessPromise() async throws {
        #if canImport(AwaitlessKitPromiseKit)
        print("7. @AwaitlessPromise & @Awaitable")
        
        let service = AwaitlessPromiseExample()
        
        do {
            let user = try await service.legacyFetchUser(id: "demo")
            print("   User: \(user)")
        } catch {
            print("   Error: \(error.localizedDescription)")
        }
        
        let data = try await service.async_legacyDownloadData(endpoint: "/test")
        print("   Downloaded: \(data.count) bytes")
        
        try await service.legacyVoidOperation()
        print("   Operation completed")
        
        print()
        #else
        print("7. @AwaitlessPromise & @Awaitable")
        print("   PromiseKit not available")
        print()
        #endif
    }

    private func demonstrateAwaitlessConfig() throws {
        print("8. AwaitlessConfig")

        let initialDefaults = AwaitlessConfig.currentDefaults
        print("   Initial: \(initialDefaults.prefix ?? "none")")

        AwaitlessConfig.setDefaults(
            prefix: "blocking_",
            availability: .deprecated("Use async version"),
            delivery: .main,
            strategy: .concurrent)

        let updatedDefaults = AwaitlessConfig.currentDefaults
        print("   Updated: \(updatedDefaults.prefix ?? "none")")

        AwaitlessConfig.setDefaults()
        print("   Reset to defaults")
        print()
    }
}
