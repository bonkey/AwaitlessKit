//
// Copyright (c) 2025 Daniel Bauke
//

public import AwaitlessCore
import PromiseKit

/// Generates a PromiseKit Promise wrapper for an async function.
///
/// The `@AwaitlessPromise` macro creates a Promise-based counterpart to your async function,
/// allowing integration with existing PromiseKit-based architectures.
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
///   - prefix: Prefix for the generated promise function name.
///     Example: `"promise_"` generates `promise_originalName()`.
///   - availability: Availability attribute for the generated function.
///     Controls deprecation warnings and availability constraints.
///
/// ## Example
///
/// ```swift
/// import PromiseKit
///
/// class NetworkService {
///     @AwaitlessPromise(prefix: "promise_", .deprecated("Use async version"))
///     func fetchData() async throws -> Data {
///         let (data, _) = try await URLSession.shared.data(from: url)
///         return data
///     }
///
///     // Automatically generates:
///     // @available(*, deprecated: "Use async version")
///     // func promise_fetchData() -> Promise<Data> {
///     //     return Promise { seal in
///     //         Task {
///     //             do {
///     //                 let result = try await self.fetchData()
///     //                 seal.fulfill(result)
///     //             } catch {
///     //                 seal.reject(error)
///     //             }
///     //         }
///     //     }
///     // }
/// }
///
/// // Usage with PromiseKit
/// let service = NetworkService()
/// service.promise_fetchData()
///     .done { data in
///         // Handle successful result
///     }
///     .catch { error in
///         // Handle error
///     }
/// ```
@attached(peer, names: arbitrary)
public macro AwaitlessPromise(
    prefix: String = "",
    _ availability: AwaitlessAvailability? = nil) = #externalMacro(
    module: "AwaitlessKitPromiseMacros",
    type: "AwaitlessPromiseMacro")

/// Generates an async/await wrapper for a PromiseKit Promise function.
///
/// The `@Awaitful` macro creates an async counterpart to your Promise-based function,
/// enabling migration from PromiseKit to async/await by providing both APIs during transition.
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
///   - prefix: Prefix for the generated async function name.
///     Example: `"async_"` generates `async_originalName()`.
///   - availability: Availability attribute for the generated function.
///     Defaults to `.deprecated()` with a configurable message.
///
/// ## Example
///
/// ```swift
/// import PromiseKit
///
/// class LegacyService {
///     @Awaitable(prefix: "async_")
///     func fetchData() -> Promise<Data> {
///         return URLSession.shared.dataTask(.promise, with: url)
///             .map(\.data)
///     }
///
///     // Automatically generates:
///     // @available(*, deprecated: "PromiseKit support is deprecated; use async function instead")
///     // func async_fetchData() async throws -> Data {
///     //     return try await self.fetchData().async()
///     // }
/// }
///
/// // Usage during migration
/// let service = LegacyService()
/// let promise = service.fetchData()           // Original Promise version
/// let data = try await service.async_fetchData()  // Generated async version
/// ```
@attached(peer, names: arbitrary)
public macro Awaitful(
    prefix: String = "",
    _ availability: AwaitlessAvailability? = .deprecated()) = #externalMacro(
    module: "AwaitlessKitPromiseMacros",
    type: "AwaitfulMacro")

/// Generates async method signatures and optional default implementations for Promise-returning protocols and classes.
///
/// Applied to protocols or classes containing Promise-returning methods, this macro generates corresponding
/// async method signatures and optionally provides default implementations.
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
///   - prefix: Prefix for the generated async function names.
///     Example: `"async_"` generates `async_originalName()`.
///   - availability: Availability attribute for the generated functions.
///     Defaults to `.deprecated()` with a configurable message.
///   - extensionGeneration: Whether to generate default async implementations
///
/// ## Example
///
/// ```swift
/// import PromiseKit
///
/// @Awaitfulable
/// protocol DataService {
///     func fetchUser(id: String) -> Promise<User>
///     func fetchData() -> Promise<Data>
/// }
///
/// // Automatically generates:
/// // protocol DataService {
/// //     func fetchUser(id: String) -> Promise<User>
/// //     func fetchData() -> Promise<Data>
/// //
/// //     // Async method signatures
/// //     func fetchUser(id: String) async throws -> User
/// //     func fetchData() async throws -> Data
/// // }
/// //
/// // extension DataService {
/// //     // Default implementations using Promise.async()
/// //     public func fetchUser(id: String) async throws -> User {
/// //         return try await self.fetchUser(id: id).async()
/// //     }
/// //
/// //     public func fetchData() async throws -> Data {
/// //         return try await self.fetchData().async()
/// //     }
/// // }
///
/// // Implementation - just implement Promise methods
/// struct APIService: DataService {
///     func fetchUser(id: String) -> Promise<User> {
///         // Your Promise implementation
///     }
///
///     func fetchData() -> Promise<Data> {
///         // Your Promise implementation
///     }
///
///     // Async versions are automatically available!
/// }
///
/// let service = APIService()
/// let user = try await service.fetchUser(id: "123")  // Uses generated async version
/// ```
@attached(member, names: arbitrary)
@attached(extension, names: arbitrary)
public macro Awaitfulable(
    prefix: String = "",
    _ availability: AwaitlessAvailability? = .deprecated(),
    extensionGeneration: AwaitlessableExtensionGeneration = .enabled) = #externalMacro(
    module: "AwaitlessKitPromiseMacros",
    type: "AwaitfulableMacro")