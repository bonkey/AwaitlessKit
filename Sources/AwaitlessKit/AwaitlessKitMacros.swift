//
// Copyright (c) 2025 Daniel Bauke
//

public import AwaitlessCore

/// Generates a synchronous wrapper for an async function.
///
/// The `@Awaitless` macro creates a synchronous counterpart to your async function,
/// allowing existing synchronous code to call the new async implementation during
/// migration periods.
///
/// ## Configuration Hierarchy
///
/// Parameters can be inherited from higher-level configurations:
/// 1. Process-level defaults via `AwaitlessConfig.setDefaults()`
/// 2. Type-scoped configuration via `@AwaitlessConfig`
/// 3. Method-level parameters (these parameters)
/// 4. Built-in defaults
///
/// - Parameters:
///   - prefix: Prefix for the generated synchronous function name.
///     Example: `"sync_"` generates `sync_originalName()`.
///   - availability: Availability attribute for the generated function.
///     Controls deprecation warnings and availability constraints.
///
/// ## Example
///
/// ```swift
/// class NetworkService {
///     @Awaitless(prefix: "blocking_", .deprecated("Use async version"))
///     func fetchData() async throws -> Data {
///         // Async implementation
///     }
///     // Generates: @available(*, deprecated: "Use async version")
///     //            func blocking_fetchData() throws -> Data
/// }
/// ```
@attached(peer, names: arbitrary)
public macro Awaitless(
    prefix: String = "",
    _ availability: AwaitlessAvailability? = nil) = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "AwaitlessSyncMacro")

/// Generates a Combine publisher wrapper for an async function.
///
/// Creates an `AnyPublisher` that wraps the async function execution,
/// useful for integrating async/await code with existing Combine-based architectures.
///
/// - Parameters:
///   - prefix: Prefix for the generated publisher function name
///   - deliverOn: Dispatch queue where publisher events are delivered
///   - availability: Availability attribute for the generated function
@attached(peer, names: arbitrary)
public macro AwaitlessPublisher(
    prefix: String = "",
    deliverOn: AwaitlessDelivery = .current,
    _ availability: AwaitlessAvailability? = nil) = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "AwaitlessPublisherMacro")

/// Generates a completion handler wrapper for an async function.
///
/// Creates a completion-handler version of the async function using `Result<T, Error>`,
/// useful for integrating with legacy callback-based APIs.
///
/// - Parameters:
///   - prefix: Prefix for the generated completion handler function name
///   - availability: Availability attribute for the generated function
@attached(peer, names: arbitrary)
public macro AwaitlessCompletion(
    prefix: String = "",
    _ availability: AwaitlessAvailability? = nil) = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "AwaitlessCompletionMacro")

/// Executes async code synchronously in a sync context.
///
/// This freestanding macro allows you to run async expressions within synchronous functions.
/// Use sparingly and only during migration periods.
///
/// ## Example
///
/// ```swift
/// func syncFunction() -> String {
///     let result = #awaitless(await asyncFunction())
///     return result
/// }
/// ```
@freestanding(expression)
public macro awaitless<T>(_ expression: T) -> T = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "AwaitlessFreestandingMacro")

/// Generates synchronous method signatures and optional default implementations for async protocols.
///
/// Applied to protocols containing async methods, this macro generates corresponding
/// synchronous method signatures and optionally provides default implementations.
///
/// - Parameter extensionGeneration: Whether to generate default sync implementations
///
/// ## Example
///
/// ```swift
/// @Awaitlessable
/// protocol DataService {
///     func fetchUser(id: String) async throws -> User
/// }
/// // Generates sync method signature and default implementation
/// ```
@attached(member, names: arbitrary)
@attached(extension, names: arbitrary)
public macro Awaitlessable(
    extensionGeneration: AwaitlessableExtensionGeneration = .enabled) = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "AwaitlessableMacro")

/// Generates thread-safe accessors for `nonisolated(unsafe)` properties.
///
/// Creates synchronized getter and setter methods for properties that need thread safety
/// but can't use actor isolation.
///
/// - Parameters:
///   - writable: Whether to generate setter methods
///   - queueName: Custom dispatch queue name for synchronization
///   - strategy: Synchronization strategy (concurrent vs serial)
@attached(peer, names: arbitrary)
public macro IsolatedSafe(
    writable: Bool = false,
    queueName: String? = nil,
    strategy: AwaitlessSynchronizationStrategy = .concurrent) = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "IsolatedSafeMacro")

/// Provides type-scoped configuration defaults for AwaitlessKit macros.
///
/// Applied to types (classes, structs, enums), this macro sets default configuration
/// values that will be inherited by all AwaitlessKit macros used within that type.
///
/// ## Configuration Hierarchy
///
/// Type-scoped configuration has precedence over process-level defaults but can be
/// overridden by method-level parameters:
/// 1. Process-level defaults via `AwaitlessConfig.setDefaults()`
/// 2. **Type-scoped configuration** (this macro)
/// 3. Method-level parameters
/// 4. Built-in defaults
///
/// - Parameters:
///   - prefix: Default prefix for generated function names within this type
///   - availability: Default availability attribute for generated functions
///   - delivery: Default delivery context for generated publishers
///   - strategy: Default synchronization strategy for isolated operations
///
/// ## Example
///
/// ```swift
/// @AwaitlessConfig(prefix: "api_", availability: .deprecated("Migrate to async"))
/// class NetworkManager {
///     @Awaitless  // Inherits: api_ prefix and deprecated availability
///     func fetchData() async throws -> Data {
///         // Implementation
///     }
///     // Generates: @available(*, deprecated: "Migrate to async")
///     //            func api_fetchData() throws -> Data
/// }
/// ```
@attached(member, names: named(__awaitlessConfig))
public macro AwaitlessConfig(
    prefix: String? = nil,
    availability: AwaitlessAvailability? = nil,
    delivery: AwaitlessDelivery? = nil,
    strategy: AwaitlessSynchronizationStrategy? = nil) = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "AwaitlessConfigMacro")
