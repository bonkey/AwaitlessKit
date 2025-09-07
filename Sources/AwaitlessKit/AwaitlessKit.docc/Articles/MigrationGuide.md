# Migration Guide

Complete guide for migrating from synchronous to asynchronous code using AwaitlessKit.

## Overview

AwaitlessKit is designed as a migration tool to help you gradually adopt Swift's async/await while maintaining backward compatibility. This guide provides strategies and best practices for successful migration.

## Migration Philosophy

### The AwaitlessKit Approach

AwaitlessKit follows a "dual-interface" migration strategy:

1. **Write async-first** - Implement new functionality using async/await
2. **Generate sync wrappers** - Use macros to automatically create legacy interfaces
3. **Migrate gradually** - Move calling code to async versions over time
4. **Remove wrappers** - Eventually remove sync interfaces for pure async implementation

### Why This Approach Works

- **Incremental Migration** - No big-bang rewrites required
- **Team Coordination** - Teams can migrate at different paces
- **Risk Mitigation** - Maintain working sync code during transition
- **Quality Assurance** - Test both interfaces during migration

## Migration Strategies

### Strategy 1: New Code First

Start by implementing all new features with async/await and macros:

```swift
// ✅ Start with async implementation
class NewFeatureService {
    @Awaitless
    func processNewData() async throws -> ProcessedData {
        // Modern async implementation
        let data = try await networkLayer.fetchData()
        let processed = try await processor.process(data)
        return processed
    }

    // Generated automatically:
    // func processNewData() throws -> ProcessedData
}

// Existing sync code can call either version
let service = NewFeatureService()
let result1 = try await service.processNewData()  // New async calling code
let result2 = try service.processNewData()        // Existing sync calling code
```

### Strategy 2: Brownfield Conversion

Convert existing sync APIs by adding async versions alongside:

```swift
class ExistingService {
    // ❌ Old sync implementation (to be deprecated)
    func fetchUserData() throws -> UserData {
        // Blocking network call
        return URLSession.shared.synchronousDataTask(with: url)
    }

    // ✅ New async implementation with sync wrapper
    @Awaitless(.deprecated("Use async version"))
    func fetchUserDataAsync() async throws -> UserData {
        let (data, _) = try await URLSession.shared.data(from: url)
        return UserData(from: data)
    }
}
```

### Strategy 3: Bottom-Up Migration

Start with low-level components and work upward:

```swift
// 1. Start with data layer
class DataRepository {
    @Awaitless
    func saveUser(_ user: User) async throws {
        try await database.save(user)
    }
}

// 2. Move to business logic layer
class UserService {
    @Awaitless
    func createUser(_ userData: UserData) async throws -> User {
        let user = User(from: userData)
        try await repository.saveUser(user)  // Can use async version
        return user
    }
}

// 3. Finally update presentation layer
class UserController {
    func handleCreateUser() {
        // Still works with sync wrapper during transition
        let user = try userService.createUser(userData)
        updateUI(with: user)
    }
}
```

## Configuration for Migration

### Process-Level Migration Settings

Set organization-wide migration policies:

```swift
// Set at application startup
AwaitlessConfig.setDefaults(
    prefix: "legacy_",
    availability: .deprecated("Migrate to async by Q4 2024")
)

// All @Awaitless macros now generate deprecated sync wrappers
class APIService {
    @Awaitless  // Generates: @available(*, deprecated: "Migrate to async by Q4 2024")
                // func legacy_fetchData() throws -> Data
    func fetchData() async throws -> Data {
        // Implementation
    }
}
```

### Team-Specific Configuration

Different teams can have different migration timelines:

```swift
// Team A: Aggressive migration schedule
@AwaitlessConfig(availability: .deprecated("Migrate by March 2024"))
class CoreNetworkingModule {
    @Awaitless
    func performCriticalOperation() async throws -> Result {
        // Implementation
    }
}

// Team B: Slower migration schedule
@AwaitlessConfig(availability: .deprecated("Migrate by December 2024"))
class LegacyIntegrationModule {
    @Awaitless
    func integrateWithLegacySystem() async throws -> Response {
        // Implementation
    }
}
```

### Progressive Deprecation

Use increasingly strict availability attributes:

```swift
// Phase 1: Soft deprecation
@Awaitless(.deprecated("Consider migrating to async version"))
func phase1Function() async throws -> Data { /* ... */ }

// Phase 2: Strong deprecation
@Awaitless(.deprecated("Sync version will be removed in v2.0"))
func phase2Function() async throws -> Data { /* ... */ }

// Phase 3: Mark unavailable
@Awaitless(.unavailable("Use async version only"))
func phase3Function() async throws -> Data { /* ... */ }

// Phase 4: Remove macro entirely (async-only)
func phase4Function() async throws -> Data { /* ... */ }
```

## Migration Patterns

### Pattern 1: Wrapper Delegation

Legacy sync methods delegate to new async implementations:

```swift
class UserRepository {
    // New async implementation
    @Awaitless
    func saveUser(_ user: User) async throws {
        try await database.insert(user)
        try await cache.update(user)
        await notificationCenter.post(.userSaved(user))
    }

    // Legacy sync method delegates to async
    func saveUserLegacy(_ user: User) throws {
        // Uses generated sync wrapper internally
        try saveUser(user)
    }
}
```

### Pattern 2: Gradual Interface Evolution

Evolve interfaces gradually while maintaining compatibility:

```swift
class APIClient {
    // Old: Completion handler style
    func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void) {
        // Legacy implementation
    }

    // New: Async/await with completion wrapper
    @AwaitlessCompletion
    func fetchUser(id: String) async throws -> User {
        // Modern implementation
    }

    // Generated automatically:
    // func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void)
}
```

### Pattern 3: Type-Level Migration

Migrate entire types systematically:

```swift
// Before: All sync
class LegacyNetworkManager {
    func request<T>(_ endpoint: Endpoint) throws -> T { /* ... */ }
    func upload(_ data: Data) throws -> Response { /* ... */ }
    func download(_ url: URL) throws -> Data { /* ... */ }
}

// During: Mixed with deprecation
@AwaitlessConfig(availability: .deprecated("Use AsyncNetworkManager"))
class NetworkManager {
    @Awaitless
    func request<T>(_ endpoint: Endpoint) async throws -> T { /* ... */ }

    @Awaitless
    func upload(_ data: Data) async throws -> Response { /* ... */ }

    @Awaitless
    func download(_ url: URL) async throws -> Data { /* ... */ }
}

// After: Pure async
class AsyncNetworkManager {
    func request<T>(_ endpoint: Endpoint) async throws -> T { /* ... */ }
    func upload(_ data: Data) async throws -> Response { /* ... */ }
    func download(_ url: URL) async throws -> Data { /* ... */ }
}
```

## Testing During Migration

### Dual Testing Strategy

Test both sync and async interfaces:

```swift
class UserServiceTests: XCTestCase {
    let service = UserService()

    // Test async interface
    func testCreateUserAsync() async throws {
        let user = try await service.createUser(userData)
        XCTAssertEqual(user.name, "Test User")
    }

    // Test generated sync interface
    func testCreateUserSync() throws {
        let user = try service.createUser(userData)  // Uses generated wrapper
        XCTAssertEqual(user.name, "Test User")
    }

    // Test behavioral equivalence
    func testInterfaceEquivalence() async throws {
        let asyncResult = try await service.createUser(userData)
        let syncResult = try service.createUser(userData)

        XCTAssertEqual(asyncResult, syncResult)
    }
}
```

## Common Migration Challenges

### Challenge 1: Nested Async Calls

**Problem**: Deep call stacks with mixed sync/async code

```swift
// ❌ Problematic nesting
func syncMethod() -> Result {
    let data = try asyncMethod()  // Sync wrapper call
    return processSync(data)
}

func asyncMethod() async throws -> Data {
    // Multiple nested async calls
    let a = try await serviceA.fetch()
    let b = try await serviceB.fetch()
    return combine(a, b)
}
```

**Solution**: Minimize wrapper usage depth

```swift
// ✅ Better approach
func syncMethod() -> Result {
    // Use wrapper only at the boundary
    let data = try fetchAllDataSync()
    return processSync(data)
}

@Awaitless
func fetchAllData() async throws -> Data {
    // Keep async context for multiple operations
    async let a = serviceA.fetch()
    async let b = serviceB.fetch()
    return try await combine(a, b)
}
```

### Challenge 2: Error Propagation

**Problem**: Different error handling patterns

```swift
// ❌ Mixed error handling
func legacyMethod() -> Result<Data, CustomError> {
    do {
        return .success(try modernAsyncMethod())  // Throws generic Error
    } catch {
        return .failure(.unknown(error))  // Loss of error context
    }
}
```

**Solution**: Consistent error types

```swift
// ✅ Consistent error handling
@Awaitless
func modernAsyncMethod() async throws -> Data {
    // Throw domain-specific errors
    throw CustomError.networkFailure
}

// Generated wrapper preserves error types
// func modernAsyncMethod() throws -> Data
```

### Challenge 3: Cancellation Support

**Problem**: Sync wrappers can't be cancelled

```swift
// ❌ Limited cancellation
func longRunningSync() -> Data {
    // Generated wrapper blocks until completion
    return try longRunningAsync()
}
```

**Solution**: Design for cancellation where needed

```swift
// ✅ Cancellation-aware design
@AwaitlessPublisher
func longRunningOperation() async throws -> Data {
    // Publisher can be cancelled
    try await Task.sleep(nanoseconds: 1_000_000_000)
    return data
}

// Generated: func longRunningOperation() -> AnyPublisher<Data, Error>
// Can be cancelled via publisher subscription
```

## Migration Timeline

### Phase 1: Foundation (Weeks 1-4)

- Set up AwaitlessKit in project
- Configure process-level defaults
- Start with new feature development using @Awaitless

### Phase 2: Brownfield (Weeks 5-12)

- Identify high-impact sync APIs for conversion
- Add async implementations with @Awaitless wrappers
- Begin migrating calling code to async versions

### Phase 3: Aggressive Migration (Weeks 13-24)

- Convert remaining sync APIs
- Use stronger deprecation warnings
- Migrate majority of calling code

### Phase 4: Cleanup (Weeks 25-28)

- Remove @Awaitless macros from converted APIs
- Remove legacy sync implementations
- Achieve pure async codebase

## Success Metrics

Track migration progress with these metrics:

1. **API Coverage** - Percentage of APIs with async versions
2. **Usage Migration** - Percentage of calls using async APIs
3. **Deprecation Compliance** - Time to address deprecation warnings

4. **Bug Reports** - Issues related to sync/async interface mismatches
