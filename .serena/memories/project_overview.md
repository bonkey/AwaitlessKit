# AwaitlessKit Project Overview

## Purpose

AwaitlessKit is a Swift package that provides macros to automatically generate synchronous wrappers for async/await functions. This enables easy migration from Swift 5 to Swift 6 by allowing both sync and async APIs to coexist during the transition period.

The primary goal is to solve the "all-or-nothing" problem of Swift's async/await adoption by allowing incremental migration without breaking existing APIs.

## Key Features

- `@Awaitless` macro - automatically generates sync wrappers for async functions
- `#awaitless()` macro - inline async code execution (Swift 6.0+ only)
- `@IsolatedSafe` macro - generates thread-safe properties for nonisolated(unsafe) properties
- `Awaitless.run()` - low-level bridge for running async code in sync contexts
- Built-in deprecation controls to manage migration timeline

## Requirements

- Swift 6.0+ compiler (Xcode 16+)
- Swift 5.x language mode compatibility maintained
- swift-syntax 601.0.1+

## Target Platforms

- macOS 14+
- iOS 15+
- tvOS 13+
- watchOS 10+
- macCatalyst 14+

## Migration Tool Warning

This is intentionally a migration tool, not a permanent solution. It bypasses Swift's concurrency safety mechanisms and should only be used during transition periods.
