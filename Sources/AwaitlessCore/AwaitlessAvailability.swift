//
// Copyright (c) 2025 Daniel Bauke
//

import Foundation

/// Defines the availability of the generated synchronous function.
public enum AwaitlessAvailability {
    /// Marks the synchronous function as deprecated.
    /// - Parameter message: An optional custom deprecation message.
    case deprecated(_ message: String? = nil)
    /// Marks the synchronous function as unavailable.
    /// - Parameter message: An optional custom unavailability message.
    case unavailable(_ message: String? = nil)
}

