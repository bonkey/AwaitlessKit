//
// Copyright (c) 2025 Daniel Bauke
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct AwaitlessKitMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AwaitlessAttachedMacro.self,
        AwaitlessFreestandingMacro.self,
        IsolatedSafeMacro.self,
    ]
}
