# PromiseKit Integration

Bidirectional conversion between async/await and PromiseKit with @AwaitlessPromise and @Awaitable macros.

## Overview

AwaitlessKit provides comprehensive PromiseKit integration through two complementary macros that enable seamless bidirectional conversion between async/await code and existing PromiseKit-based architectures:

- **`@AwaitlessPromise`**: Converts async functions to return `Promise<T>`
- **`@Awaitable`**: Converts Promise functions to async/await functions

Both macros follow the same configuration patterns as other AwaitlessKit macros, supporting prefixes, availability attributes, and the four-level configuration hierarchy.

> Important: PromiseKit integration requires importing the `AwaitlessKit-PromiseKit` library, which is available as a separate product for modular usage.

## Installation

Add both AwaitlessKit and the PromiseKit integration to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/bonkey/AwaitlessKit.git", from: "7.1.0"),
    .package(url: "https://github.com/mxcl/PromiseKit.git", from: "8.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            "AwaitlessKit",
            .product(name: "AwaitlessKit-PromiseKit", package: "AwaitlessKit"),
            "PromiseKit"
        ]
    )
]
```

## @AwaitlessPromise - Async to Promise Conversion

The `@AwaitlessPromise` macro generates Promise-returning functions from your async implementations, enabling integration of modern async/await code with existing PromiseKit-based systems.

### Basic Usage

```swift
import AwaitlessKit
import PromiseKit

class NetworkService {
    @AwaitlessPromise
    func fetchUser(id: String) async throws -> User {
        let url = URL(string: "https://api.example.com/users/\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(User.self, from: data)
    }
    // Generates: func fetchUser(id: String) -> Promise<User>
}

// Usage with PromiseKit
let service = NetworkService()
service.fetchUser(id: "123")
    .done { user in
        print("Fetched user: \(user.name)")
    }
    .catch { error in
        print("Error: \(error)")
    }
```

### With Prefix and Availability

```swift
class DataService {
    @AwaitlessPromise(prefix: "promise_", .deprecated("Use async version instead"))
    func loadData() async throws -> Data {
        // Your async implementation
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    // Generates: 
    // @available(*, deprecated: "Use async version instead")
    // func promise_loadData() -> Promise<Data>
}
```

### Non-throwing Functions

Non-throwing async functions generate Promises that never reject:

```swift
class CacheService {
    @AwaitlessPromise
    func getValue(key: String) async -> String? {
        // Simulate async cache lookup
        await Task.sleep(nanoseconds: 1_000_000)
        return cache[key]
    }
    // Generates: func getValue(key: String) -> Promise<String?>
}

// Usage
service.getValue(key: "user_123")
    .done { value in
        // Handle optional value
    }
```

### Void Functions

```swift
class ConfigurationService {
    @AwaitlessPromise(prefix: "promise_")
    func saveSettings(_ settings: [String: Any]) async throws -> Void {
        // Save settings asynchronously
        try await persistSettings(settings)
    }
    // Generates: func promise_saveSettings(_ settings: [String: Any]) -> Promise<Void>
}

// Usage
service.promise_saveSettings(newSettings)
    .done {
        print("Settings saved successfully")
    }
    .catch { error in
        print("Failed to save settings: \(error)")
    }
```

## @Awaitable - Promise to Async Conversion

The `@Awaitable` macro generates async/await functions from existing Promise-based implementations, enabling gradual migration from PromiseKit to modern async/await patterns.

### Basic Usage

```swift
class LegacyNetworkService {
    @Awaitable
    func fetchUser(id: String) -> Promise<User> {
        return URLSession.shared.dataTask(.promise, with: userURL)
            .map { data, response in
                return try JSONDecoder().decode(User.self, from: data)
            }
    }
    // Generates: 
    // @available(*, deprecated: "PromiseKit support is deprecated; use async function instead")
    // func fetchUser(id: String) async throws -> User
}

// Usage with async/await
let service = LegacyNetworkService()
do {
    let user = try await service.fetchUser(id: "123")
    print("Fetched user: \(user.name)")
} catch {
    print("Error: \(error)")
}
```

### Custom Availability Messages

```swift
class APIService {
    @Awaitable(.deprecated("Migrate to the new async API by Q2 2024"))
    func legacyFetchData() -> Promise<Data> {
        // Your Promise-based implementation
        return Promise { seal in
            // Legacy Promise implementation
        }
    }
    // Generates:
    // @available(*, deprecated: "Migrate to the new async API by Q2 2024")
    // func legacyFetchData() async throws -> Data
}
```

### With Prefixes

```swift
class MigrationService {
    @Awaitable(prefix: "async_")
    func legacyOperation() -> Promise<Result> {
        return Promise.value(Result())
    }
    // Generates:
    // @available(*, deprecated: "PromiseKit support is deprecated; use async function instead")
    // func async_legacyOperation() async throws -> Result
}
```

### Void Promises

```swift
class UtilityService {
    @Awaitable
    func performMaintenance() -> Promise<Void> {
        return Promise { seal in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                // Perform maintenance
                seal.fulfill(())
            }
        }
    }
    // Generates: func performMaintenance() async throws -> Void
}

// Usage
try await service.performMaintenance()
print("Maintenance completed")
```

## Bidirectional Migration Patterns

### Gradual Migration Strategy

Use both macros together to enable smooth transitions:

```swift
class UserService {
    // New async implementation with Promise support for legacy code
    @AwaitlessPromise(prefix: "promise_")
    func fetchUser(id: String) async throws -> User {
        let url = URL(string: "https://api.example.com/users/\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(User.self, from: data)
    }
    
    // Legacy Promise implementation with async support for new code
    @Awaitable(prefix: "async_", .deprecated("Use fetchUser(id:) async version instead"))
    func legacyFetchUser(id: String) -> Promise<User> {
        return URLSession.shared.dataTask(.promise, with: userURL)
            .map { try JSONDecoder().decode(User.self, from: $0) }
    }
}

// During migration, both APIs are available:
let service = UserService()

// New async/await code
let user1 = try await service.fetchUser(id: "123")

// Legacy PromiseKit code
let user2Promise = service.promise_fetchUser(id: "456")

// Migrating legacy code
let user3 = try await service.async_legacyFetchUser(id: "789")

// Existing PromiseKit chains
service.legacyFetchUser(id: "101")
    .then { user in
        // Existing Promise chains continue to work
    }
```

### Configuration Integration

PromiseKit macros support the same configuration system as other AwaitlessKit macros:

```swift
@AwaitlessConfig(prefix: "legacy_", availability: .deprecated("Migrate to async/await"))
class NetworkManager {
    @AwaitlessPromise  // Inherits config: legacy_fetchData with deprecation
    func fetchData() async throws -> Data {
        // Implementation
    }
    
    @Awaitable(prefix: "async_")  // Overrides prefix, inherits availability
    func promiseBasedOperation() -> Promise<String> {
        // Implementation
    }
}
```

## Error Handling

### Promise Error Handling

The `@AwaitlessPromise` macro handles errors by catching thrown exceptions and rejecting the Promise:

```swift
@AwaitlessPromise
func riskyOperation() async throws -> String {
    if Bool.random() {
        throw APIError.networkFailure
    }
    return "Success"
}
// Generated function automatically catches errors and rejects the Promise
```

### Async Error Handling

The `@Awaitable` macro uses PromiseKit's `.async()` method to convert Promise rejections to thrown errors:

```swift
@Awaitable
func promiseOperation() -> Promise<String> {
    return Promise { seal in
        if Bool.random() {
            seal.reject(APIError.networkFailure)
        } else {
            seal.fulfill("Success")
        }
    }
}
// Generated async function throws APIError.networkFailure when Promise rejects
```

## Implementation Details

### Generated Code Patterns

The macros generate code using established patterns:

**@AwaitlessPromise generates:**
```swift
func methodName() -> Promise<ReturnType> {
    return Promise { seal in
        Task {
            do {
                let result = try await self.methodName()
                seal.fulfill(result)
            } catch {
                seal.reject(error)
            }
        }
    }
}
```

**@Awaitable generates:**
```swift
@available(*, deprecated: "PromiseKit support is deprecated; use async function instead")
func methodName() async throws -> ReturnType {
    return try await self.methodName().async()
}
```

### PromiseKit.async() Integration

The `@Awaitable` macro leverages PromiseKit's native `.async()` extension method, which uses Swift's continuation APIs to properly bridge Promise completion to async/await contexts.

## Best Practices

### Migration Planning

1. **Start with @AwaitlessPromise**: Add Promise support to new async implementations first
2. **Gradual replacement**: Use @Awaitable to add async support to existing Promise code
3. **Deprecation strategy**: Use availability attributes to guide migration timeline
4. **Testing**: Ensure both APIs produce identical results during transition period
5. **Remove macros**: Once migration is complete, remove macros for clean async-only code

### Configuration Strategy

```swift
// Global configuration for organization-wide migration
AwaitlessConfig.setDefaults(
    prefix: "legacy_",
    availability: .deprecated("Migrate to async/await by end of Q2 2024")
)

// Type-specific configuration for different migration timelines
@AwaitlessConfig(availability: .deprecated("Critical: migrate by end of month"))
class CriticalService {
    @AwaitlessPromise
    func importantOperation() async throws -> Result {
        // Implementation
    }
}
```

### Error Handling Strategy

```swift
// Consistent error types across both APIs
enum APIError: Error {
    case networkFailure
    case invalidData
    case unauthorized
}

class APIService {
    @AwaitlessPromise
    func fetchData() async throws -> Data {
        // Throw APIError types that will be properly propagated to Promise rejection
        guard authenticated else { throw APIError.unauthorized }
        // Implementation
    }
    
    @Awaitable
    func legacyFetchData() -> Promise<Data> {
        return Promise { seal in
            // Reject with same APIError types for consistency
            guard authenticated else { 
                seal.reject(APIError.unauthorized)
                return 
            }
            // Implementation
        }
    }
}
```

## Common Patterns

### API Client Migration

```swift
class APIClient {
    // Modern async implementation with Promise compatibility
    @AwaitlessPromise(prefix: "promise_")
    func request<T: Codable>(_ endpoint: Endpoint) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: endpoint.urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // Legacy Promise implementation with async bridge
    @Awaitable(prefix: "async_", .deprecated("Use async request method instead"))
    func legacyRequest<T: Codable>(_ endpoint: Endpoint) -> Promise<T> {
        return URLSession.shared.dataTask(.promise, with: endpoint.urlRequest)
            .map(\.data)
            .map { try JSONDecoder().decode(T.self, from: $0) }
    }
}
```

### Repository Pattern

```swift
protocol UserRepository {
    func fetchUser(id: String) async throws -> User
    func saveUser(_ user: User) async throws
}

class NetworkUserRepository: UserRepository {
    @AwaitlessPromise(prefix: "promise_")
    func fetchUser(id: String) async throws -> User {
        // Modern async implementation
    }
    
    @AwaitlessPromise(prefix: "promise_")  
    func saveUser(_ user: User) async throws {
        // Modern async implementation
    }
}

// Enable legacy PromiseKit-based code to use modern repository
extension NetworkUserRepository {
    @Awaitable(.unavailable("Use async fetchUser instead"))
    func legacyFetchUser(id: String) -> Promise<User> {
        // This will be unavailable, forcing migration
        return Promise.value(User())
    }
}
```

This comprehensive PromiseKit integration enables smooth transitions between Promise-based and async/await architectures while maintaining full compatibility with existing codebases.