# Configuration System

Learn how to configure AwaitlessKit macros using the four-level configuration hierarchy.

## Overview

AwaitlessKit provides a flexible configuration system that allows you to set defaults at multiple levels, creating a hierarchy of precedence for macro behavior.

## Configuration Hierarchy

The configuration system follows a clear precedence order:

1. **Process-Level Defaults** - Application-wide defaults via ``AwaitlessConfig/setDefaults(prefix:availability:delivery:strategy:)``
2. **Type-Scoped Configuration** - Per-type defaults via ``AwaitlessConfig`` member macro
3. **Method-Level Configuration** - Per-method settings via macro parameters
4. **Built-in Defaults** - Fallback default values

Higher-numbered levels override lower-numbered ones when both are specified.

## Process-Level Configuration

Set application-wide defaults that apply to all AwaitlessKit macros:

```swift
// Set at application startup, typically in main() or App delegate
AwaitlessConfig.setDefaults(
    prefix: "sync_",
    availability: .deprecated("Migrate to async APIs by 2025"), 
    delivery: .main,
    strategy: .concurrent
)

class NetworkService {
    @Awaitless  // Uses process defaults
    func fetchData() async throws -> Data {
        // Implementation
    }
    // Generates: @available(*, deprecated: "Migrate to async APIs by 2025")
    //            func sync_fetchData() throws -> Data
}
```

## Type-Scoped Configuration  

Configure defaults for all methods within a specific type:

```swift
@AwaitlessConfig(prefix: "blocking_", availability: .deprecated("Use async version"))
class APIClient {
    @Awaitless  // Inherits type configuration
    func authenticate() async throws -> Token {
        // Implementation  
    }
    // Generates: @available(*, deprecated: "Use async version")
    //            func blocking_authenticate() throws -> Token
    
    @AwaitlessPublisher  // Type config applies to all macro types
    func streamUpdates() async throws -> [Update] {
        // Implementation
    }
    // Generates: @available(*, deprecated: "Use async version") 
    //            func blocking_streamUpdates() -> AnyPublisher<[Update], Error>
}
```

## Method-Level Configuration

Override higher-level configurations for specific methods:

```swift
@AwaitlessConfig(prefix: "api_")  // Type-level default
class ServiceManager {
    @Awaitless(prefix: "immediate_")  // Method-level override
    func urgentCheck() async -> Bool {
        // Implementation
    }
    // Generates: func immediate_urgentCheck() -> Bool
    // (Method prefix overrides type prefix)
    
    @Awaitless(.noasync)  // Method-level availability override
    func internalOperation() async throws -> String {
        // Implementation
    }
    // Generates: @available(*, noasync)
    //            func api_internalOperation() throws -> String
    // (Method availability overrides, but type prefix is used)
}
```

## Configuration Properties

### Prefix

Controls the naming of generated synchronous functions:

- **Default**: `""` (empty string)
- **Example**: `prefix: "sync_"` generates `sync_originalName()`

### Availability

Controls the availability attributes of generated functions:

- ``AwaitlessAvailability/noasync`` - Marks as `@available(*, noasync)`
- ``AwaitlessAvailability/deprecated(_:)`` - Marks as deprecated with custom message
- ``AwaitlessAvailability/unavailable(_:)`` - Marks as unavailable with custom message

### Delivery (Publishers only)

Controls where Combine publisher events are delivered:

- ``AwaitlessDelivery/current`` - Current execution context
- ``AwaitlessDelivery/main`` - Main dispatch queue
- ``AwaitlessDelivery/global(qos:)`` - Global queue with specified QoS

### Strategy (IsolatedSafe only)

Controls synchronization strategy for thread-safe properties:

- ``AwaitlessSynchronizationStrategy/concurrent`` - Concurrent queue with barriers
- ``AwaitlessSynchronizationStrategy/serial`` - Serial queue

## Complete Example

```swift
// 1. Set process-wide defaults
AwaitlessConfig.setDefaults(
    prefix: "app_",
    availability: .deprecated("Migrate by Q3 2025")
)

// 2. Type-scoped overrides
@AwaitlessConfig(prefix: "api_", delivery: .main)
class NetworkManager {
    // 3. Method inherits: api_ prefix, deprecated availability, main delivery
    @AwaitlessPublisher
    func fetchUpdates() async throws -> [Update] {
        // Generates: @available(*, deprecated: "Migrate by Q3 2025")
        //            func api_fetchUpdates() -> AnyPublisher<[Update], Error>
        //            (delivered on main queue)
    }
    
    // 4. Method-level overrides prefix and availability
    @Awaitless(prefix: "urgent_", .noasync)
    func criticalOperation() async throws -> Result {
        // Generates: @available(*, noasync)
        //            func urgent_criticalOperation() throws -> Result
    }
}
```

## Best Practices

1. **Set process defaults early** in application lifecycle
2. **Use type-scoped configuration** for consistent behavior within classes/structs
3. **Override at method level** only when specific behavior is needed
4. **Document your configuration strategy** for team consistency
5. **Use deprecation messages** to guide migration efforts

## Topics

### Configuration APIs

- ``AwaitlessConfig``
- ``AwaitlessConfig/setDefaults(prefix:availability:delivery:strategy:)``

### Configuration Types

- ``AwaitlessAvailability``
- ``AwaitlessDelivery`` 
- ``AwaitlessSynchronizationStrategy``