# Examples

Comprehensive examples demonstrating AwaitlessKit usage patterns and real-world scenarios.

## Overview

This guide provides practical examples of using AwaitlessKit macros in various scenarios, from basic usage to advanced configuration patterns. Each example includes both the async implementation and the generated synchronous wrapper.

## Basic Usage Examples

### Simple Async Function

The most basic usage of `@Awaitless` generates a synchronous wrapper for an async function:

```swift
import AwaitlessKit

class APIService {
    @Awaitless
    func fetchData() async throws -> Data {
        let url = URL(string: "https://api.example.com/data")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    // Generates: func fetchData() throws -> Data
}

// Usage
let service = APIService()

// Async version
let data1 = try await service.fetchData()

// Generated sync version
let data2 = try service.fetchData()
```

### Non-throwing Async Function

Functions that don't throw still get useful synchronous wrappers:

```swift
class CacheService {
    @Awaitless
    func getValue(for key: String) async -> String? {
        // Simulate async cache lookup
        try? await Task.sleep(nanoseconds: 1_000_000)
        return cache[key]
    }
    // Generates: func getValue(for key: String) -> String?
}

// Usage
let cache = CacheService()
let value = cache.getValue(for: "user_123")  // Synchronous call
```

### Async Function with Complex Return Types

AwaitlessKit handles complex return types seamlessly:

```swift
class DataProcessor {
    @Awaitless
    func processItems() async throws -> [String: [ProcessedItem]] {
        let items = try await fetchRawItems()
        let processed = try await process(items)
        return Dictionary(grouping: processed) { $0.category }
    }
    // Generates: func processItems() throws -> [String: [ProcessedItem]]
}
```

## Publisher Examples

### Basic Publisher Generation

Generate Combine publishers from async functions (now backed by a dedicated cancellation-aware Task-based publisher rather than a Future for correct cancellation and cleaner semantics):

```swift
import Combine

class NetworkService {
    @AwaitlessPublisher
    func fetchUser(id: String) async throws -> User {
        let url = URL(string: "https://api.example.com/users/\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(User.self, from: data)
    }
    // Generates: func fetchUser(id: String) -> AnyPublisher<User, Error>
}

// Usage
let service = NetworkService()
let cancellable = service.fetchUser(id: "123")
    .sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished: print("Completed")
            case .failure(let error): print("Error: \(error)")
            }
        },
        receiveValue: { user in
            print("Received user: \(user.name)")
        }
    )
```

### Publisher with Custom Delivery Queue

Control where publisher events are delivered:

```swift
class ImageService {
    @AwaitlessPublisher(deliverOn: .main)
    func loadImage(from url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw ImageError.invalidData
        }
        return image
    }
    // Generates: func loadImage(from url: URL) -> AnyPublisher<UIImage, Error>
    // Events delivered on main queue
}

// Usage - perfect for UI updates
service.loadImage(from: imageURL)
    .sink(receiveValue: { image in
        // This runs on main queue automatically
        self.imageView.image = image
    })
```

### Non-throwing Publisher Example

Showcasing a non-throwing async function generating a `Never`-failing publisher:

```swift
class StatsService {
    @AwaitlessPublisher
    func currentLoad() async -> Double {
        await metrics.loadAverage()
    }
    // Generates: func currentLoad() -> AnyPublisher<Double, Never>
}

// Usage
let stats = StatsService()
let cancellable = stats.currentLoad()
    .sink(
        receiveCompletion: { _ in },
        receiveValue: { load in
            print("Current load: \(load)")
        }
    )
```

Cancellation note: All `@AwaitlessPublisher` wrappers are built on Task-backed publishers (not `Future`), so cancelling the subscription cancels the underlying `Task` promptly.

## Completion Handler Examples

### Basic Completion Handler

Generate completion-handler based functions:

```swift
class AuthService {
    @AwaitlessCompletion
    func authenticate(username: String, password: String) async throws -> AuthToken {
        let request = AuthRequest(username: username, password: password)
        let response = try await networkClient.send(request)
        return response.token
    }
    // Generates: func authenticate(username: String, password: String,
    //                              completion: @escaping (Result<AuthToken, Error>) -> Void)
}

// Usage
let auth = AuthService()
auth.authenticate(username: "user", password: "pass") { result in
    switch result {
    case .success(let token):
        print("Authenticated with token: \(token)")
    case .failure(let error):
        print("Authentication failed: \(error)")
    }
}
```

### Completion Handler with Custom Prefix

Use prefixes to avoid naming conflicts:

```swift
class DatabaseService {
    @AwaitlessCompletion(prefix: "callback_")
    func saveRecord(_ record: Record) async throws -> RecordID {
        return try await database.insert(record)
    }
    // Generates: func callback_saveRecord(_ record: Record,
    //                                    completion: @escaping (Result<RecordID, Error>) -> Void)

    // Original completion-based method can coexist
    func saveRecord(_ record: Record, completion: @escaping (Result<RecordID, Error>) -> Void) {
        // Legacy implementation
    }
}
```

## Protocol Examples

### Basic Protocol Generation

Generate synchronous protocol extensions from async protocols:

```swift
@Awaitlessable
protocol DataRepository {
    func fetch(id: String) async throws -> DataModel
    func save(_ model: DataModel) async throws
    func delete(id: String) async throws
}
// Generates synchronous versions of all methods in an extension

class InMemoryRepository: DataRepository {
    func fetch(id: String) async throws -> DataModel {
        // Async implementation
    }

    func save(_ model: DataModel) async throws {
        // Async implementation
    }

    func delete(id: String) async throws {
        // Async implementation
    }
}

// Usage with both interfaces
let repo: DataRepository = InMemoryRepository()

// Async versions
let model1 = try await repo.fetch(id: "123")
try await repo.save(model1)

// Generated sync versions
let model2 = try repo.fetch(id: "456")  // Uses generated sync extension
try repo.save(model2)
```

### Protocol with Default Implementation

Generate default implementations for protocol methods:

```swift
@Awaitlessable(extensionGeneration: .withDefaults)
protocol CacheProtocol {
    func get(key: String) async -> String?
    func set(key: String, value: String) async
}
// Generates extension with default sync implementations that call async versions

// Conforming types automatically get sync versions
struct MemoryCache: CacheProtocol {
    func get(key: String) async -> String? {
        // Only implement async version
        return storage[key]
    }

    func set(key: String, value: String) async {
        // Only implement async version
        storage[key] = value
    }
}

// Usage
let cache = MemoryCache()
cache.set(key: "user_123", value: "John")  // Uses generated sync wrapper
let value = cache.get(key: "user_123")     // Uses generated sync wrapper
```

## Configuration Examples

### Process-Level Configuration

Set application-wide defaults:

```swift
// In main() or application startup
AwaitlessConfig.setDefaults(
    prefix: "sync_",
    availability: .deprecated("Migrate to async APIs by Q4 2024")
)

// All macros now inherit these defaults
class UserService {
    @Awaitless
    func createUser(_ userData: UserData) async throws -> User {
        // Implementation
    }
    // Generates: @available(*, deprecated: "Migrate to async APIs by Q4 2024")
    //            func sync_createUser(_ userData: UserData) throws -> User
}
```

### Type-Scoped Configuration

Configure all methods within a type:

```swift
@AwaitlessConfig(prefix: "blocking_", availability: .noasync)
class CriticalOperations {
    @Awaitless
    func performCriticalTask() async throws -> CriticalResult {
        // Implementation
    }
    // Generates: @available(*, noasync)
    //            func blocking_performCriticalTask() throws -> CriticalResult

    @AwaitlessPublisher
    func monitorCriticalSystem() async throws -> SystemStatus {
        // Implementation
    }
    // Generates: @available(*, noasync)
    //            func blocking_monitorCriticalSystem() -> AnyPublisher<SystemStatus, Error>
}
```

### Method-Level Override

Override type and process configurations for specific methods:

```swift
@AwaitlessConfig(prefix: "api_")  // Type-level default
class ServiceManager {
    @Awaitless  // Uses type prefix: api_
    func standardOperation() async throws -> String {
        return "standard"
    }
    // Generates: func api_standardOperation() throws -> String

    @Awaitless(prefix: "urgent_")  // Override prefix
    func urgentOperation() async throws -> String {
        return "urgent"
    }
    // Generates: func urgent_urgentOperation() throws -> String

    @Awaitless(.unavailable("This operation requires async context"))  // Override availability
    func contextSensitiveOperation() async throws -> String {
        return "context"
    }
    // Generates: @available(*, unavailable: "This operation requires async context")
    //            func api_contextSensitiveOperation() throws -> String
}
```

## Advanced Usage Examples

### Multiple Macro Composition

Apply multiple macros to generate different wrapper styles:

```swift
class FlexibleService {
    @Awaitless
    @AwaitlessPublisher(deliverOn: .main)
    @AwaitlessCompletion
    func fetchData() async throws -> Data {
        // Single async implementation
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    // Generates three wrappers:
    // 1. func fetchData() throws -> Data
    // 2. func fetchData() -> AnyPublisher<Data, Error>  (main queue delivery)
    // 3. func fetchData(completion: @escaping (Result<Data, Error>) -> Void)
}

// Usage flexibility
let service = FlexibleService()

// Choose the style that fits your needs
let syncData = try service.fetchData()

let publisher = service.fetchData()
    .sink(receiveValue: { data in /* handle on main thread */ })

service.fetchData { result in
    switch result {
    case .success(let data): /* handle data */
    case .failure(let error): /* handle error */
    }
}
```

### Inline Async Execution

Use `#awaitless()` for inline async code execution:

```swift
class LegacyIntegration {
    func synchronousMethod() -> String {
        // Execute async code inline within sync method
        let result = #awaitless {
            let data = try await asyncAPI.fetchData()
            let processed = try await processor.process(data)
            return processed.description
        }

        return result ?? "fallback"
    }

    func complexSynchronousLogic() -> ProcessedData {
        let step1 = performSyncStep1()

        // Mix async operations into sync flow
        let step2 = #awaitless {
            try await performAsyncStep2(step1)
        }

        let step3 = performSyncStep3(step2 ?? fallbackData)
        return step3
    }
}
```

### Thread-Safe Properties

Generate thread-safe property wrappers:

```swift
class SharedCounter {
    @IsolatedSafe(writable: true, strategy: .concurrent)
    private var _count: Int = 0
    // Generates thread-safe getter and setter using concurrent queue with barriers

    @IsolatedSafe(writable: false, strategy: .serial, queueName: "counter-read")
    private var _readOnlyValue: String = "initial"
    // Generates thread-safe getter only using serial queue

    func increment() {
        count += 1  // Thread-safe write
    }

    func getValue() -> (count: Int, value: String) {
        return (count: count, value: readOnlyValue)  // Thread-safe reads
    }
}
```

## Real-World Migration Examples

### Migrating a Network Layer

```swift
// Phase 1: Add async implementation with sync wrappers
class NetworkClient {
    // Synchronous method
    func requestLegacy<T: Codable>(_ endpoint: Endpoint) throws -> T {
        // Synchronous implementation
        let data = synchronousNetworkCall(endpoint)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // Async method with sync wrapper
    @Awaitless(prefix: "wrapped_", .deprecated("Use async version"))
    func request<T: Codable>(_ endpoint: Endpoint) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: endpoint.urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.invalidResponse
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
    // Generates: @available(*, deprecated: "Use async version")
    //            func modern_request<T: Codable>(_ endpoint: Endpoint) throws -> T
}

// Usage during migration
let client = NetworkClient()

// Old calling code continues to work
let user1: User = try client.requestLegacy(.user(id: "123"))

// New async calling code
let user2: User = try await client.request(.user(id: "456"))

// Generated wrapper for gradual migration
let user3: User = try client.wrapped_request(.user(id: "789"))
```

### Migrating a Data Repository

```swift
// Phase 1: Start with protocols
@Awaitlessable(extensionGeneration: .withDefaults)
protocol UserRepository {
    func findUser(by id: String) async throws -> User?
    func saveUser(_ user: User) async throws
    func deleteUser(id: String) async throws
}

// Phase 2: Implement with async-first approach
class CoreDataUserRepository: UserRepository {
    @Awaitless(.deprecated("Use async findUser"))
    func findUser(by id: String) async throws -> User? {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                // Core Data operations
                do {
                    let user = try self.fetchUser(id: id, in: context)
                    continuation.resume(returning: user)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @Awaitless(.deprecated("Use async saveUser"))
    func saveUser(_ user: User) async throws {
        try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                // Save operations
                do {
                    try self.save(user, in: context)
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @Awaitless(.deprecated("Use async deleteUser"))
    func deleteUser(id: String) async throws {
        // Implementation
    }
}

// Usage across migration phases
class UserService {
    let repository: UserRepository

    // Can use either interface during migration
    func getUserSync(id: String) throws -> User? {
        return try repository.findUser(by: id)  // Uses generated sync wrapper
    }

    func getUserAsync(id: String) async throws -> User? {
        return try await repository.findUser(by: id)  // Uses native async method
    }
}
```

### Progressive Deprecation Example

```swift
class PaymentProcessor {
    // Phase 1: Soft deprecation
    @Awaitless(.deprecated("Consider migrating to async version for better performance"))
    func processPayment(_ payment: Payment) async throws -> PaymentResult {
        return try await performPaymentProcessing(payment)
    }

    // Phase 2: Strong deprecation with timeline
    @Awaitless(.deprecated("Sync version will be removed in v3.0. Migrate to async version."))
    func refundPayment(_ refund: Refund) async throws -> RefundResult {
        return try await performRefundProcessing(refund)
    }

    // Phase 3: Mark as unavailable
    @Awaitless(.unavailable("Sync version removed. Use async version only."))
    func cancelPayment(_ cancellation: Cancellation) async throws -> CancellationResult {
        return try await performCancellationProcessing(cancellation)
    }

    // Phase 4: Pure async (macro removed)
    func validatePayment(_ validation: ValidationRequest) async throws -> ValidationResult {
        return try await performValidation(validation)
    }
}
```

## Testing Examples

### Testing Generated Wrappers

```swift
class APIServiceTests: XCTestCase {
    var service: APIService!

    override func setUp() {
        service = APIService()
    }

    // Test async version
    func testFetchDataAsync() async throws {
        let data = try await service.fetchData()
        XCTAssertFalse(data.isEmpty)
    }

    // Test generated sync version
    func testFetchDataSync() throws {
        let data = try service.fetchData()  // Generated sync wrapper
        XCTAssertFalse(data.isEmpty)
    }

    // Test behavioral equivalence
    func testAsyncSyncEquivalence() async throws {
        let asyncData = try await service.fetchData()
        let syncData = try service.fetchData()

        // Both should return equivalent data
        XCTAssertEqual(asyncData.count, syncData.count)
    }
}
```

## Error Handling Examples

### Comprehensive Error Handling

```swift
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL provided"
        case .noData: return "No data received"
        case .invalidResponse: return "Invalid response received"
        case .decodingError(let error): return "Decoding failed: \(error.localizedDescription)"
        }
    }
}

class RobustNetworkService {
    @Awaitless
    @AwaitlessPublisher(deliverOn: .main)
    @AwaitlessCompletion
    func fetchUserData(id: String) async throws -> UserData {
        guard let url = URL(string: "https://api.example.com/users/\(id)") else {
            throw NetworkError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.invalidResponse
        }

        guard !data.isEmpty else {
            throw NetworkError.noData
        }

        do {
            return try JSONDecoder().decode(UserData.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}

// Error handling with different approaches
let service = RobustNetworkService()

// Sync wrapper with do-catch
do {
    let userData = try service.fetchUserData(id: "123")
    print("Success: \(userData)")
} catch let error as NetworkError {
    print("Network error: \(error.errorDescription ?? "Unknown")")
} catch {
    print("Unexpected error: \(error)")
}

// Publisher with error handling
service.fetchUserData(id: "123")
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Publisher error: \(error)")
            }
        },
        receiveValue: { userData in
            print("Publisher success: \(userData)")
        }
    )

// Completion handler with Result
service.fetchUserData(id: "123") { result in
    switch result {
    case .success(let userData):
        print("Completion success: \(userData)")
    case .failure(let error):
        print("Completion error: \(error)")
    }
}
```

## Best Practices Examples

### Naming Consistency

```swift
// Use consistent prefixes for different scenarios
@AwaitlessConfig(prefix: "sync_")  // For general sync wrappers
class GeneralService {
    @Awaitless
    func operation() async throws -> Result { /* ... */ }
    // Generates: func sync_operation() throws -> Result
}

@AwaitlessConfig(prefix: "blocking_")  // For operations that might block
class BlockingService {
    @Awaitless
    func heavyComputation() async throws -> Result { /* ... */ }
    // Generates: func blocking_heavyComputation() throws -> Result
}

@AwaitlessConfig(prefix: "legacy_")  // For backward compatibility
class LegacyCompatibilityService {
    @Awaitless(.deprecated("Use async version"))
    func oldStyleOperation() async throws -> Result { /* ... */ }
    // Generates: @available(*, deprecated: "Use async version")
    //            func legacy_oldStyleOperation() throws -> Result
}
```

### Documentation and Comments

```swift
class WellDocumentedService {
    /// Fetches user data asynchronously with automatic sync wrapper generation.
    ///
    /// The `@Awaitless` macro generates a synchronous wrapper that blocks the current thread.
    /// Use the async version when possible for better performance and resource utilization.
    ///
    /// - Parameter id: The unique identifier for the user
    /// - Returns: User data if found
    /// - Throws: `NetworkError` for network-related issues, `DecodingError` for parsing issues
    ///
    /// Generated sync wrapper: `func fetchUser(id:) throws -> User`
    @Awaitless(.deprecated("Use async version for better performance"))
    func fetchUser(id: String) async throws -> User {
        // Implementation details...
        let userData = try await networkClient.fetch(endpoint: .user(id))
        return try UserDecoder.decode(userData)
    }
}
```

This comprehensive examples guide demonstrates the full range of AwaitlessKit capabilities, from basic usage to complex real-world migration scenarios. Each example is designed to be practical and immediately applicable to your async/await migration needs.
