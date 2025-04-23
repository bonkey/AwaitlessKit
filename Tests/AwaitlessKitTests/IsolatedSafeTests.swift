//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["IsolatedSafe": IsolatedSafeMacro.self], record: .missing))
struct IsolatedSafeTests {
    @Test("Expand basic isolated safe macro")
    func basic() {
        assertMacro {
            """
            @IsolatedSafe
            private nonisolated(unsafe) var _unsafeStrings: [String] = ["Hello", "World"]
            """
        } expansion: {
            """
            private nonisolated(unsafe) var _unsafeStrings: [String] = ["Hello", "World"]

            internal var strings: [String] {
                get {
                    accessQueueStrings.sync {
                        self._unsafeStrings
                    }
                }
            }

            private let accessQueueStrings = DispatchQueue(label: "accessQueueStrings", attributes: .concurrent)
            """
        }
    }

    @Test("Specify custom queue name")
    func withQueue() {
        assertMacro {
            """
            @IsolatedSafe(queueName: "blah")
            private nonisolated(unsafe) var _unsafeStrings: [String] = ["Hello", "World"]
            """
        } expansion: {
            """
            private nonisolated(unsafe) var _unsafeStrings: [String] = ["Hello", "World"]

            internal var strings: [String] {
                get {
                    blah.sync {
                        self._unsafeStrings
                    }
                }
            }

            private let blah = DispatchQueue(label: "blah", attributes: .concurrent)
            """
        }
    }

    @Test("Make property writable")
    func writable() {
        assertMacro {
            """
            @IsolatedSafe(writable: true)
            private nonisolated(unsafe) var _unsafeCache: [String: Any] = [:]
            """
        } expansion: {
            """
            private nonisolated(unsafe) var _unsafeCache: [String: Any] = [:]

            internal var cache: [String: Any] {
                get {
                    accessQueueCache.sync {
                        self._unsafeCache
                    }
                }
                set {
                    accessQueueCache.async(flags: .barrier) {
                        self._unsafeCache = newValue
                    }
                }
            }

            private let accessQueueCache = DispatchQueue(label: "accessQueueCache", attributes: .concurrent)
            """
        }
    }

    @Test("Specify custom access level")
    func accessLevel() {
        assertMacro {
            """
            @IsolatedSafe(accessLevel: "public", writable: true)
            private nonisolated(unsafe) var _unsafeSettings: [String: String] = [:]
            """
        } expansion: {
            """
            private nonisolated(unsafe) var _unsafeSettings: [String: String] = [:]

            public var settings: [String: String] {
                get {
                    accessQueueSettings.sync {
                        self._unsafeSettings
                    }
                }
                set {
                    accessQueueSettings.async(flags: .barrier) {
                        self._unsafeSettings = newValue
                    }
                }
            }

            private let accessQueueSettings = DispatchQueue(label: "accessQueueSettings", attributes: .concurrent)
            """
        }
    }
}
