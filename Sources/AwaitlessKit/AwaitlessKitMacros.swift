//
// Copyright (c) 2025 Daniel Bauke
//

public import AwaitlessCore

@attached(peer, names: arbitrary)
public macro Awaitless(
    prefix: String = "", 
    as outputType: AwaitlessOutputType = .sync,
    _ availability: AwaitlessAvailability? = nil) = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "AwaitlessAttachedMacro")

// Publisher-only entry point for clearer API surface (SR-01)
@attached(peer, names: arbitrary)
public macro AwaitlessPublisher(
    prefix: String = "",
    deliverOn: AwaitlessDelivery = .current,
    _ availability: AwaitlessAvailability? = nil) = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "AwaitlessAttachedMacro")

@freestanding(expression)
public macro awaitless<T>(_ expression: T) -> T = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "AwaitlessFreestandingMacro")

@attached(member, names: arbitrary)
@attached(extension, names: arbitrary)
public macro Awaitlessable(
    extensionGeneration: AwaitlessableExtensionGeneration = .enabled
) = #externalMacro(
    module: "AwaitlessKitMacros", 
    type: "AwaitlessableMacro")

@attached(peer, names: arbitrary)
public macro IsolatedSafe(
    writable: Bool = false, 
    queueName: String? = nil,
    strategy: AwaitlessSynchronizationStrategy = .concurrent) = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "IsolatedSafeMacro")
