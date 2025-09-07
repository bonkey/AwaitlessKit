[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/bonkey/AwaitlessKit)
[![Tests](https://github.com/bonkey/AwaitlessKit/actions/workflows/test.yml/badge.svg)](https://github.com/bonkey/AwaitlessKit/actions/workflows/test.yml)
[![codecov](https://codecov.io/github/bonkey/awaitlesskit/graph/badge.svg?token=TV5h6MeO1D)](https://codecov.io/github/bonkey/awaitlesskit)

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbonkey%2FAwaitlessKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/bonkey/AwaitlessKit)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbonkey%2FAwaitlessKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/bonkey/AwaitlessKit)

# AwaitlessKit

**Automatically generate legacy sync interfaces for your `async/await` code, enabling easy migration to Swift 6 Structured Concurrency with both APIs available.**

`AwaitlessKit` provides Swift macros to automatically generate synchronous wrappers for your `async` functions, making it easy to call new async APIs from existing nonasync code. This helps you gradually adopt async/await without breaking old APIs or rewriting everything at once.

## Table of Contents

- [Quick Start](#quick-start)
- [Why AwaitlessKit?](#why-awaitlesskit)
- [Requirements](#requirements)
- [Installation](#installation)
- [Core Features](#core-features)
- [Quick Examples](#quick-examples)
- [Migration Guide](#migration-guide)
- [License](#license)
- [Credits](#credits)

## Quick Start

This example demonstrates the core functionality of AwaitlessKit - automatically generating synchronous wrappers for async functions to enable gradual migration to Swift 6 Structured Concurrency:

```swift
import AwaitlessKit

class DataService {
    @Awaitless
    func fetchUser(id: String) async throws -> User {
        let response = try await URLSession.shared.data(from: userURL(id))
        return try JSONDecoder().decode(User.self, from: response.0)
    }

    // Automatically generates a noasync counterpart:
    // @available(*, noasync) func fetchUser(id: String) throws -> User {
    //     try Noasync.run({
    //             try await fetchUser(id: id)
    //         })
    // }

    // Generate Combine publishers instead
    @AwaitlessPublisher
    func streamUserUpdates(id: String) async throws -> [UserUpdate] {
        // Your async implementation
        return []
    }
    // Generates: func streamUserUpdates(id: String) -> AnyPublisher<[UserUpdate], Error>
}

// Use both versions during migration
let service = DataService()
let user1 = try await service.fetchUser(id: "123")  // Async version
let user2 = try service.fetchUser(id: "456")        // Generated sync version

// Protocol-based approach with automatic implementations
@Awaitlessable
protocol UserRepository {
    func findUser(id: String) async throws -> User
}

struct DatabaseUserRepository: UserRepository {
    func findUser(id: String) async throws -> User {
        // Your async implementation
    }
    // Sync version automatically available: try findUser(id:)
}
```

## Why AwaitlessKit?

**The Problem:** Swift's async/await adoption is an "all-or-nothing" proposition. You can't easily call async functions from sync contexts, making incremental migration painful.

**The Solution:** `AwaitlessKit` automatically generates synchronous counterparts for your async functions, allowing you to:

- ✅ Migrate to `async/await` incrementally
- ✅ Maintain backward compatibility during transitions
- ✅ Avoid rewriting entire call chains at once
- ✅ Keep existing APIs stable while modernizing internals

> **⚠️ Important:** This library intentionally bypasses Swift's concurrency safety mechanisms. Use during migration periods only, not as a permanent solution.

## Requirements

**Swift 6.0+ compiler required** (available in Xcode 16 and above).

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/bonkey/AwaitlessKit.git", from: "6.1.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["AwaitlessKit"]
    )
]
```

## Core Features

### `@Awaitless` - automatic sync function generation

Generates synchronous wrappers for `async` functions with built-in deprecation controls. For Combine publisher wrappers, use `@AwaitlessPublisher`. For completion-handler wrappers, use `@AwaitlessCompletion`.

### Configuration System - four-level configuration hierarchy

AwaitlessKit provides a flexible configuration system with multiple levels of precedence:

1. **Process-Level Defaults** via `AwaitlessConfig.setDefaults()`
2. **Type-Scoped Configuration** via `@AwaitlessConfig` member macro
3. **Method-Level Configuration** via `@Awaitless` parameters
4. **Built-in Defaults** as fallback

### `@Awaitlessable` - protocol extension generation

Automatically generates sync method signatures and optional default implementations for protocols with async methods.

### `#awaitless()` - inline async code execution

Execute async code blocks synchronously.

### `@IsolatedSafe` - generate thread-safe properties

Automatic runtime thread-safe wrappers for `nonisolated(unsafe)` properties with configurable synchronization strategies.

### `Noasync.run()` - low-level bridge

Direct function for running async code in sync contexts.

## Quick Examples

### Basic Usage

This example shows the simplest use case - adding the `@Awaitless` macro to an async function to automatically generate a synchronous counterpart:

```swift
import AwaitlessKit

class NetworkManager {
    @Awaitless
    func downloadFile(url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    // Generated automatically:
    // @available(*, noasync) func downloadFile(url: URL) throws -> Data {
    //    try Noasync.run({
    //            try await downloadFile(url: url)
    //        })
    // }
}

// Usage
let data = try NetowrkManager().downloadFile(url: fileURL) // Sync call
```

### Migration with Deprecation

During migration, you can mark the generated synchronous functions as deprecated to encourage adoption of the async versions while maintaining backward compatibility:

```swift
class LegacyService {
    @Awaitless(.deprecated("Use async version. Non-async version will be removed in v2.0"))
    func processData() async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000)
        return "Processed"
    }
}

// Calling sync version shows deprecation warning
let result = try service.processData() // ⚠️ Deprecated warning
```

### Custom Naming

When you need to avoid naming conflicts or follow specific conventions, you can customize the prefix for generated synchronous functions:

```swift
class APIClient {
    @Awaitless(prefix: "sync_")
    func authenticate() async throws -> Token {
        try await Task.sleep(nanoseconds: 1_000_000)
    }
    // Generates:
    // @available(*, noasync) func sync_authenticate() throws {
    //     try Noasync.run({
    //             try await authenticate()
    //         })
    // }
}
```

### Process-Level Configuration

Configure default behavior for all AwaitlessKit macros across your entire application by setting process-level defaults at startup:

```swift
// Set defaults at application startup
AwaitlessConfig.setDefaults(
    prefix: "sync_",
    availability: .deprecated("Migrate to async APIs by 2025"),
    delivery: .main,
    strategy: .concurrent
)

class NetworkService {
    @Awaitless  // Uses process defaults: prefix "sync_" and deprecated availability
    func fetchData() async throws -> Data {
        // Implementation
    }
    // Generates: @available(*, deprecated: "Migrate to async APIs by 2025")
    //            func sync_fetchData() throws -> Data
}
```

### Configuration Hierarchy Example

This example demonstrates how AwaitlessKit's four-level configuration system works, with method-level overrides taking precedence over type-scoped, which overrides process-level defaults:

```swift
// 1. Process-level defaults (global configuration)
AwaitlessConfig.setDefaults(prefix: "global_", availability: .deprecated("Global migration"))

// 2. Type-scoped configuration
@AwaitlessConfig(prefix: "type_")
class ServiceManager {

    // 3. Method uses type prefix, global availability
    @Awaitless
    func loadData() async throws -> Data {
        // Generates: @available(*, deprecated: "Global migration")
        //            func type_loadData() throws -> Data
    }

    // 4. Method-level override of both (local configuration)
    @Awaitless(prefix: "local_", .noasync)
    func urgentOperation() async throws -> Result {
        // Generates: @available(*, noasync)
        //            func local_urgentOperation() throws -> Result
    }
}
```

### Combine Publisher Output

Instead of generating synchronous functions, you can generate Combine publishers for reactive programming patterns, with optional delivery queue control:

```swift
import Combine

class AsyncService {
    @AwaitlessPublisher
    func fetchData() async throws -> [String] {
        // Async implementation
        return ["data1", "data2"]
    }

    // Generates:
    // func fetchData() -> AnyPublisher<[String], Error> {
    //     Future({ promise in
    //         Task() {
    //             do {
    //                 let result = try await self.fetchData()
    //                 promise(.success(result))
    //             } catch {
    //                 promise(.failure(error))
    //             }
    //         }
    //     }).eraseToAnyPublisher()
    // }
}

// Delivery control for UI consumers
class UIService {
    // Deliver publisher events on the main queue
    @AwaitlessPublisher(deliverOn: .main)
    func loadUIData() async throws -> [Item] {
        // Async implementation
        return []
    }
    // Generates:
    // func loadUIData() -> AnyPublisher<[Item], Error> {
    //     Future({ promise in
    //         Task() {
    //             do { promise(.success(try await self.loadUIData())) }
    //             catch { promise(.failure(error)) }
    //         }
    //     })
    //     .receive(on: DispatchQueue.main) // delivery control
    //     .eraseToAnyPublisher()
    // }
}
```

### Completion-Based Output

For compatibility with completion-handler based APIs, generate functions that use `Result` completion handlers instead of throwing:

```swift
class CompletionService {
    @AwaitlessCompletion
    func fetch() async throws -> String { "OK" }

    // Generates:
    // func fetch(completion: @escaping (Result<String, Error>) -> Void) {
    //     Task() {
    //         do {
    //             let result = try await self.fetch()
    //             completion(.success(result))
    //         } catch {
    //             completion(.failure(error))
    //         }
    //     }
    // }
}
```

### Protocol Extensions with Default Implementations

The `@Awaitlessable` macro automatically generates synchronous method signatures and default implementations for protocols, eliminating boilerplate code:

```swift
@Awaitlessable
protocol DataService {
    func fetchUser(id: String) async throws -> User
    func fetchData() async -> Data
}

// Automatically generates:
// protocol DataService {
//     func fetchUser(id: String) async throws -> User
//     func fetchData() async -> Data
//
//     // Sync method signatures
//     func fetchUser(id: String) throws -> User
//     func fetchData() -> Data
// }
//
// extension DataService {
//     // Default implementations using Noasync.run
//     public func fetchUser(id: String) throws -> User {
//         return try Noasync.run { try await self.fetchUser(id: id) }
//     }
//
//     public func fetchData() -> Data {
//         return Noasync.run { await self.fetchData() }
//     }
// }

// Usage - just implement the protocol
struct MyService: DataService {
    func fetchUser(id: String) async throws -> User {
        // Your async implementation
    }

    func fetchData() async -> Data {
        // Your async implementation
    }

    // Sync versions are automatically available!
}

let service = MyService()
let user = try service.fetchUser(id: "123") // Uses generated sync version
```

### Thread-Safe Properties with Synchronization Strategies

The `@IsolatedSafe` macro generates thread-safe property accessors for `nonisolated(unsafe)` properties with configurable synchronization strategies:

```swift
class SharedState: Sendable {
    @IsolatedSafe
    private nonisolated(unsafe) var _unsafeCounter: Int = 0

    @IsolatedSafe(writable: true, strategy: .concurrent)
    private nonisolated(unsafe) var _unsafeItems: [String] = []

    @IsolatedSafe(writable: true, strategy: .serial, queueName: "custom.queue")
    private nonisolated(unsafe) var _criticalData: Data? = nil

    // Generates thread-safe accessors with appropriate synchronization
}
```

## Migration Guide

### Phase 1: Add Async Code with autogenerated sync function

Start migration by implementing new async functions while automatically maintaining synchronous compatibility for existing callers:

```swift
class DataManager {
    // Autogenerate noasync version alongside new async function
    @Awaitless
    func loadData() async throws -> [String] {
        // New async implementation
    }
}
```

### Phase 2: Deprecate generated sync function

Add deprecation warnings to encourage migration to async versions while still providing the synchronous fallback:

```swift
class DataManager {
    @Awaitless(.deprecated("Migrate to async version by Q2 2026"))
    func loadData() async throws -> [String] {
        // Implementation
    }
}
```

### Phase 3: Make sync function unavailable

Force migration by making the synchronous version unavailable, providing clear error messages about required changes:

```swift
class DataManager {
    @Awaitless(.unavailable("Sync version removed. Use async version only"))
    func loadData() async throws -> [String] {
        // Implementation
    }
}
```

### Phase 4: Remove macro and autogenerated function

Complete the migration by removing the AwaitlessKit macro entirely, leaving only the pure async implementation:

```swift
class DataManager {
    func loadData() async throws -> [String] {
        // Pure async implementation
    }
}
```

## License

MIT License. See [LICENSE](LICENSE) for details.

## Credits

- **Wade Tregaskis** for `Task.noasync` from [Calling Swift Concurrency async code synchronously in Swift](https://wadetregaskis.com/calling-swift-concurrency-async-code-synchronously-in-swift/)
- **[Zed Editor](https://zed.dev)** for its powerful agentic GenAI support
- **Anthropic** for Claude 3.7 and 4.0 models

---

**Remember:** AwaitlessKit is a migration tool, not a permanent solution. Plan your async/await adoption strategy and use this library to smooth the transition.
