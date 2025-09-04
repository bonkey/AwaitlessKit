//
// Copyright (c) 2025 Daniel Bauke
//

import Foundation

/// Configuration data for AwaitlessKit defaults.
/// This type will be generated as a static property by @AwaitlessConfig.
public struct AwaitlessConfigData {
    public let prefix: String?
    public let availability: AwaitlessAvailability?
    public let delivery: AwaitlessDelivery?
    public let strategy: AwaitlessSynchronizationStrategy?
    
    public init(
        prefix: String? = nil,
        availability: AwaitlessAvailability? = nil,
        delivery: AwaitlessDelivery? = nil,
        strategy: AwaitlessSynchronizationStrategy? = nil
    ) {
        self.prefix = prefix
        self.availability = availability
        self.delivery = delivery
        self.strategy = strategy
    }
}