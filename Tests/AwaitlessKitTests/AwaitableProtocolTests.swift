//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["Awaitable": AwaitableMacro.self], record: .missing), .tags(.macros))
struct AwaitableProtocolTests {
    @Test("Expand Awaitable on protocol with Publisher methods", .tags(.macros))
    func protocolWithPublisherMethods() {
        assertMacro {
            """
            @Awaitable
            protocol DataService {
                func fetchUser(id: String) -> AnyPublisher<User, Error>
                func fetchData() -> AnyPublisher<Data, Never>
            }
            """
        } expansion: {
            """
            protocol DataService {
                func fetchUser(id: String) -> AnyPublisher<User, Error>
                func fetchData() -> AnyPublisher<Data, Never>

                func fetchUser(id: String) async throws -> User

                func fetchData() async -> Data
            }

            extension DataService {
                @available(*, deprecated, message: "Combine support is deprecated; use async function instead", renamed: "fetchUser") public func fetchUser(id: String) async throws -> User {
                    return try await self.fetchUser(id: id).async()
                }
                @available(*, deprecated, message: "Combine support is deprecated; use async function instead", renamed: "fetchData") public func fetchData() async -> Data {
                    return await self.fetchData().value()
                }
            }
            """
        }
    }

    @Test("Expand Awaitable on protocol with completion handler methods", .tags(.macros))
    func protocolWithCompletionMethods() {
        assertMacro {
            """
            @Awaitable
            protocol DataService {
                func saveData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void)
                func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void)
            }
            """
        } expansion: {
            """
            protocol DataService {
                func saveData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void)
                func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void)
            }
            """
        }
    }

    @Test("Expand Awaitable on protocol with mixed methods", .tags(.macros))
    func protocolWithMixedMethods() {
        assertMacro {
            """
            @Awaitable
            protocol DataService {
                func fetchUser(id: String) -> AnyPublisher<User, Error>
                func saveData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void)
                func regularMethod() -> String
            }
            """
        } expansion: {
            """
            protocol DataService {
                func fetchUser(id: String) -> AnyPublisher<User, Error>
                func saveData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void)
                func regularMethod() -> String

                func fetchUser(id: String) async throws -> User
            }

            extension DataService {
                @available(*, deprecated, message: "Combine support is deprecated; use async function instead", renamed: "fetchUser") public func fetchUser(id: String) async throws -> User {
                    return try await self.fetchUser(id: id).async()
                }
            }
            """
        }
    }

    @Test("Expand Awaitable with extensionGeneration disabled", .tags(.macros))
    func protocolWithExtensionGenerationDisabled() {
        assertMacro {
            """
            @Awaitable(extensionGeneration: .disabled)
            protocol DataService {
                func fetchUser(id: String) -> AnyPublisher<User, Error>
                func saveData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void)
            }
            """
        } expansion: {
            """
            protocol DataService {
                func fetchUser(id: String) -> AnyPublisher<User, Error>
                func saveData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void)

                func fetchUser(id: String) async throws -> User
            }
            """
        }
    }

    @Test("Awaitable requires protocol", .tags(.macros))
    func requiresProtocol() {
        assertMacro {
            """
            @Awaitable
            class DataService {
                func fetchData() -> String {
                    return "data"
                }
            }
            """
        } diagnostics: {
            """
            @Awaitable
            ╰─ 🛑 @Awaitable can only be applied to protocols
            class DataService {
                func fetchData() -> String {
                    return "data"
                }
            }
            """
        }
    }
}
