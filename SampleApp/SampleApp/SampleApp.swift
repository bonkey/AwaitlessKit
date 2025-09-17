//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Combine
import Foundation

@main
final class SampleApp {
    static func main() throws {
        let app = SampleApp()
        try app.run()
    }

    func run() throws {
        print("=== AwaitlessKit Feature Demonstrations ===\n")
        
        try demonstrateAwaitlessBasic()
        try demonstrateAwaitlessableProtocol()
        demonstrateAwaitlessPublisher()
        try demonstrateAwaitlessFreestanding()
        demonstrateIsolatedSafeState()
        try demonstrateAwaitlessCompletion()
        try demonstrateAwaitlessConfig()
        
        print("\n=== All demonstrations completed ===")
    }

    private func demonstrateAwaitlessBasic() throws {
        print("1. @Awaitless Basic Usage")
        
        let service = AwaitlessBasic()
        let url = URL(string: "https://httpbin.org/json")!
        
        let data = try service.downloadFile(url: url)
        print("   Downloaded: \(data.count) bytes")
        
        let result = service.processData(data)
        print("   Processed: \(result)")
        
        let isValid = try service.blocking_validateInput("test input")
        print("   Input valid: \(isValid)")
        
        // unavailable
        // let hash = service.sync_computeHash(data)
        // print("   Hash: \(hash)")
        // print()
    }




    private func demonstrateAwaitlessableProtocol() throws {
        print("2. @Awaitlessable Protocol Generation")
        
        let mockRepo: AwaitlessableProtocol = MockRepository()
        let remoteRepo: AwaitlessableProtocol = RemoteRepository()
        
        let user1 = try mockRepo.fetchUserProfile(id: "123")
        print("   Mock user: \(user1.name) (\(user1.email))")
        
        let response = try remoteRepo.fetchRawData(endpoint: "/api/data")
        print("   Remote response: \(response.statusCode), \(response.data.count) bytes")
        
        let updateSuccess = try mockRepo.updateUserProfile(user1)
        print("   Update success: \(updateSuccess)")
        
        let deleteSuccess = remoteRepo.deleteUser(id: "user456")
        print("   Delete success: \(deleteSuccess)")
        print()
    }

    private func demonstrateAwaitlessPublisher() {
        print("3. @AwaitlessPublisher Generation")
        
        let service = AwaitlessPublisher()
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
                    case .failure(let error):
                        print("   User data error: \(error.localizedDescription)")
                    }
                },
                receiveValue: { data in
                    print("   User data loaded: \(data)")
                }
            )
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

    private func demonstrateAwaitlessFreestanding() throws {
        print("4. #awaitless Freestanding Macro")
        
        let service = AwaitlessBasic()
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
        
        let state = IsolatedSafeState()
        
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
        
        let service = AwaitlessCompletion()
        let semaphore = DispatchSemaphore(value: 0)
        
        service.fetchData { result in
            switch result {
            case .success(let data):
                print("   Completion result: \(data)")
            case .failure(let error):
                print("   Completion error: \(error.localizedDescription)")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        let semaphore2 = DispatchSemaphore(value: 0)
        
        service.callback_processRequest("test request") { result in
            switch result {
            case .success(let success):
                print("   Request processed: \(success)")
            case .failure(_):
                print("   Request processed: false")
            }
            semaphore2.signal()
        }
        
        semaphore2.wait()
        print()
    }

    private func demonstrateAwaitlessConfig() throws {
        print("7. AwaitlessConfig Global Configuration")
        
        // Show current defaults
        let initialDefaults = AwaitlessConfig.currentDefaults
        print("   Initial defaults: prefix=\(initialDefaults.prefix ?? "nil"), strategy=\(String(describing: initialDefaults.strategy))")
        
        // Set custom global defaults
        AwaitlessConfig.setDefaults(
            prefix: "blocking_",
            availability: .deprecated("Use async version instead"),
            delivery: .main,
            strategy: .concurrent
        )
        
        let updatedDefaults = AwaitlessConfig.currentDefaults
        print("   Updated defaults: prefix=\(updatedDefaults.prefix ?? "nil"), strategy=\(String(describing: updatedDefaults.strategy))")
        
        // Reset to default configuration
        AwaitlessConfig.setDefaults()
        let resetDefaults = AwaitlessConfig.currentDefaults
        print("   Reset defaults: prefix=\(resetDefaults.prefix ?? "nil"), strategy=\(String(describing: resetDefaults.strategy))")
        print()
    }


}




