//
// Copyright (c) 2025 Daniel Bauke
//

import Testing

// MARK: - Centralized Test Tags

extension Tag {
    /// Tests that verify macro expansion and code generation
    @Tag static var macros: Self
    
    /// Tests that verify runtime functionality and behavior
    @Tag static var functional: Self
    
    /// Tests that stress test performance, run many iterations, or test race conditions
    @Tag static var performance: Self
    
    /// Tests that may take longer to execute (typically >1 second)
    @Tag static var longRunning: Self
}