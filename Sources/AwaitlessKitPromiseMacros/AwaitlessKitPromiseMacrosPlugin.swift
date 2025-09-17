//
// Copyright (c) 2025 Daniel Bauke
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct AwaitlessKitPromiseMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AwaitlessPromiseMacro.self,
    ]
}