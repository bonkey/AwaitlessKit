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

            @available(*, noasync) func fetchData() throws -> [String] {
                try Noasync.run({
                        try await fetchData()
                    })
            }
            """
        }
    }

    @Test("Expand macro with simple function parameters")
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

            @available(*, noasync) func greet(name: String, loudly: Bool = false) -> String {
                Noasync.run({
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

            @available(*, noasync) @available(*, unavailable, message: "This synchronous version of getData is unavailable") func getData() -> Data {
                Noasync.run({
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

            @available(*, noasync) @available(*, deprecated, message: "This sync version will be removed in v2.0", renamed: "processItems") func processItems() throws -> Bool {
                try Noasync.run({
                        try await processItems()
                    })
            }
            """
        }
    }

    @Test("Handle deprecated without message")
    func deprecatedNoMessage() {
        assertMacro {
            """
            @Awaitless(.deprecated("This sync version will be removed in v2.0"))
            func fetchItems() async -> [Int] {
                await Task.sleep(nanoseconds: 1_000_000)
                return [1, 2, 3]
            }
            """
        } expansion: {
            """
            func fetchItems() async -> [Int] {
                await Task.sleep(nanoseconds: 1_000_000)
                return [1, 2, 3]
            }

            @available(*, noasync) @available(*, deprecated, message: "This sync version will be removed in v2.0", renamed: "fetchItems") func fetchItems() -> [Int] {
                Noasync.run({
                        await fetchItems()
                    })
            }
            """
        }
    }

    @Test("Handle unavailable with custom message")
    func unavailableCustomMessage() {
        assertMacro {
            """
            @Awaitless(.unavailable("Please use the async version instead"))
            func loadConfig() async throws -> [String: Any] {
                try await Task.sleep(nanoseconds: 1_000_000)
                return ["key": "value"]
            }
            """
        } expansion: {
            """
            func loadConfig() async throws -> [String: Any] {
                try await Task.sleep(nanoseconds: 1_000_000)
                return ["key": "value"]
            }

            @available(*, noasync) @available(*, unavailable, message: "Please use the async version instead") func loadConfig() throws -> [String: Any] {
                try Noasync.run({
                        try await loadConfig()
                    })
            }
            """
        }
    }

    @Test("Handle empty prefix")
    func emptyPrefix() {
        assertMacro {
            """
            @Awaitless(prefix: "")
            func processQueue() async throws -> Void {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            """
        } expansion: {
            """
            func processQueue() async throws -> Void {
                try await Task.sleep(nanoseconds: 1_000_000)
            }

            @available(*, noasync) func processQueue() throws -> Void {
                try Noasync.run({
                        try await processQueue()
                    })
            }
            """
        }
    }

    @Test("Handle custom prefix")
    func customPrefix() {
        assertMacro {
            """
            @Awaitless(prefix: "sync_")
            func downloadFile(url: URL) async throws -> Data {
                try await Task.sleep(nanoseconds: 1_000_000)
                return Data()
            }
            """
        } expansion: {
            """
            func downloadFile(url: URL) async throws -> Data {
                try await Task.sleep(nanoseconds: 1_000_000)
                return Data()
            }

            @available(*, noasync) func sync_downloadFile(url: URL) throws -> Data {
                try Noasync.run({
                        try await downloadFile(url url)
                    })
            }
            """
        }
    }
}
