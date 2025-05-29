[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/bonkey/AwaitlessKit)

[![Tests on Xcode 16](https://github.com/bonkey/AwaitlessKit/actions/workflows/swift_test_xcode16.yml/badge.svg)](https://github.com/bonkey/AwaitlessKit/actions/workflows/swift_test_xcode16.yml)
[![Build on Xcode 15](https://github.com/bonkey/AwaitlessKit/actions/workflows/swift_build_xcode15.yml/badge.svg)](https://github.com/bonkey/AwaitlessKit/actions/workflows/swift_build_xcode15.yml)
[![Tests on Linux](https://github.com/bonkey/AwaitlessKit/actions/workflows/swift_test_linux.yml/badge.svg)](https://github.com/bonkey/AwaitlessKit/actions/workflows/swift_test_linux.yml)

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbonkey%2FAwaitlessKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/bonkey/AwaitlessKit)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbonkey%2FAwaitlessKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/bonkey/AwaitlessKit)

# AwaitlessKit

`AwaitlessKit` is a collection of Swift macros and utilities that lets you commit unspeakable asynchronous sins - like calling `async` functions from a `nonasync` context without awaiting them properly.

In other words, it simplifies the migration to `async/await` code from Structured Concurrency using some loopholes. It likely performs better than your ad hoc hacks.

> **Remember!** This framework deliberately sidesteps type-safety guardrails. Though it leverages battle-tested patterns, do your due diligence on edge cases before using it in production.

- [Motivation](#motivation)
- [Requirements](#requirements)
- [Available macros](#available-macros)
  - [`#awaitless()`](#awaitless)
  - [`@Awaitless`](#awaitless-1)
  - [`@IsolatedSafe`](#isolatedsafe)
- [Available functions](#available-functions)
  - [`Noasync.run()`](#noasyncrun)
- [Usage](#usage)
  - [Awaitless](#awaitless-2)
  - [IsolatedSafe](#isolatedsafe-1)
- [Installation](#installation)
- [SampleApp](#sampleapp)
- [Credits](#credits)

## Motivation

From Swift's Evolution [Improving the approachability of data-race safety](https://github.com/hborla/swift-evolution/blob/approachable-concurrency-vision/visions/approachable-concurrency.md#bridging-between-synchronous-and-asynchronous-code):

> Introducing async/await into an existing codebase is difficult to do incrementally, because the language does not provide tools to bridge between synchronous and asynchronous code. Sometimes programmers can kick off a new unstructured task to perform the async work, and other times that is not suitable, e.g. because the synchronous code needs a result from the async operation. It’s also not always possible to propagate async throughout callers, because the function signature might be declared in a library dependency that you don’t own.

`AwaitlessKit` aims to bridge that gap and simplify the adoption of `async/await`.

## Requirements

While `AwaitlessKit` *should* work with Xcode 15 and Swift 5.x, it's less tested, and support is considered **experimental**.

For the best experience, Xcode 16 with Swift 6.0 compiler is highly recommended. Your project can still be in Swift 5.x.

## Available macros

### `#awaitless()`

*Note: not yet available in Swift 5.x / Xcode 15*

A freestanding expression macro that executes `async` code blocks synchronously.

Particularly valuable when interfacing with third-party APIs or legacy systems where asynchronous context isn't available, but you need to integrate with your `async` implementations.

### `@Awaitless`

An attached macro that automatically generates synchronous counterparts for your `async` functions.

Ideal for API design patterns requiring both synchronous and asynchronous interfaces, eliminating the need to manually maintain duplicate implementations and providing simple deprecation for the future.

### `@IsolatedSafe`

An attached property macro that implements a serial dispatch queue to provide thread-safe access to `nonisolated(unsafe)` properties.

Offers runtime concurrency protection when compile-time isolation isn't feasible, effectively preventing data races through a property protected with `DispatchQueue`.

## Available functions

### `Noasync.run()`

Allows to run `async` code in `noasync` context.

Powers `@Awaitless()` and `#awaitless()` macros.

More details in [Calling Swift Concurrency async code synchronously in Swift](https://wadetregaskis.com/calling-swift-concurrency-async-code-synchronously-in-swift/)

## Usage

### Awaitless

```swift
import AwaitlessKit

final class AwaitlessExample: Sendable {
    public func runBasicExample() throws {
        // Call sync function generated from async
        let data = try fetchUserData()
        print("Fetched data: \(String(data: data, encoding: .utf8) ?? "")")
    }

    @Awaitless
    private func fetchUserData() async throws -> Data {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return "User data from API".data(using: .utf8)!
    }

    public func runDeprecatedExample() {
        // Call deprecated sync version - shows deprecation warning
        let items = try! processOrderItems()
        print("Processed items: \(items)")
    }

    @Awaitless(.deprecated("Synchronous API will be phased out, migrate to async version"))
    private func processOrderItems() async throws -> [String] {
        try await Task.sleep(nanoseconds: 750_000_000)
        return ["Order Item 1", "Order Item 2", "Order Item 3"]
    }

    public func runCustomPrefixExample() {
        // Call sync version with custom prefix
        let config = sync_loadAppConfig()
        print("Loaded config:", config)
    }

    // Custom prefix for generated function
    @Awaitless(prefix: "sync_")
    private func loadAppConfig() async -> [String: Sendable] {
        await Task.sleep(nanoseconds: 300_000_000)
        return ["apiUrl": "https://api.example.com", "timeout": 30]
    }

    public func runFreestandingMacroExample() throw {
        // Use the freestanding macro
        let result = try #awaitless(try downloadFileData())
        print("Downloaded: \(String(decoding: result, as: UTF8.self))")
    }

    private func downloadFileData() async throws -> Data? {
        try await Task.sleep(nanoseconds: 500_000_000)
        return "Downloaded file content".data(using: .utf8)
    }

    public func runUnavailableExample() throws {
        // Call sync version that is unavailable - this will cause a compile error
        // let resources = try loadDatabaseResources()
        // print("Loaded resources: \(resources)")
    }

    // Make sync version unavailable
    @Awaitless(.unavailable("Synchronous API has been removed, use async version"))
    private func loadDatabaseResources() async throws -> [String] {
        try await Task.sleep(nanoseconds: 2_000_000_000)
        return ["Record 1", "Record 2", "Record 3"]
    }
}
```

### IsolatedSafe

```swift
final class IsolatedSafeExample: Sendable {
    public func runStringExample() {
        // Safe access to "_unsafeStrings" through generated thread-safe "string" property
        strings.append("and")
        strings.append("universe")
    }

    @IsolatedSafe
    private nonisolated(unsafe) var _unsafeStrings: [String] = ["Hello", "World"]

    public func runProcessCountExample() {
        // Safe access to "_unsafeProcessCount" through generated thread-safe "processCount" property
        processCount += 1
    }

    @IsolatedSafe(writable: true)
    private nonisolated(unsafe) var _unsafeProcessCount: Int = 0
}
```

## Installation

Add `AwaitlessKit` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AwaitlessKit.git", from: "6.0.0")
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
- [Zed Editor](https://zed.dev) for its powerful GenAI support
- Anthropic for its 3.7 and 4.0 models
