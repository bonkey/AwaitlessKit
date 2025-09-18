//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKitPromiseKit
import AwaitlessKitPromiseMacros
import MacroTesting
import PromiseKit
import Testing

@Suite(.macros(["Awaitfulable": AwaitfulableMacro.self], record: .missing), .tags(.macros))
struct AwaitfulableProtocolTests {
    
    @Test("Expand Awaitfulable on protocol with Promise methods", .tags(.macros))
    func awaitfulableProtocolWithPromiseMethods() {
        assertMacro {
            """
            @Awaitfulable
            protocol DataService {
                func fetchUser(id: String) -> Promise<User>
                func fetchData() -> Promise<Data>
            }
            """
        } expansion: {
            """
            protocol DataService {
                func fetchUser(id: String) -> Promise<User>
                func fetchData() -> Promise<Data>

                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "fetchUser") func fetchUser(id: String) async throws -> User

                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "fetchData") func fetchData() async throws -> Data
            }

            extension DataService {
                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "fetchUser") public func fetchUser(id: String) async throws -> User {
                    return try await self.fetchUser(id: id).async()
                }
                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "fetchData") public func fetchData() async throws -> Data {
                    return try await self.fetchData().async()
                }
            }
            """
        }
    }

    @Test("Expand Awaitfulable on protocol with parameters", .tags(.macros))
    func awaitfulableProtocolWithMixedMethods() {
        assertMacro {
            """
            @Awaitfulable
            protocol Service {
                func promiseMethod() -> Promise<String>
                func syncMethod() -> Int
                var readOnlyProperty: Bool { get }
                var readWriteProperty: [String] { get set }
            }
            """
        } expansion: {
            """
            protocol Service {
                func promiseMethod() -> Promise<String>
                func syncMethod() -> Int
                var readOnlyProperty: Bool { get }
                var readWriteProperty: [String] { get set }

                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "promiseMethod") func promiseMethod() async throws -> String
            }

            extension Service {
                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "promiseMethod") public func promiseMethod() async throws -> String {
                    return try await self.promiseMethod().async()
                }
            }
            """
        }
    }

    @Test("Expand Awaitfulable with extensionGeneration disabled", .tags(.macros))
    func awaitfulableProtocolWithExtensionGenerationDisabled() {
        assertMacro {
            """
            @Awaitfulable(extensionGeneration: .disabled)
            protocol DataService {
                func fetchUser(id: String) -> Promise<User>
                func fetchData() -> Promise<Data>
            }
            """
        } expansion: {
            """
            protocol DataService {
                func fetchUser(id: String) -> Promise<User>
                func fetchData() -> Promise<Data>

                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "fetchUser") func fetchUser(id: String) async throws -> User

                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "fetchData") func fetchData() async throws -> Data
            }
            """
        }
    }

    @Test("Expand Awaitfulable with prefix on protocol", .tags(.macros))
    func awaitfulableProtocolWithPrefix() {
        assertMacro {
            """
            @Awaitfulable(prefix: "async_")
            protocol DataService {
                func fetchUser(id: String) -> Promise<User>
            }
            """
        } expansion: {
            """
            protocol DataService {
                func fetchUser(id: String) -> Promise<User>

                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "fetchUser") func async_fetchUser(id: String) async throws -> User
            }

            extension DataService {
                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "fetchUser") public func async_fetchUser(id: String) async throws -> User {
                    return try await self.fetchUser(id: id).async()
                }
            }
            """
        }
    }

    @Test("Expand Awaitfulable with custom availability on protocol", .tags(.macros))
    func awaitfulableProtocolWithCustomAvailability() {
        assertMacro {
            """
            @Awaitfulable(.unavailable("Use async methods"))
            protocol LegacyService {
                func fetchData() -> Promise<String>
            }
            """
        } expansion: {
            """
            protocol LegacyService {
                func fetchData() -> Promise<String>

                @available(*, unavailable, message: "Use async methods") func fetchData() async throws -> String
            }

            extension LegacyService {
                @available(*, unavailable, message: "Use async methods") public func fetchData() async throws -> String {
                    return try await self.fetchData().async()
                }
            }
            """
        }
    }

    @Test("Expand Awaitfulable for Void Promise methods", .tags(.macros))
    func awaitfulableVoidPromiseMethods() {
        assertMacro {
            """
            @Awaitfulable
            protocol ActionService {
                func save() -> Promise<Void>
                func delete(id: String) -> Promise<()>
            }
            """
        } expansion: {
            """
            protocol ActionService {
                func save() -> Promise<Void>
                func delete(id: String) -> Promise<()>

                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "save") func save() async throws -> Void

                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "delete") func delete(id: String) async throws -> ()
            }

            extension ActionService {
                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "save") public func save() async throws -> Void {
                    return try await self.save().async()
                }
                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "delete") public func delete(id: String) async throws -> () {
                    return try await self.delete(id: id).async()
                }
            }
            """
        }
    }
}