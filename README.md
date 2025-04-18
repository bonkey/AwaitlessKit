# AwaitlessKit

- [Overview](#overview)
- [Usage](#usage)
- [Installation](#installation)
- [Credits](#credits)

## Overview

`AwaitlessKit` is a collection of Swift macros and utilities that let you commit unspeakable asynchronous sins - like calling `async` functions from synchronous contexts without awaiting them properly.

> **Warning!** This package is the equivalent of using a chainsaw to butter your toast. It might work, but think twice if you want to use it in production code. Use responsibly.

- `#awaitless()`: Free-standing macro to execute `async` expressions synchronously
- `@Awaitless`: Macro that generates a synchronous version of your `async` functions
- `@IsolatedSafe`: Macro to create thread-safe queue for accessing `nonisolated(unsafe)` properties

## Usage

```swift
import AwaitlessKit

final class FooBar: Sendable {
    // (1) Mark async functions to generate sync versions
    @Awaitless
    private func fetchData() async throws -> Data {
        // ...
    }

    public func run() {}
        // (2a) Now you can call the generated sync version
        let data = try awaitless_fetchData()

        // (2b) Or use the freestanding macro
        let result = try #awaitless(try fetchData())

        // Safe access to _unsafeStrings
        strings.append("and")
        strings.append("universe")

        // Safe access to _unsafeProcessCount
        processCount += 1
    }

    @IsolatedSafe
    private nonisolated(unsafe) var _unsafeStrings: [String] = ["Hello", "World"]
    
    @IsolatedSafe(writable: true)
    private nonisolated(unsafe) var _unsafeProcessCount: Int = 0
}

```

## Installation

Add `AwaitlessKit` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AwaitlessKit.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["AwaitlessKit"]
    )
]
```

> The `AwaitlessApp` included in the repo is just a simple demo app showing these features in action.

## Credits

Wade Tregaskis for `Task.noasync` from [Calling Swift Concurrency async code synchronously in Swift](https://wadetregaskis.com/calling-swift-concurrency-async-code-synchronously-in-swift/)
