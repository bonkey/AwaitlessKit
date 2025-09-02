//
// Copyright (c) 2025 Daniel Bauke
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

// MARK: - AwaitlessKitMacrosPlugin

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
