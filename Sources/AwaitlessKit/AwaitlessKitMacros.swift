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

#if compiler(>=6.0)
    @freestanding(expression)
    public macro awaitless<T>(_ expression: T) -> T = #externalMacro(
        module: "AwaitlessKitMacros",
        type: "AwaitlessFreestandingMacro")
#endif

@attached(peer, names: arbitrary)
public macro IsolatedSafe(
    writable: Bool = false, 
    queueName: String? = nil,
    strategy: AwaitlessSynchronizationStrategy = .concurrent) = #externalMacro(
    module: "AwaitlessKitMacros",
    type: "IsolatedSafeMacro")
