//
// Copyright (c) 2025 Daniel Bauke
//

import SwiftCompilerPlugin

#if compiler(>=6.0)
import SwiftSyntaxMacros
#else
public import SwiftSyntaxMacros
#endif

@main
struct AwaitlessKitMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AwaitlessAttachedMacro.self,
        AwaitlessFreestandingMacro.self,
        IsolatedSafeMacro.self,
    ]
}
