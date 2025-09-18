//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["IsolatedSafe": IsolatedSafeMacro.self], record: .missing), .tags(.macros))
struct IsolatedSafeEnhancedTests {
    @Test("Expand IsolatedSafe with serial strategy", .tags(.macros))
    func serialStrategy() {
        assertMacro {
            """
            @IsolatedSafe(writable: true, strategy: .serial)
            private nonisolated(unsafe) var _unsafeItems: [String] = []
            """
        } expansion: {
            """
            private nonisolated(unsafe) var _unsafeItems: [String] = []

            internal var items: [String] {
                get {
                    accessQueueItems.sync {
                        self._unsafeItems
                    }
                }
                set {
                    accessQueueItems.sync {
                        self._unsafeItems = newValue
                    }
                }
            }

            private let accessQueueItems = DispatchQueue(label: "accessQueueItems")
            """
        }
    }

    @Test("Expand IsolatedSafe with custom queue name and strategy", .tags(.macros))
    func customQueueNameWithStrategy() {
        assertMacro {
            """
            @IsolatedSafe(writable: true, queueName: "customQueue", strategy: .serial)
            private nonisolated(unsafe) var _unsafeData: Data = Data()
            """
        } expansion: {
            """
            private nonisolated(unsafe) var _unsafeData: Data = Data()

            internal var data: Data {
                get {
                    customQueue.sync {
                        self._unsafeData
                    }
                }
                set {
                    customQueue.sync {
                        self._unsafeData = newValue
                    }
                }
            }

            private let customQueue = DispatchQueue(label: "customQueue")
            """
        }
    }
}
