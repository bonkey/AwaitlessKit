//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["Awaitlessable": AwaitlessableMacro.self], record: .missing), .tags(.macros))
struct AwaitlessableTests {
    @Test("Expand Awaitlessable on protocol with async methods", .tags(.macros))
    func protocolWithAsyncMethods() {
        assertMacro {
            """
            @Awaitlessable
            protocol DataService {
                func fetchUser(id: String) async throws -> User
                func fetchData() async -> Data
            }
            """
        } expansion: {
            """
            protocol DataService {
                func fetchUser(id: String) async throws -> User
                func fetchData() async -> Data

                func fetchUser(id: String) throws -> User

                func fetchData() -> Data
            }

            extension DataService {
                public func fetchUser(id: String) throws -> User {
                    return try Awaitless.run {
                        try await self.fetchUser(id: id)
                    }
                }
                public func fetchData() -> Data {
                    return Awaitless.run {
                        await self.fetchData()
                    }
                }
            }
            """
        }
    }

    @Test("Expand Awaitlessable on protocol with mixed methods", .tags(.macros))
    func protocolWithMixedMethods() {
        assertMacro {
            """
            @Awaitlessable
            protocol Service {
                func asyncMethod() async throws -> String
                func syncMethod() -> Int
                var readOnlyProperty: Bool { get }
                var readWriteProperty: [String] { get set }
            }
            """
        } expansion: {
            """
            protocol Service {
                func asyncMethod() async throws -> String
                func syncMethod() -> Int
                var readOnlyProperty: Bool { get }
                var readWriteProperty: [String] { get set }

                func asyncMethod() throws -> String
            }

            extension Service {
                public func asyncMethod() throws -> String {
                    return try Awaitless.run {
                        try await self.asyncMethod()
                    }
                }
            }
            """
        }
    }

    @Test("Expand Awaitlessable with extensionGeneration disabled", .tags(.macros))
    func protocolWithExtensionGenerationDisabled() {
        assertMacro {
            """
            @Awaitlessable(extensionGeneration: .disabled)
            protocol DataService {
                func fetchUser(id: String) async throws -> User
                func fetchData() async -> Data
            }
            """
        } expansion: {
            """
            protocol DataService {
                func fetchUser(id: String) async throws -> User
                func fetchData() async -> Data

                func fetchUser(id: String) throws -> User

                func fetchData() -> Data
            }
            """
        }
    }

    @Test("Expand Awaitlessable with extensionGeneration enabled explicitly", .tags(.macros))
    func protocolWithExtensionGenerationEnabled() {
        assertMacro {
            """
            @Awaitlessable(extensionGeneration: .enabled)
            protocol DataService {
                func fetchUser(id: String) async throws -> User
            }
            """
        } expansion: {
            """
            protocol DataService {
                func fetchUser(id: String) async throws -> User

                func fetchUser(id: String) throws -> User
            }

            extension DataService {
                public func fetchUser(id: String) throws -> User {
                    return try Awaitless.run {
                        try await self.fetchUser(id: id)
                    }
                }
            }
            """
        }
    }
}
