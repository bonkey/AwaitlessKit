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