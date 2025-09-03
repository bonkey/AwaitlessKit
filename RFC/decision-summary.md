# SR-05 Decision Summary: Configuration Defaults

**Date**: 2025-01-03  
**Status**: **APPROVED** - Type-Scoped Approach  
**Implementation**: Deferred to separate issue  

## Decision

**Adopt the type-scoped `@AwaitlessConfig` approach** for AwaitlessKit configuration defaults.

## Rationale

After evaluating both type-scoped and file-scoped approaches, the type-scoped design provides:

1. **Better Swift Idioms**: Aligns with Swift's type-based attribute system
2. **Granular Control**: Different types can have different defaults  
3. **Clear Ownership**: Configuration is visibly associated with types
4. **Incremental Adoption**: Can be migrated gradually per type

## Approved API Surface

```swift
// Configuration data storage
public struct AwaitlessConfigData {
    public let prefix: String?
    public let availability: AwaitlessAvailability?
    public let delivery: AwaitlessDelivery?
    public let strategy: AwaitlessSynchronizationStrategy?
}

// Configuration macro
@attached(member, names: named(__awaitlessConfig))
public macro AwaitlessConfig(
    prefix: String? = nil,
    availability: AwaitlessAvailability? = nil,
    delivery: AwaitlessDelivery? = nil,
    strategy: AwaitlessSynchronizationStrategy? = nil
) = #externalMacro(module: "AwaitlessKitMacros", type: "AwaitlessConfigMacro")
```

## Usage Examples

### Basic Configuration
```swift
@AwaitlessConfig(prefix: "sync", availability: .deprecated())
class UserService {
    @Awaitless  // Generates: syncFetchUser() with @available(*, deprecated)
    func fetchUser(id: String) async throws -> User { ... }
}
```

### Override Behavior
```swift
@AwaitlessConfig(prefix: "sync", delivery: .main)
class DataService {
    @Awaitless  // Uses prefix="sync"
    func normalMethod() async throws -> String { ... }
    
    @Awaitless(prefix: "legacy")  // Override: prefix="legacy", keeps delivery=.main
    func legacyMethod() async throws -> String { ... }
}
```

## Precedence Rules

1. **Method-level explicit parameters** override all defaults
2. **Type-level @AwaitlessConfig** provides defaults for the type  
3. **Built-in defaults** are used when neither method nor type specifies a value

## Implementation Strategy

**Generated Configuration Storage**:
1. `@AwaitlessConfig` generates a static property storing configuration
2. Other macros look for this property on the containing type
3. Fall back to built-in defaults if not found

## Migration Path

Teams can migrate gradually:

**Before (repetitive):**
```swift
class APIClient {
    @Awaitless(prefix: "sync", .deprecated("Use async"))
    func fetchUsers() async throws -> [User] { ... }
    
    @AwaitlessPublisher(prefix: "sync", deliverOn: .main, .deprecated("Use async"))
    func userStream() async -> AsyncStream<User> { ... }
}
```

**After (with configuration):**
```swift
@AwaitlessConfig(prefix: "sync", availability: .deprecated("Use async"), delivery: .main)
class APIClient {
    @Awaitless
    func fetchUsers() async throws -> [User] { ... }
    
    @AwaitlessPublisher
    func userStream() async -> AsyncStream<User> { ... }
}
```

## Implementation Notes

- Configuration discovery requires AST traversal or generated property lookup
- Macro implementation complexity is acceptable for the UX benefits
- Performance impact should be minimal with property-based storage

## Next Steps

1. Create implementation issue for `@AwaitlessConfig` macro
2. Update existing macros to support configuration discovery
3. Add comprehensive tests for configuration and override behavior
4. Update documentation with migration guide

## Deliverables Completed

- ✅ RFC document with approach comparison
- ✅ API surface design and examples  
- ✅ Migration guide with patterns
- ✅ Implementation prototype and feasibility analysis
- ✅ Decision documentation

This design provides a solid foundation for reducing repetition in AwaitlessKit while maintaining flexibility and Swift idioms.