//
// Copyright (c) 2025 Daniel Bauke
//

import Foundation

/// Defines the synchronization strategy for the generated property.
public enum AwaitlessSynchronizationStrategy {
    /// Uses a concurrent queue with sync/async barrier for read/write operations
    case concurrent
    /// Uses a serial queue for all operations
    case serial
}
