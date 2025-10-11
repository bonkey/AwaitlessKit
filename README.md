[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/bonkey/AwaitlessKit)
[![Tests](https://github.com/bonkey/AwaitlessKit/actions/workflows/package-tests.yml/badge.svg)](https://github.com/bonkey/AwaitlessKit/actions/workflows/package-tests.yml)
[![codecov](https://codecov.io/github/bonkey/awaitlesskit/graph/badge.svg?token=TV5h6MeO1D)](https://codecov.io/github/bonkey/awaitlesskit)

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbonkey%2FAwaitlessKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/bonkey/AwaitlessKit)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbonkey%2FAwaitlessKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/bonkey/AwaitlessKit)

# AwaitlessKit

**Automatically generate legacy sync interfaces for your `async/await` code, enabling easy migration to Swift 6 Structured Concurrency with both APIs available.**

`AwaitlessKit` provides Swift macros to automatically generate synchronous wrappers for your `async` functions, making it easy to call async APIs from existing synchronous code. This helps you adopt async/await without breaking existing APIs or rewriting entire call chains at once.

## Table of Contents <!-- omit in toc -->

- [Quick Start](#quick-start)
- [Why AwaitlessKit?](#why-awaitlesskit)
- [Installation](#installation)
- [Core Features](#core-features)
- [More Examples](#more-examples)
- [Documentation](#documentation)
- [Migration Overview](#migration-overview)
- [License](#license)
- [Credits](#credits)

## Quick Start

Add the `@Awaitless` macro to your async functions to automatically generate synchronous wrappers:

```swift
import AwaitlessKit

class DataService {
    @Awaitless
    func fetchUser(id: String) async throws -> User {
        // Your async implementation
    }
    // Generates: @available(*, noasync) func fetchUser(id: String) throws -> User
}

// Use both versions during migration
let service = DataService()
let user1 = try await service.fetchUser(id: "123")  // Async version
let user2 = try service.fetchUser(id: "456")        // Generated sync version
```

See [more examples](#more-examples) or [documentation](#documentation) for more sophisticated cases.

## Why AwaitlessKit?

**The Problem:** Swift's async/await adoption is an "all-or-nothing" proposition. You can't easily call async functions from sync contexts, making incremental migration painful.

**The Solution:** `AwaitlessKit` automatically generates synchronous counterparts for your async functions, allowing you to:

- ✅ Migrate to `async/await` incrementally
- ✅ Maintain backward compatibility during transitions
- ✅ Avoid rewriting entire call chains at once
- ✅ Keep existing APIs stable while modernizing internals

> **⚠️ Important:** This library bypasses Swift's concurrency safety mechanisms. It is a migration tool, not a permanent solution.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/bonkey/AwaitlessKit.git", from: "9.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["AwaitlessKit"]
    )
]
```

**Swift 6.0+ compiler required** (available in Xcode 16 and above).

## Core Features

AwaitlessKit provides **bidirectional conversion** between async/await and legacy callback-based APIs:

### `@Awaitless*` Family - async → sync conversion

Generates synchronous wrappers for `async` functions with built-in deprecation controls.

- **`@Awaitless`** - Generates synchronous throwing functions that can be called directly from non-async contexts
- **`@AwaitlessPublisher`** - Generates Combine `AnyPublisher` wrappers for reactive programming patterns
- **`@AwaitlessCompletion`** - Generates completion-handler based functions using `Result` callbacks

### `@Awaitable*` Family - sync → async conversion  

Generates async/await wrappers for legacy callback-based functions, enabling migration to modern Swift concurrency.

- **`@AwaitablePublisher`** - Converts Combine `AnyPublisher` functions to async/await using `.async()`
- **`@AwaitableCompletion`** - Converts completion-handler functions to async/await using `withCheckedThrowingContinuation`
- **`@Awaitable`** - Protocol macro that generates async versions of both Publisher and completion-handler methods

### PromiseKit Integration

Bidirectional PromiseKit integration (separate `AwaitlessKit-PromiseKit` product):

- **`@AwaitlessPromise`** - async → Promise conversion
- **`@AwaitablePromise`** - Promise → async conversion

### Protocol Support

- **`@Awaitlessable`** - Generates sync method signatures for protocols with async methods
- **`@Awaitable`** - Generates async method signatures for protocols with Publisher/completion methods

### `#awaitless()` - inline async code execution

Execute async code blocks synchronously in non-async contexts.

### `@IsolatedSafe` - generate thread-safe properties

Automatic runtime thread-safe wrappers for `nonisolated(unsafe)` properties with configurable synchronization strategies.

### `Awaitless.run()` - low-level bridge

Direct function for running async code in sync contexts with fine-grained control.

### Configuration System - four-level configuration hierarchy

AwaitlessKit provides a flexible configuration system with multiple levels of precedence for customizing generated code behavior.

1. **Process-Level Defaults** via `AwaitlessConfig.setDefaults()`
2. **Type-Scoped Configuration** via `@AwaitlessConfig` member macro
3. **Method-Level Configuration** via `@Awaitless` parameters
4. **Built-in Defaults** as fallback

## More Examples

### Non-async Function

```swift
class APIService {
    @Awaitless
    func fetchData() async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    // Generates: @available(*, noasync) func fetchData() throws -> Data
}
```

### Combine Publisher

`@AwaitlessPublisher` generates a publisher backed by a dedicated cancellation-aware task publisher. This provides:

- Correct cancellation propagation (cancelling the subscription cancels the underlying `Task`)
- Memory behavior (no retained promise closure beyond execution)
- Semantic clarity (single-shot mapping of async result to a Combine stream)
- Clear failure typing: non-throwing async -> `AnyPublisher<Output, Never>`, throwing async -> `AnyPublisher<Output, Error>`

Throwing example:

```swift
class APIService {
    @AwaitlessPublisher
    func fetchData() async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    // Generates: func fetchData() -> AnyPublisher<Data, Error>
}
```

Non-throwing example:

```swift
class TimeService {
    @AwaitlessPublisher
    func currentTimestamp() async -> Int {
        Int(Date().timeIntervalSince1970)
    }
    // Generates: func currentTimestamp() -> AnyPublisher<Int, Never>
}
```

Main thread delivery:

```swift
class ProfileService {
    @AwaitlessPublisher(deliverOn: .main)
    func loadProfile(id: String) async throws -> Profile {
        // ...
    }
    // Generated publisher delivers value & completion on DispatchQueue.main
}
```

Under the hood the macro calls an internal factory that uses `TaskThrowingPublisher` / `TaskPublisher` (adapted from a Swift Forums discussion on correctly bridging async functions to Combine) to produce the `AnyPublisher`.

### PromiseKit Integration

**Bidirectional conversion** between async/await and PromiseKit with `@AwaitlessPromise` and `@Awaitable`:

```swift
// Add PromiseKit integration to Package.swift
.product(name: "AwaitlessKit-PromiseKit", package: "AwaitlessKit")
```

**Async to Promise conversion:**

```swift
import AwaitlessKit
import PromiseKit

class NetworkService {
    @AwaitlessPromise(prefix: "promise_")
    func fetchData() async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    // Generates: func promise_fetchData() -> Promise<Data>
}

// Use with PromiseKit
service.promise_fetchData()
    .done { data in print("Success: \(data)") }
    .catch { error in print("Error: \(error)") }
```

**Promise to async conversion:**

```swift
class LegacyService {
    @Awaitable(prefix: "async_")
    func legacyFetchData() -> Promise<Data> {
        return URLSession.shared.dataTask(.promise, with: url).map(\.data)
    }
    // Generates: 
    // @available(*, deprecated: "PromiseKit support is deprecated; use async function instead")
    // func async_legacyFetchData() async throws -> Data
}

// Use with async/await
let data = try await service.async_legacyFetchData()
```

Perfect for **gradual migration** between PromiseKit and async/await architectures.

### Completion Handler

```swift
class APIService {
    @AwaitlessCompletion
    func fetchData() async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    // Generates: func fetchData(completion: @escaping (Result<Data, Error>) -> Void)
}
```

## Documentation

AwaitlessKit includes comprehensive DocC documentation with detailed guides, examples, and API reference.

**📖 [Complete Documentation](https://swiftpackageindex.com/bonkey/AwaitlessKit/main/documentation/awaitlesskit)**

### Key Documentation Sections

- **[Usage Guide](https://swiftpackageindex.com/bonkey/AwaitlessKit/main/documentation/awaitlesskit/usageguide)** - Quick reference with practical examples and common patterns
- **[Examples Guide](https://swiftpackageindex.com/bonkey/AwaitlessKit/main/documentation/awaitlesskit/examples)** - Comprehensive examples from basic usage to advanced patterns
- **[PromiseKit Integration](https://swiftpackageindex.com/bonkey/AwaitlessKit/main/documentation/awaitlesskit/promisekitintegration)** - Bidirectional conversion between async/await and PromiseKit
- **[Configuration System](https://swiftpackageindex.com/bonkey/AwaitlessKit/main/documentation/awaitlesskit/configuration)** - Four-level configuration hierarchy and customization options
- **[Migration Guide](https://swiftpackageindex.com/bonkey/AwaitlessKit/main/documentation/awaitlesskit/migrationguide)** - Step-by-step migration strategies and best practices
- **[Macro Implementation](https://swiftpackageindex.com/bonkey/AwaitlessKit/main/documentation/awaitlesskit/macroImplementation)** - Technical details for extending and contributing to AwaitlessKit

### What You'll Find

- **Quick Reference** - Fast lookup for common macro usage patterns and configurations
- **Real-world Examples** - From simple async functions to complex migration scenarios
- **PromiseKit Integration** - Complete bidirectional conversion guide with migration strategies
- **Configuration Patterns** - Process-level, type-scoped, and method-level configuration examples
- **Migration Strategies** - Progressive deprecation, brownfield conversion, and testing approaches
- **Best Practices** - Naming conventions, error handling, and testing approaches
- **Technical Details** - Macro implementation, SwiftSyntax integration, and extension points

The documentation is designed to help you successfully adopt async/await in your projects while maintaining backward compatibility during the transition period.

## Migration Overview

### Phase 1: Add Async Code with autogenerated sync function

Implement async functions while maintaining synchronous compatibility for existing callers:

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
