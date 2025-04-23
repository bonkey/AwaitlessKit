//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["awaitless": AwaitlessFreestandingMacro.self], record: .missing))
struct AwaitlessFreestandingTests {
    @Test("Expand freestanding macro")
    func basic() {
        assertMacro {
            """
            let result = #awaitless(fetchData())
            """
        } expansion: {
            """
            let result = Task.noasync({
                    return await fetchData()
                })
            """
        }
    }

    @Test("Handle try expression")
    func withTry() {
        assertMacro {
            """
            let result = #awaitless(try fetchData())
            """
        } expansion: {
            """
            let result = Task.noasync({
                    return try await fetchData()
                })
            """
        }
    }
}
