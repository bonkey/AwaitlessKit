//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["AwaitablePublisher": AwaitablePublisherMacro.self], record: .missing), .tags(.macros))
struct AwaitablePublisherTests {
    @Test("Expand AwaitablePublisher on Publisher function", .tags(.macros))
    func publisherFunction() {
        assertMacro {
            """
            @AwaitablePublisher
            func fetchData() -> AnyPublisher<Data, Error> {
                return publisher
            }
            """
        } expansion: {
            """
            func fetchData() -> AnyPublisher<Data, Error> {
                return publisher
            }

            func fetchData() async throws -> Data {
                return try await self.fetchData().async()
            }
            """
        }
    }

    @Test("Expand AwaitablePublisher with prefix", .tags(.macros))
    func publisherFunctionWithPrefix() {
        assertMacro {
            """
            @AwaitablePublisher(prefix: "async_")
            func fetchUser(id: String) -> AnyPublisher<User, Error> {
                return publisher
            }
            """
        } expansion: {
            """
            func fetchUser(id: String) -> AnyPublisher<User, Error> {
                return publisher
            }

            func async_fetchUser(id: String) async throws -> User {
                return try await self.fetchUser(id: id).async()
            }
            """
        }
    }

    @Test("Expand AwaitablePublisher with Never error type", .tags(.macros))
    func publisherFunctionWithNeverError() {
        assertMacro {
            """
            @AwaitablePublisher
            func fetchData() -> AnyPublisher<Data, Never> {
                return publisher
            }
            """
        } expansion: {
            """
            func fetchData() -> AnyPublisher<Data, Never> {
                return publisher
            }

            func fetchData() async -> Data {
                return await self.fetchData().value
            }
            """
        }
    }

    @Test("AwaitablePublisher requires function", .tags(.macros))
    func requiresFunction() {
        assertMacro {
            """
            @AwaitablePublisher
            var data: String = ""
            """
        } diagnostics: {
            """
            @AwaitablePublisher
            ╰─ 🛑 @AwaitablePublisher can only be applied to functions
            var data: String = ""
            """
        }
    }

    @Test("AwaitablePublisher requires Publisher return type", .tags(.macros))
    func requiresPublisherReturn() {
        assertMacro {
            """
            @AwaitablePublisher
            func fetchData() -> String {
                return "data"
            }
            """
        } diagnostics: {
            """
            @AwaitablePublisher
            func fetchData() -> String {
                 ┬────────
                 ╰─ 🛑 @AwaitablePublisher requires the function to return a Publisher<T, E>
                return "data"
            }
            """
        }
    }

    @Test("AwaitablePublisher with explicit deprecated availability", .tags(.macros))
    func publisherFunctionWithDeprecated() {
        assertMacro {
            """
            @AwaitablePublisher(.deprecated())
            func fetchData() -> AnyPublisher<Data, Error> {
                return publisher
            }
            """
        } expansion: {
            """
            func fetchData() -> AnyPublisher<Data, Error> {
                return publisher
            }

            @available(*, deprecated, message: "Combine support is deprecated; use async function instead", renamed: "fetchData") func fetchData() async throws -> Data {
                return try await self.fetchData().async()
            }
            """
        }
    }

    @Test("AwaitablePublisher with custom deprecated message", .tags(.macros))
    func publisherFunctionWithCustomMessage() {
        assertMacro {
            """
            @AwaitablePublisher(.deprecated("Use async version"))
            func fetchData() -> AnyPublisher<Data, Error> {
                return publisher
            }
            """
        } expansion: {
            """
            func fetchData() -> AnyPublisher<Data, Error> {
                return publisher
            }

            @available(*, deprecated, message: "Use async version", renamed: "fetchData") func fetchData() async throws -> Data {
                return try await self.fetchData().async()
            }
            """
        }
    }
}
