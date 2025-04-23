//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessCore

@attached(peer, names: arbitrary)
public macro Awaitless(_ available: AwaitlessAvailability? = nil) = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "AwaitlessAttachedMacro")

@freestanding(expression)
public macro awaitless<T>(_ expression: T) -> T = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "AwaitlessFreestandingMacro")

@attached(peer, names: arbitrary)
public macro IsolatedSafe(writable: Bool = false, queueName: String? = nil) = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "IsolatedSafeMacro")
