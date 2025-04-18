# AwaitlessKit

Helps you to do bad things: use `async` without `await` and other blasphemies.

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Warning](#warning)

## Overview

AwaitlessKit is a collection of Swift macros and utilities that let you commit unspeakable asynchronous sins - like calling async functions from synchronous contexts without awaiting them properly. The Swift Concurrency Police™ would like to have a word with you.

## Features

- **@Awaitless**: Macro that generates a synchronous version of your async functions
- **#awaitless()**: Free-standing macro to execute async expressions synchronously
- **@IsolatedSafe**: Macro for thread-safe access to nonisolated(unsafe) properties

## Installation

Add AwaitlessKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AwaitlessKit.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["AwaitlessKit"],
        plugins: [
            .plugin(name: "AwaitlessKitMacros", package: "AwaitlessKit")
        ]
    )
]
```

## Usage

```swift
import AwaitlessKit

// Mark async functions to generate sync versions
@Awaitless
private func fetchData() async throws -> Data {
    // ... async code
}

// Now you can call the generated sync version
let data = try awaitless_fetchData()

// Or use the freestanding macro
let result = #awaitless(await processStuff())
```

## Warning

This package is the programming equivalent of using a chainsaw to butter your toast. It might work, but it's probably not a good idea for production code. Use responsibly.

> The `AwaitlessApp` included in the repo is just a simple demo app showing these features in action.
