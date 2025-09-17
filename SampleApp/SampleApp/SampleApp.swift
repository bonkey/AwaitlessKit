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
        demonstrateAwaitlessFreestanding()
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

    private func demonstrateAwaitlessFreestanding() {
        print("4. #awaitless Freestanding Macro")
        
        let usage = AwaitlessFreestandingUsage()
        
        let result1 = usage.syncMethodUsingAsyncCode()
        print("   Sync method result: \(result1)")
        
        let result2 = usage.processDataSync()
        print("   Process data sync: \(result2)")
        
        let computed = usage.computedProperty
        print("   Computed property: \(computed)")
        
        let mixed = usage.mixedOperations()
        print("   Mixed operations: hash=\(mixed.hash), number=\(mixed.number), processed=\(mixed.processed)")
        
        let hashes = usage.batchProcess(items: ["item1", "item2", "item3"])
        print("   Batch hashes: \(hashes)")
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
        var completionResult: String = ""
        var completionError: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        service.fetchData { result in
            switch result {
            case .success(let data):
                completionResult = data
            case .failure(let error):
                completionError = error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = completionError {
            print("   Completion error: \(error.localizedDescription)")
        } else {
            print("   Completion result: \(completionResult)")
        }
        
        let semaphore2 = DispatchSemaphore(value: 0)
        var requestResult: Bool = false
        
        service.callback_processRequest("test request") { result in
            switch result {
            case .success(let success):
                requestResult = success
            case .failure(_):
                requestResult = false
            }
            semaphore2.signal()
        }
        
        semaphore2.wait()
        print("   Request processed: \(requestResult)")
        print()
    }

    private func demonstrateAwaitlessConfig() throws {
        print("7. Direct Awaitless.run() Usage")
        
        let directResult = Awaitless.run {
            await simulateProcessing()
            return "Direct async execution result"
        }
        print("   Direct result: \(directResult)")
        
        let computedValue = Awaitless.run {
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.001) {
                    continuation.resume(returning: 999)
                }
            }
        }
        print("   Computed value: \(computedValue)")
        print()
    }


}



final class AwaitlessCompletion: Sendable {
    @AwaitlessCompletion
    func fetchData() async throws -> String {
        await simulateProcessing()
        if Bool.random() {
            throw NSError(domain: "Demo", code: 2, userInfo: [NSLocalizedDescriptionKey: "Random failure"])
        }
        return "Completion handler data"
    }
    
    @AwaitlessCompletion(prefix: "callback_")
    func processRequest(_ request: String) async throws -> Bool {
        await simulateProcessing()
        return request.count > 5
    }
}
