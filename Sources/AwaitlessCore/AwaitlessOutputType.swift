//
// Copyright (c) 2025 Daniel Bauke
//

import Foundation

/// Defines the output type for the generated function.
public enum AwaitlessOutputType {
    /// Generates a standard synchronous function.
    case sync
    /// Generates a Combine publisher instead of a synchronous function.
    case publisher
}