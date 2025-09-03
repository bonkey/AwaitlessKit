# Migration Guide: AwaitlessKit Configuration Defaults

This guide explains how to migrate from explicit parameter repetition to using `@AwaitlessConfig` for default configuration.

## Overview

The `@AwaitlessConfig` macro allows you to set default parameters for all AwaitlessKit macros within a type, reducing repetition and ensuring consistency.

## Migration Steps

### Step 1: Identify Repetitive Patterns

Look for types where multiple methods use the same parameters:

**Before:**
```swift
class APIClient {
    @Awaitless(prefix: "sync", .deprecated("Use async version"))
    func fetchUsers() async throws -> [User] { ... }
    
    @Awaitless(prefix: "sync", .deprecated("Use async version"))
    func fetchPosts() async throws -> [Post] { ... }
    
    @AwaitlessPublisher(prefix: "sync", deliverOn: .main, .deprecated("Use async version"))
    func userUpdates() async -> AsyncStream<User> { ... }
}
```

### Step 2: Add @AwaitlessConfig

Add the configuration macro to the type with common parameters:

**After:**
```swift
@AwaitlessConfig(prefix: "sync", availability: .deprecated("Use async version"), delivery: .main)
class APIClient {
    @Awaitless
    func fetchUsers() async throws -> [User] { ... }
    
    @Awaitless
    func fetchPosts() async throws -> [Post] { ... }
    
    @AwaitlessPublisher
    func userUpdates() async -> AsyncStream<User> { ... }
}
```

### Step 3: Override When Needed

Keep explicit parameters for methods that need different behavior:

```swift
@AwaitlessConfig(prefix: "sync", availability: .deprecated("Use async version"))
class DataService {
    @Awaitless  // Uses defaults
    func fetchData() async throws -> Data { ... }
    
    @Awaitless(prefix: "legacy")  // Override prefix only
    func legacyFetch() async throws -> Data { ... }
    
    @Awaitless(.unavailable("Removed in v2.0"))  // Override availability only
    func oldMethod() async throws -> String { ... }
}
```

## Migration Patterns

### Pattern 1: Common Prefix

**Before:**
```swift
class UserService {
    @Awaitless(prefix: "blocking")
    func createUser() async throws -> User { ... }
    
    @Awaitless(prefix: "blocking")
    func updateUser() async throws -> User { ... }
    
    @AwaitlessCompletion(prefix: "blocking")
    func deleteUser() async throws { ... }
}
```

**After:**
```swift
@AwaitlessConfig(prefix: "blocking")
class UserService {
    @Awaitless
    func createUser() async throws -> User { ... }
    
    @Awaitless
    func updateUser() async throws -> User { ... }
    
    @AwaitlessCompletion
    func deleteUser() async throws { ... }
}
```

### Pattern 2: Deprecation Strategy

**Before:**
```swift
class LegacyAPI {
    @Awaitless(.deprecated("Migrate to v2 API"))
    func method1() async throws -> String { ... }
    
    @Awaitless(.deprecated("Migrate to v2 API"))
    func method2() async throws -> Int { ... }
    
    @AwaitlessPublisher(.deprecated("Migrate to v2 API"))
    func stream1() async -> AsyncStream<String> { ... }
}
```

**After:**
```swift
@AwaitlessConfig(availability: .deprecated("Migrate to v2 API"))
class LegacyAPI {
    @Awaitless
    func method1() async throws -> String { ... }
    
    @Awaitless
    func method2() async throws -> Int { ... }
    
    @AwaitlessPublisher
    func stream1() async -> AsyncStream<String> { ... }
}
```

### Pattern 3: Publisher Configuration

**Before:**
```swift
class UIDataProvider {
    @AwaitlessPublisher(prefix: "rx", deliverOn: .main)
    func userStream() async -> AsyncStream<User> { ... }
    
    @AwaitlessPublisher(prefix: "rx", deliverOn: .main)
    func postStream() async -> AsyncStream<Post> { ... }
    
    @AwaitlessPublisher(prefix: "rx", deliverOn: .main)
    func notificationStream() async -> AsyncStream<Notification> { ... }
}
```

**After:**
```swift
@AwaitlessConfig(prefix: "rx", delivery: .main)
class UIDataProvider {
    @AwaitlessPublisher
    func userStream() async -> AsyncStream<User> { ... }
    
    @AwaitlessPublisher
    func postStream() async -> AsyncStream<Post> { ... }
    
    @AwaitlessPublisher
    func notificationStream() async -> AsyncStream<Notification> { ... }
}
```

## Gradual Migration

You can migrate gradually by applying `@AwaitlessConfig` to one type at a time:

### Phase 1: Add Configuration
```swift
@AwaitlessConfig(prefix: "sync")  // Add configuration
class DataService {
    @Awaitless(prefix: "sync")  // Keep explicit for now
    func fetchData() async throws -> Data { ... }
}
```

### Phase 2: Remove Redundant Parameters
```swift
@AwaitlessConfig(prefix: "sync")
class DataService {
    @Awaitless  // Remove redundant prefix
    func fetchData() async throws -> Data { ... }
}
```

## Best Practices

### 1. Use Consistent Naming
Choose consistent prefixes and availability messages across your codebase:

```swift
@AwaitlessConfig(
    prefix: "sync",
    availability: .deprecated("Use async/await instead")
)
```

### 2. Document Configuration
Add comments explaining the configuration choices:

```swift
/// Legacy sync APIs - deprecated in favor of async/await
@AwaitlessConfig(
    prefix: "legacy",
    availability: .deprecated("Migrate to async/await APIs")
)
class LegacyService {
    // ...
}
```

### 3. Group Related Methods
Apply configuration to types that logically group related async methods:

```swift
@AwaitlessConfig(prefix: "blocking", delivery: .main)
class NetworkManager {
    // All network methods use consistent configuration
}
```

### 4. Override Sparingly
Only override configuration when truly necessary:

```swift
@AwaitlessConfig(prefix: "sync")
class Service {
    @Awaitless  // Uses default prefix
    func normalMethod() async throws -> String { ... }
    
    @Awaitless(prefix: "special")  // Override only when needed
    func specialMethod() async throws -> String { ... }
}
```

## Common Gotchas

### 1. Partial Overrides
Remember that explicit parameters only override that specific setting:

```swift
@AwaitlessConfig(prefix: "sync", availability: .deprecated())
class Service {
    @Awaitless(prefix: "custom")  // prefix="custom", availability=.deprecated (from config)
    func method() async throws -> String { ... }
}
```

### 2. Empty Configuration
An empty `@AwaitlessConfig()` is valid but has no effect:

```swift
@AwaitlessConfig()  // Same as no configuration
class Service {
    @Awaitless  // Uses built-in defaults
    func method() async throws -> String { ... }
}
```

### 3. Multiple Configurations
Don't apply multiple `@AwaitlessConfig` to the same type - the last one wins:

```swift
@AwaitlessConfig(prefix: "sync")
@AwaitlessConfig(prefix: "legacy")  // This overrides the first one
class Service { ... }
```

## Verification

After migration, verify the generated code maintains the same behavior:

1. Check that generated method names match expectations
2. Verify availability attributes are correctly applied
3. Test that publisher delivery behavior is unchanged
4. Ensure override behavior works as expected

The migration preserves all existing functionality while reducing code duplication and improving maintainability.