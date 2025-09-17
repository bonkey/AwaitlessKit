//
// Copyright (c) 2025 Daniel Bauke
//

import Foundation
public import AwaitlessCore

/// Thread-safe storage for configuration
private final class ConfigStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: AwaitlessConfigData = .init()
    
    var value: AwaitlessConfigData {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}

/// Global configuration for AwaitlessKit macros, providing process-level defaults.
///
/// AwaitlessKit uses a four-level configuration hierarchy:
/// 1. Process-level defaults (this API)
/// 2. Type-scoped configuration via `@AwaitlessConfig`
/// 3. Method-level configuration via macro parameters
/// 4. Built-in defaults as fallback
///
/// ## Usage
///
/// Set process-wide defaults early in your application lifecycle:
///
/// ```swift
/// // Typically in main() or App delegate
/// AwaitlessConfig.setDefaults(
///     prefix: "sync_",
///     availability: .deprecated("Migrate to async APIs by 2025"),
///     delivery: .main,
///     strategy: .concurrent
/// )
/// ```
///
/// These defaults will be used by all AwaitlessKit macros unless overridden by more specific configuration.
public enum AwaitlessConfig {
    /// Access the current process-level defaults.
    ///
    /// This property is used internally by macros during compilation to access
    /// the current configuration state. You typically don't need to call this directly.
    ///
    /// - Returns: The current process-level configuration data
    public static var currentDefaults: AwaitlessConfigData {
        _storage.value
    }

    /// Sets process-level defaults for AwaitlessKit macros.
    ///
    /// These defaults provide fallback values when no more specific configuration
    /// is provided via `@AwaitlessConfig` member macro or macro parameters.
    ///
    /// - Parameters:
    ///   - prefix: Default prefix for generated synchronous function names.
    ///     Example: `"sync_"` generates `sync_originalName()` functions.
    ///   - availability: Default availability attribute for generated functions.
    ///     Controls deprecation warnings and availability constraints.
    ///   - delivery: Default delivery context for generated Combine publishers.
    ///     Determines which dispatch queue publisher events are delivered on.
    ///   - strategy: Default synchronization strategy for `@IsolatedSafe` properties.
    ///     Controls thread-safety implementation approach.
    ///
    /// ## Example
    ///
    /// ```swift
    /// AwaitlessConfig.setDefaults(
    ///     prefix: "blocking_",
    ///     availability: .deprecated("Migrate to async by Q4 2024"),
    ///     delivery: .main,
    ///     strategy: .concurrent
    /// )
    ///
    /// class NetworkService {
    ///     @Awaitless  // Uses process defaults
    ///     func fetchData() async throws -> Data {
    ///         // Implementation
    ///     }
    ///     // Generates: @available(*, deprecated: "Migrate to async by Q4 2024")
    ///     //            func blocking_fetchData() throws -> Data
    /// }
    /// ```
    public static func setDefaults(
        prefix: String? = nil,
        availability: AwaitlessAvailability? = nil,
        delivery: AwaitlessDelivery? = nil,
        strategy: AwaitlessSynchronizationStrategy? = nil)
    {
        _storage.value = AwaitlessConfigData(
            prefix: prefix,
            availability: availability,
            delivery: delivery,
            strategy: strategy)
    }

    /// Internal storage for the current defaults
    private static let _storage = ConfigStorage()
}
