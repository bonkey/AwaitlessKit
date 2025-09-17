//
// Copyright (c) 2025 Daniel Bauke
//

public import Foundation

/// Errors that can occur during `Awaitless.run` execution.
public enum AwaitlessError: Error, Sendable, Equatable {
    /// The operation timed out before completing.
    /// - Parameter duration: The timeout duration that was exceeded.
    case timeout(TimeInterval)
}
