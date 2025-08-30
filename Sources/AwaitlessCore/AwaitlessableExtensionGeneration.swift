//
// Copyright (c) 2025 Daniel Bauke
//

import Foundation

/// Defines whether and how extensions should be generated for `@Awaitlessable` protocols.
public enum AwaitlessableExtensionGeneration {
    /// No extensions are generated. Only protocol members are added.
    case disabled
    /// Extensions with default implementations are generated using `Noasync.run`.
    case enabled
}