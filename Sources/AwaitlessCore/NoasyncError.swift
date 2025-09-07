//
// Copyright (c) 2025 Daniel Bauke
//

public import Foundation

/// Errors that can occur during `Noasync.run` execution.
public enum NoasyncError: Error, Sendable, Equatable {
    /// The operation timed out before completing.
    /// - Parameter duration: The timeout duration that was exceeded.
    case timeout(TimeInterval)
}
