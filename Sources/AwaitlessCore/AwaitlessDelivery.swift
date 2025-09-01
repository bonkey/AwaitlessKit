//
// Copyright (c) 2025 Daniel Bauke
//

import Foundation

/// Controls delivery context for generated publishers.
public enum AwaitlessDelivery {
    /// Do not modify delivery; emit on the Task's context.
    case current
    /// Deliver on the main queue (UI‑friendly).
    case main
}

