//
// Copyright (c) 2025 Daniel Bauke
//

import Foundation
public import AwaitlessCore

/// Global configuration for AwaitlessKit macros, providing process-level defaults.
@MainActor
public enum AwaitlessConfig {
    /// Internal storage for the current defaults
    private static var _currentDefaults: AwaitlessConfigData = AwaitlessConfigData()
    
    /// Sets process-level defaults for AwaitlessKit macros.
    /// These defaults are used when no more specific configuration is provided.
    /// 
    /// - Parameters:
    ///   - prefix: Default prefix for generated synchronous function names
    ///   - availability: Default availability attribute for generated functions
    ///   - delivery: Default delivery context for generated publishers
    ///   - strategy: Default synchronization strategy for isolated operations
    public static func setDefaults(
        prefix: String? = nil,
        availability: AwaitlessAvailability? = nil,
        delivery: AwaitlessDelivery? = nil,
        strategy: AwaitlessSynchronizationStrategy? = nil
    ) {
        _currentDefaults = AwaitlessConfigData(
            prefix: prefix,
            availability: availability,
            delivery: delivery,
            strategy: strategy
        )
    }
    
    /// Access the current process-level defaults.
    /// This property is used by macros during compilation to access configuration.
    public static var currentDefaults: AwaitlessConfigData {
        return _currentDefaults
    }
}