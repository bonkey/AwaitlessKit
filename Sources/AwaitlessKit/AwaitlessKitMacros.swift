//
// Copyright (c) 2025 Daniel Bauke
//

public import AwaitlessCore

@attached(peer, names: arbitrary)
public macro Awaitless(prefix: String = "", _ availability: AwaitlessAvailability? = nil) = #externalMacro(
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
