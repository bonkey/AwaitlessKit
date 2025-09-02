//
// Copyright (c) 2025 Daniel Bauke
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct AwaitlessKitMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AwaitlessSyncMacro.self,
        AwaitlessPublisherMacro.self,
        AwaitlessCompletionMacro.self,
        AwaitlessFreestandingMacro.self,
        AwaitlessableMacro.self,
        IsolatedSafeMacro.self,
    ]
}
