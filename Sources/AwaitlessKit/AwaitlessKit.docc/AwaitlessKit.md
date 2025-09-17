# AwaitlessKit

### Concurrency & Sendable Summary

For best results with macro-generated synchronous, completion, and publisher wrappers in Swift 6:

- Mark service / repository classes as `final` and `Sendable` when their async methods are wrapped (`@Awaitless`, `@AwaitlessPublisher`, `@AwaitlessCompletion`).
- Mark protocols annotated with `@Awaitlessable` as `Sendable` if conformers cross task or actor boundaries.
- Prefer value-semantic / `Sendable` model types for parameters and returns to reduce isolation warnings.
- Use `@IsolatedSafe` for mutable shared state that is accessed from generated sync wrappers or Task-backed publishers.
- Non-throwing async functions generate `AnyPublisher<Output, Never>`; throwing ones generate `AnyPublisher<Output, Error>`.
- Use `deliverOn: .main` only for UI-facing publishers; default `.current` avoids extra queue hops.
- Encapsulate legacy non-Sendable dependencies behind audited `final` façade types (only use `@unchecked Sendable` after careful review).

This section is a summary—see the detailed guidance in the Usage, Migration, and Macro Implementation articles for deeper rationale and patterns.

Automatically generate legacy sync interfaces for your async/await code, enabling easy migration to Swift 6 Structured Concurrency.

## Overview

AwaitlessKit provides Swift macros to automatically generate synchronous wrappers for your `async` functions, making it easy to call new async APIs from existing nonasync code. This helps you gradually adopt async/await without breaking old APIs or rewriting everything at once.

### Key Features

- **@Awaitless** - Generate synchronous wrappers for async functions
- **@AwaitlessPublisher** - Generate Combine publishers from async functions
- **@AwaitlessCompletion** - Generate completion-handler wrappers
- **@Awaitlessable** - Protocol extension generation for async protocols
- **Configuration System** - Four-level configuration hierarchy for flexible customization
- **#awaitless()** - Inline async code execution in sync contexts
- **@IsolatedSafe** - Thread-safe property wrappers

### Configuration Hierarchy

AwaitlessKit provides a flexible configuration system with four levels of precedence:

1. **Process-Level Defaults** via `AwaitlessConfig/setDefaults(prefix:availability:delivery:strategy:)`
2. **Type-Scoped Configuration** via `AwaitlessConfig` member macro
3. **Method-Level Configuration** via `Awaitless` parameters
4. **Built-in Defaults** as fallback

## Quick Start

Add the `@Awaitless` macro to your async functions to automatically generate synchronous wrappers:

```swift
import AwaitlessKit

class DataService {
    @Awaitless
    func fetchUser(id: String) async throws -> User {
        // Your async implementation
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(User.self, from: data)
    }
    // Generates: func fetchUser(id: String) throws -> User
}

// Use both versions during migration
let service = DataService()
let user1 = try await service.fetchUser(id: "123")  // Async version
let user2 = try service.fetchUser(id: "456")        // Generated sync version
```

For comprehensive examples and real-world usage patterns, see <doc:Examples>.

## Topics

### Primary Macros

- `Awaitless`
- `AwaitlessPublisher`
- `AwaitlessCompletion`
- `Awaitlessable`

### Configuration System

- `AwaitlessConfig`
- `AwaitlessAvailability`
- `AwaitlessDelivery`
- `AwaitlessSynchronizationStrategy`

### Utility Macros

- `awaitless(_:)`
- `IsolatedSafe`

### Low-Level API

- `Awaitless`

### Comprehensive Guides

- <doc:UsageGuide>
- <doc:Examples>
- <doc:Configuration>
- <doc:MigrationGuide>
- <doc:MacroImplementation>

## Migration Strategy

> Important: AwaitlessKit is a migration tool, not a permanent solution. Use during transition periods to gradually adopt async/await while maintaining backward compatibility.

### Recommended Migration Path

1. **Add async implementations** with `@Awaitless` to generate sync counterparts
2. **Deprecate sync versions** using availability attributes
3. **Migrate calling code** to async versions over time
4. **Remove sync support** when migration is complete
5. **Remove macros** for pure async implementation

For detailed migration strategies and real-world scenarios, see <doc:MigrationGuide>.

## Configuration Examples

```swift
import AwaitlessKit

// Set process-level defaults
AwaitlessConfig.setDefaults(prefix: "sync_", availability: .deprecated("Migrate to async"))

// Type-scoped configuration
@AwaitlessConfig(prefix: "blocking_")
class NetworkService {
    @Awaitless  // Inherits configuration: blocking_fetchData with deprecation
    func fetchData() async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    @Awaitless(prefix: "immediate_")  // Method-level override
    func quickCheck() async -> Bool {
        // Implementation
    }
}

// Usage with both APIs available
let service = NetworkService()
let data1 = try await service.fetchData()      // Async version
let data2 = try service.blocking_fetchData()   // Generated sync version
```

For complete configuration documentation and advanced patterns, see <doc:Configuration>.

## Implementation Details

AwaitlessKit macros use SwiftSyntax to analyze your async code and automatically generate corresponding synchronous wrapper functions. All macros follow a consistent architecture pattern for reliability and maintainability.

For comprehensive implementation details and extending AwaitlessKit, see <doc:MacroImplementation>.
