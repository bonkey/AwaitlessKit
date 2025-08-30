[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/bonkey/AwaitlessKit) [![Tests on Xcode 16](https://github.com/bonkey/AwaitlessKit/actions/workflows/swift_test_xcode16.yml/badge.svg)](https://github.com/bonkey/AwaitlessKit/actions/workflows/swift_test_xcode16.yml) [![Tests on Linux](https://github.com/bonkey/AwaitlessKit/actions/workflows/swift_test_linux.yml/badge.svg)](https://github.com/bonkey/AwaitlessKit/actions/workflows/swift_test_linux.yml)

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbonkey%2FAwaitlessKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/bonkey/AwaitlessKit) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbonkey%2FAwaitlessKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/bonkey/AwaitlessKit)

# AwaitlessKit

**Automatically generate legacy sync interfaces for your `async/await` code—enabling easy migration from Swift 5 to Swift 6 with both APIs available.**

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
    @Awaitless(as: .publisher)
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

| Swift Compiler Version | Xcode Version | Support Level    |
| ---------------------- | ------------- | ---------------- |
| Swift 6.0+             | Xcode 16+     | ✅ Full support  |
| Swift 5.x              | Xcode 15-     | ❌ Not supported |

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/bonkey/AwaitlessKit.git", from: "7.0.0")
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

Generates synchronous wrappers for `async` functions with built-in deprecation controls and optional Combine publisher output.

### `@Awaitlessable` - protocol extension generation

Automatically generates sync method signatures and optional default implementations for protocols with async methods.

### `#awaitless()` - inline async code execution

Execute async code blocks synchronously (Swift 6.0+ only).

### `@IsolatedSafe` - generate thread-safe properties

Automatic runtime thread-safe wrappers for `nonisolated(unsafe)` properties with configurable synchronization strategies.

### `Noasync.run()` - low-level bridge

Direct function for running async code in sync contexts.

## Quick Examples

### Basic Usage

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

### Combine Publisher Output

```swift
import Combine

class AsyncService {
    @Awaitless(as: .publisher)
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
```

### Protocol Extensions with Default Implementations

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

### Configurable Protocol Extension Generation

```swift
// Default behavior - generates both protocol members and extensions
@Awaitlessable
protocol NetworkService {
    func downloadFile(url: URL) async throws -> Data
}

// Explicitly enable extension generation
@Awaitlessable(extensionGeneration: .enabled)
protocol APIService {
    func fetchUser(id: String) async throws -> User
}

// Disable extension generation - only protocol members
@Awaitlessable(extensionGeneration: .disabled)
protocol CustomService {
    func processData() async -> Result
    // Must implement sync version manually
}
```

### Thread-Safe Properties with Synchronization Strategies

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

### Phase 1: Add Async Code

```swift
class DataManager {
    // Autogenetate noasync version alongside new async function
    @Awaitless
    func loadData() async throws -> [String] {
        // New async implementation
    }
}
```

### Phase 2: Deprecate Generated Sync

```swift
class DataManager {
    @Awaitless(.deprecated("Migrate to async version by Q2 2024"))
    func loadData() async throws -> [String] {
        // Implementation
    }
}
```

### Phase 3: Remove Sync Support

```swift
class DataManager {
    @Awaitless(.unavailable("Sync version removed. Use async version only"))
    func loadData() async throws -> [String] {
        // Implementation
    }
}
```

### Phase 4: Remove Macro

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

**\*Remember:** AwaitlessKit is a migration tool, not a permanent solution. Plan your async/await adoption strategy and use this library to smooth the transition.\*
