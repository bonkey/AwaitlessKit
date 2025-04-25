[![Swift Tests](https://github.com/bonkey/AwaitlessKit/actions/workflows/test.yml/badge.svg)](https://github.com/bonkey/AwaitlessKit/actions/workflows/test.yml)

# AwaitlessKit

- [Overview](#overview)
  - [`#awaitless()`](#awaitless)
  - [`@Awaitless`](#awaitless-1)
  - [`@IsolatedSafe`](#isolatedsafe)
- [Usage](#usage)
  - [Awaitless](#awaitless-2)
  - [IsolatedSafe](#isolatedsafe-1)
- [Installation](#installation)
- [Credits](#credits)

## Overview

`AwaitlessKit` is a collection of Swift macros and utilities that let you commit unspeakable asynchronous sins - like calling `async` functions from synchronous contexts without awaiting them properly.

> **Warning!** This package is the equivalent of using a chainsaw to butter your toast. It might work, but think twice if you want to use it in production code.

### `#awaitless()`

A freestanding expression macro that executes `async` code blocks synchronously.

Particularly valuable when interfacing with third-party APIs or legacy systems where asynchronous context isn't available, but you need to integrate with your `async` implementations.

### `@Awaitless`

An attached macro that automatically generates synchronous counterparts for your `async` functions.

Ideal for API design patterns requiring both synchronous and asynchronous interfaces, eliminating the need to manually maintain duplicate implementations and providing simple deprecation for the future.

### `@IsolatedSafe`

An attached property macro that implements a serial dispatch queue to provide thread-safe access to `nonisolated(unsafe)` properties.

Offers runtime concurrency protection when compile-time isolation isn't feasible, effectively preventing data races through a property protected with `DispatchQueue`.

## Usage

### Awaitless

```swift
import AwaitlessKit

final class AwaitlessExample: Sendable {
    // Basic usage - generates a sync version with same name
    @Awaitless
    func fetchData() async throws -> Data {
        // ...async implementation
    }

    func onlyAsyncFetchData() async throws -> Data {
        // ...async implementation
    }

    // With deprecation warning
    @Awaitless(.deprecated("Synchronous API will be phased out, migrate to async version"))
    func processItems() async throws -> [String] {
        // ...async implementation
    }

    // Make sync version unavailable
    @Awaitless(.unavailable("Synchronous API has been removed, use async version"))
    func loadResources() async throws -> [Resource] {
        // ...async implementation
    }

    // Custom prefix for generated function
    @Awaitless(prefix: "sync_")
    func loadConfig() async -> Config {
        // ...async implementation
    }

    public func run() {
        // Call generated sync versions
        let data = try fetchData()
        let items = try processItems() // Shows deprecation warning
        let config = sync_loadConfig()

        // Or use the freestanding macro
        let result = try #awaitless(try onlyAsyncFetchData())
    }
}
```

### IsolatedSafe

```swift
final class IsolatedSafeExample: Sendable {
    // (1a) Thread-safe wrapper for unsafe property access
    @IsolatedSafe
    private nonisolated(unsafe) var _unsafeStrings: [String] = ["Hello", "World"]

    // (2a) Thread-safe wrapper with write access
    @IsolatedSafe(writable: true)
    private nonisolated(unsafe) var _unsafeProcessCount: Int = 0

    public func run() {
        // (1b) Safe access to _unsafeStrings through generated accessors
        strings.append("and")
        strings.append("universe")

        // (2b) Safe access to _unsafeProcessCount through generated accessors
        processCount += 1
    }
}
```

## Installation

Add `AwaitlessKit` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AwaitlessKit.git", from: "2.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["AwaitlessKit"]
    )
]
```
 
## SampleApp

The `SampleApp` included in the repo is just a simple demo app showing these features in action.

## Credits

- Wade Tregaskis for `Task.noasync` from [Calling Swift Concurrency async code synchronously in Swift](https://wadetregaskis.com/calling-swift-concurrency-async-code-synchronously-in-swift/)
- [Zed Editor](https://zed.dev) for its powerful GenAI support and Claude 3.7 model
