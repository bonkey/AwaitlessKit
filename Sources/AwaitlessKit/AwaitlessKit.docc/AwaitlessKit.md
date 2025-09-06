# ``AwaitlessKit``

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

1. **Process-Level Defaults** via ``AwaitlessConfig/setDefaults(prefix:availability:delivery:strategy:)``
2. **Type-Scoped Configuration** via ``AwaitlessConfig`` member macro
3. **Method-Level Configuration** via ``Awaitless`` parameters
4. **Built-in Defaults** as fallback

## Topics

### Primary Macros

- ``Awaitless``
- ``AwaitlessPublisher`` 
- ``AwaitlessCompletion``
- ``Awaitlessable``

### Configuration System

- ``AwaitlessConfig``
- ``AwaitlessAvailability``
- ``AwaitlessDelivery``
- ``AwaitlessSynchronizationStrategy``

### Utility Macros

- ``awaitless(_:)``
- ``IsolatedSafe``

### Low-Level API

- ``Noasync``

## Migration Strategy

> Important: AwaitlessKit is a migration tool, not a permanent solution. Use during transition periods to gradually adopt async/await while maintaining backward compatibility.

### Recommended Migration Path

1. **Add async implementations** with `@Awaitless` to generate sync counterparts
2. **Deprecate sync versions** using availability attributes  
3. **Migrate calling code** to async versions over time
4. **Remove sync support** when migration is complete
5. **Remove macros** for pure async implementation

## Example Usage

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