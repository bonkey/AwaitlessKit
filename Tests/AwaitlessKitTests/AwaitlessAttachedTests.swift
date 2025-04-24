//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["Awaitless": AwaitlessAttachedMacro.self], record: .missing))
struct AwaitlessAttachedTests {
    @Test("Expand basic attached macro")
    func basic() {
        assertMacro {
            """
            @Awaitless
            func fetchData() async throws -> [String] {
                // simulate network request
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return ["Hello", "World"]
            }
            """
        } expansion: {
            """
            func fetchData() async throws -> [String] {
                // simulate network request
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return ["Hello", "World"]
            }

            @available(*, noasync) func awaitless_fetchData() throws -> [String] {
                try Task.noasync({
                        try await fetchData()
                    })
            }
            """
        }
    }

    @Test("Expand macro with function parameters")
    func withParams() {
        assertMacro {
            """
            @Awaitless
            func greet(name: String, loudly: Bool = false) async -> String {
                await Task.sleep(nanoseconds: 1_000_000)
                return loudly ? "HELLO, \\(name.uppercased())!" : "Hello, \\(name)."
            }
            """
        } expansion: {
            #"""
            func greet(name: String, loudly: Bool = false) async -> String {
                await Task.sleep(nanoseconds: 1_000_000)
                return loudly ? "HELLO, \(name.uppercased())!" : "Hello, \(name)."
            }

            @available(*, noasync) func awaitless_greet(name: String, loudly: Bool = false) -> String {
                Task.noasync({
                        await greet(name name loudly loudly)
                    })
            }
            """#
        }
    }

    @Test("Handle deprecated flag")
    func deprecated() {
        assertMacro {
            """
            @Awaitless(.unavailable())
            func getData() async -> Data {
                await Task.sleep(nanoseconds: 1_000_000)
                return Data()
            }
            """
        } expansion: {
            """
            func getData() async -> Data {
                await Task.sleep(nanoseconds: 1_000_000)
                return Data()
            }

            @available(*, noasync) @available(*, unavailable, message: "This synchronous version of getData is unavailable") func awaitless_getData() -> Data {
                Task.noasync({
                        await getData()
                    })
            }
            """
        }
    }

    @Test("Add custom deprecation message")
    func customMessage() {
        assertMacro {
            """
            @Awaitless(.deprecated("This sync version will be removed in v2.0"))
            func processItems() async throws -> Bool {
                try await Task.sleep(nanoseconds: 1_000_000)
                return true
            }
            """
        } expansion: {
            """
            func processItems() async throws -> Bool {
                try await Task.sleep(nanoseconds: 1_000_000)
                return true
            }

            @available(*, noasync) @available(*, deprecated, message: "This sync version will be removed in v2.0", renamed: "processItems") func awaitless_processItems() throws -> Bool {
                try Task.noasync({
                        try await processItems()
                    })
            }
            """
        }
    }
}
