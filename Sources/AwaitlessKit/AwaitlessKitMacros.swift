//
// Copyright (c) 2025 Daniel Bauke
//

// MARK: - AwaitlessKitMacros

@attached(peer, names: arbitrary)
public macro Awaitless() = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "AwaitlessMacro")

@attached(peer, names: arbitrary)
public macro IsolatedSafe(queueName: String? = nil) = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "IsolatedSafeMacro")
