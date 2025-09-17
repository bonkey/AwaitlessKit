# Usage Guide

Quick reference for using AwaitlessKit macros with practical examples.

Quick reference for common AwaitlessKit patterns. For detailed examples, see <doc:Examples>.

## Basic Macro Usage

### @Awaitless - Synchronous Wrappers

Generate synchronous wrappers for async functions:

```swift
import AwaitlessKit

class APIService {
    @Awaitless
    func fetchData() async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    // Generates: func fetchData() throws -> Data
}

// Usage
let service = APIService()
let data = try service.fetchData()  // Blocks current thread
```

### @AwaitlessPublisher - Combine Publishers

Generate Combine publishers from async functions:

```swift
import Combine

class DataService {
    @AwaitlessPublisher
    func loadUser(id: String) async throws -> User {
        // Async implementation
        return try await networkClient.fetchUser(id: id)
    }
    // Generates: func loadUser(id: String) -> AnyPublisher<User, Error>
}

// Usage
let cancellable = service.loadUser(id: "123")
    .sink(
        receiveCompletion: { _ in },
        receiveValue: { user in print("Loaded: \(user.name)") }
    )
```

### @AwaitlessCompletion - Completion Handlers

Generate completion-handler based functions:

```swift
class AuthService {
    @AwaitlessCompletion
    func login(username: String, password: String) async throws -> AuthToken {
        // Async implementation
        return try await performAuthentication(username, password)
    }
    // Generates: func login(username: String, password: String,
    //                      completion: @escaping (Result<AuthToken, Error>) -> Void)
}

// Usage
service.login(username: "user", password: "pass") { result in
    switch result {
    case .success(let token): print("Authenticated")
    case .failure(let error): print("Failed: \(error)")
    }
}
```

## Configuration Patterns

### Method-Level Configuration

Configure individual methods:

```swift
class ServiceManager {
    @Awaitless(prefix: "sync_")
    func operation1() async throws -> String { "result" }
    // Generates: func sync_operation1() throws -> String

    @Awaitless(.deprecated("Use async version"))
    func operation2() async throws -> String { "result" }
    // Generates: @available(*, deprecated: "Use async version")
    //            func operation2() throws -> String

    @Awaitless(.unavailable("Requires async context"))
    func operation3() async throws -> String { "result" }
    // Generates: @available(*, unavailable: "Requires async context")
    //            func operation3() throws -> String
}
```

### Type-Level Configuration

Configure all methods in a type:

```swift
@AwaitlessConfig(prefix: "blocking_", availability: .noasync)
class CriticalService {
    @Awaitless
    func criticalOperation() async throws -> Result {
        // Implementation
    }
    // Generates: @available(*, noasync)
    //            func blocking_criticalOperation() throws -> Result

    @AwaitlessPublisher
    func monitorStatus() async throws -> Status {
        // Implementation
    }
    // Generates: @available(*, noasync)
    //            func blocking_monitorStatus() -> AnyPublisher<Status, Error>
}
```

### Process-Level Configuration

Set application-wide defaults:

```swift
// In main() or application startup
AwaitlessConfig.setDefaults(
    prefix: "sync_",
    availability: .deprecated("Migrate to async by Q4 2024")
)

// All subsequent @Awaitless macros inherit these defaults
class UserService {
    @Awaitless
    func createUser(_ data: UserData) async throws -> User {
        // Implementation
    }
    // Generates: @available(*, deprecated: "Migrate to async by Q4 2024")
    //            func sync_createUser(_ data: UserData) throws -> User
}
```

## Protocol Extensions

### Basic Protocol Generation

```swift
@Awaitlessable
protocol DataRepository {
    func fetch(id: String) async throws -> DataModel
    func save(_ model: DataModel) async throws
}
// Generates synchronous protocol extension with method signatures

class Repository: DataRepository {
    func fetch(id: String) async throws -> DataModel {
        // Async implementation
    }

    func save(_ model: DataModel) async throws {
        // Async implementation
    }
}

// Usage
let repo: DataRepository = Repository()
let model = try repo.fetch(id: "123")  // Uses generated sync extension
```

### Protocol with Default Implementations

```swift
@Awaitlessable(extensionGeneration: .withDefaults)
protocol CacheProtocol {
    func get(key: String) async -> String?
    func set(key: String, value: String) async
}
// Generates extension with default sync implementations

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

// Automatically has sync wrappers available
let cache = MemoryCache()
cache.set(key: "user", value: "data")  // Generated sync wrapper
```

## Utility Macros

### Inline Async Execution

Execute async code in synchronous contexts:

```swift
class LegacyIntegration {
    func syncMethod() -> String {
        // Execute async code inline
        let result = #awaitless {
            let data = try await fetchData()
            let processed = try await process(data)
            return processed.description
        }

        return result ?? "fallback"
    }
}
```

### Thread-Safe Properties

Generate thread-safe property wrappers:

```swift
class SharedState {
    @IsolatedSafe(writable: true, strategy: .concurrent)
    private var _counter: Int = 0
    // Generates thread-safe getter and setter

    @IsolatedSafe(writable: false, strategy: .serial)
    private var _config: Configuration = defaultConfig
    // Generates thread-safe getter only

    func increment() {
        counter += 1  // Thread-safe
    }

    var currentState: (counter: Int, config: Configuration) {
        return (counter: counter, config: config)  // Thread-safe reads
    }
}
```

## Multiple Macro Composition

Combine macros for maximum flexibility:

```swift
class FlexibleService {
    @Awaitless
    @AwaitlessPublisher(deliverOn: .main)
    @AwaitlessCompletion
    func fetchData() async throws -> Data {
        // Single implementation generates three wrappers
        return try await URLSession.shared.data(from: url).0
    }
    // Generates:
    // 1. func fetchData() throws -> Data
    // 2. func fetchData() -> AnyPublisher<Data, Error>
    // 3. func fetchData(completion: @escaping (Result<Data, Error>) -> Void)
}

// Use the approach that fits your needs
let service = FlexibleService()

// Direct sync call
let data = try service.fetchData()

// Combine publisher
let cancellable = service.fetchData()
    .sink(receiveValue: { data in /* main queue */ })

// Completion handler
service.fetchData { result in
    // Handle result
}
```

## Common Patterns

### Migration-Friendly APIs

```swift
class NetworkClient {
    // Async API with backward compatibility
    @Awaitless(prefix: "sync_", .deprecated("Use async version"))
    func request<T: Codable>(_ endpoint: Endpoint) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: endpoint.request)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.invalidResponse
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
    // Generates: @available(*, deprecated: "Use async version")
    //            func sync_request<T: Codable>(_ endpoint: Endpoint) throws -> T
}

// Gradual migration
let client = NetworkClient()

// Legacy code continues working
let user1: User = try client.sync_request(.user(id: "123"))

// Async usage
let user2: User = try await client.request(.user(id: "456"))
```

### Error Handling

```swift
enum ServiceError: Error {
    case invalidInput
    case networkFailure
    case processingFailed
}

class RobustService {
    @Awaitless
    @AwaitlessCompletion
    func processRequest(_ input: String) async throws -> ProcessedResult {
        guard !input.isEmpty else {
            throw ServiceError.invalidInput
        }

        do {
            let data = try await networkCall(input)
            return try await processData(data)
        } catch {
            throw ServiceError.processingFailed
        }
    }
}

// Error handling with sync wrapper
do {
    let result = try service.processRequest("input")
    print("Success: \(result)")
} catch ServiceError.invalidInput {
    print("Invalid input provided")
} catch ServiceError.networkFailure {
    print("Network connection failed")
} catch ServiceError.processingFailed {
    print("Processing failed")
} catch {
    print("Unexpected error: \(error)")
}

// Error handling with completion handler
service.processRequest("input") { result in
    switch result {
    case .success(let processed):
        print("Success: \(processed)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

## Common Prefixes

- `sync_` - General synchronous operations
- `blocking_` - Operations that block significantly
- `legacy_` - Backward compatibility wrappers

## Quick Reference Summary

| Macro                  | Purpose                | Generated Code                                                |
| ---------------------- | ---------------------- | ------------------------------------------------------------- |
| `@Awaitless`           | Sync wrapper           | `func name() throws -> T`                                     |
| `@AwaitlessPublisher`  | Combine publisher      | `func name() -> AnyPublisher<T, Error>`                       |
| `@AwaitlessCompletion` | Completion handler     | `func name(completion: @escaping (Result<T, Error>) -> Void)` |
| `@Awaitlessable`       | Protocol extensions    | Sync method signatures in extension                           |
| `#awaitless()`         | Inline async execution | Direct async code in sync context                             |
| `@IsolatedSafe`        | Thread-safe properties | Thread-safe getter/setter with queues                         |

For comprehensive examples and advanced usage patterns, see <doc:Examples>.
For configuration details, see <doc:Configuration>.
For migration strategies, see <doc:MigrationGuide>.

## Concurrency & Sendable Requirements

When using AwaitlessKit macros in Swift 6+ you should explicitly model isolation and value transfer semantics to avoid warnings or undefined behavior:

### Mark Classes `final` Whenever Possible

Marking an async-capable service class `final`:

- Enables the compiler to better reason about thread-safety
- Avoids accidental subclass overrides that could bypass wrappers
- Reduces dynamic dispatch overhead

```swift
final class UserService: Sendable {
    @Awaitless
    func fetchUser(id: String) async throws -> User { /* ... */ }
}
```

If a class must be subclassed, ensure all async or macro-decorated methods are not relying on subclass-only invariants that the generated sync or publisher wrappers could violate.

### Adopt `Sendable` on Types Participating in Concurrency

Add `Sendable` to:

- Service classes whose methods you wrap with `@Awaitless`, `@AwaitlessPublisher`, or `@AwaitlessCompletion`
- Protocols you annotate with `@Awaitlessable`
- Parameter/result model types crossing concurrency boundaries (where feasible)

```swift
@Awaitlessable
protocol DataService: Sendable {
    func fetchUser(id: String) async throws -> User
}
```

### Protocols + `@Awaitlessable`

When you generate synchronous protocol extensions:

- Mark the protocol `Sendable` if conforming types will be used across tasks/threads
- Ensure all associated types & referenced types are `Sendable` (or consciously non-Sendable if confined)

### Capturing Self in Generated Publishers

`@AwaitlessPublisher` generates a Task-backed publisher. To keep captures safe:

- Prefer immutable or thread-safe state inside the async function
- Use `@IsolatedSafe` for mutable `nonisolated(unsafe)` properties when crossing threads
- Avoid relying on main-thread-only assumptions unless you specify `deliverOn: .main`

### Non-Sendable Legacy Types

If you must interact with non-Sendable legacy types:

- Contain them inside a final wrapper object marked `@unchecked Sendable` only after a deliberate audit
- Keep such usage out of macro-generated surfaces when possible

```swift
final class LegacyWrapper: @unchecked Sendable {
    private let ref: LegacyNonThreadSafeThing
    init(_ ref: LegacyNonThreadSafeThing) { self.ref = ref }

    @Awaitless
    func perform() async { ref.doWork() } // Consciously audited
}
```

### Summary Checklist

- final + Sendable for service classes
- Sendable protocols with @Awaitlessable
- Prefer value-semantic / Sendable parameter & return types
- Use `deliverOn: .main` only for UI-sensitive delivery
- Introduce `@IsolatedSafe` for unsafe shared mutable state
- Avoid `@unchecked Sendable` unless strictly necessary and audited

These practices keep the generated synchronous and publisher surfaces aligned with Swift 6 concurrency expectations while minimizing warnings and migration friction.
