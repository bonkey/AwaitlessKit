//
// Copyright (c) 2025 Daniel Bauke
//

import SwiftCompilerPlugin

#if compiler(>=6.0)
    import SwiftSyntaxMacros
#else
    public import SwiftSyntaxMacros
#endif

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
