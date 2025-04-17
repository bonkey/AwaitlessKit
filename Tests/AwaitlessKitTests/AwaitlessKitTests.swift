//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(
    .macros(
        ["IsolatedSafe": IsolatedSafeMacro.self],
        record: .missing))
struct StringifyMacroSwiftTestingTests {
    @Test
    func testIsolatedSafe() {
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
}
