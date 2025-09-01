//
// Copyright (c) 2025 Daniel Bauke
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

// MARK: - AwaitlessKitMacrosPlugin

@main
struct AwaitlessKitMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AwaitlessAttachedMacro.self,
        AwaitlessFreestandingMacro.self,
        AwaitlessableMacro.self,
        IsolatedSafeMacro.self,
    ]
}
