//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKitPromiseKit
import AwaitlessKitPromiseMacros
import MacroTesting
import PromiseKit
import Testing

@Suite(.macros(["Awaitful": AwaitfulMacro.self], record: .missing), .tags(.macros))
struct AwaitfulMacroTests {
    
    @Test("Expand async wrapper for Promise function", .tags(.macros))
    func awaitfulBasic() {
        assertMacro {
            """
            @Awaitful
            func fetchData() -> Promise<String> {
                return Promise.value("OK")
            }
            """
        } expansion: {
            """
            func fetchData() -> Promise<String> {
                return Promise.value("OK")
            }

            @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "fetchData") func fetchData() async throws -> String {
                return try await self.fetchData().async()
            }
            """
        }
    }

    @Test("Expand async wrapper with prefix", .tags(.macros))
    func awaitfulWithPrefix() {
        assertMacro {
            """
            @Awaitful(prefix: "async_")
            func fetchUser() -> Promise<User> {
                return Promise.value(User())
            }
            """
        } expansion: {
            """
            func fetchUser() -> Promise<User> {
                return Promise.value(User())
            }

            @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "fetchUser") func async_fetchUser() async throws -> User {
                return try await self.fetchUser().async()
            }
            """
        }
    }

    @Test("Expand async wrapper with all options", .tags(.macros))
    func awaitfulWithParameters() {
        assertMacro {
            """
            @Awaitful
            func fetchUser(id: String, timeout: Double = 5.0) -> Promise<User> {
                return Promise.value(User())
            }
            """
        } expansion: {
            """
            func fetchUser(id: String, timeout: Double = 5.0) -> Promise<User> {
                return Promise.value(User())
            }

            @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "fetchUser") func fetchUser(id: String, timeout: Double = 5.0) async throws -> User {
                return try await self.fetchUser(id: id, timeout: timeout).async()
            }
            """
        }
    }

    @Test("Expand async wrapper with custom availability", .tags(.macros))
    func awaitfulWithCustomAvailability() {
        assertMacro {
            """
            @Awaitful(.deprecated("Use the new async API"))
            func legacy() -> Promise<String> {
                return Promise.value("data")
            }
            """
        } expansion: {
            """
            func legacy() -> Promise<String> {
                return Promise.value("data")
            }

            @available(*, deprecated, message: "Use the new async API", renamed: "legacy") func legacy() async throws -> String {
                return try await self.legacy().async()
            }
            """
        }
    }

    @Test("Expand async wrapper for Void Promise", .tags(.macros))
    func awaitfulVoidPromise() {
        assertMacro {
            """
            @Awaitful
            func save() -> Promise<Void> {
                return Promise.value(())
            }
            """
        } expansion: {
            """
            func save() -> Promise<Void> {
                return Promise.value(())
            }

            @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "save") func save() async throws -> Void {
                return try await self.save().async()
            }
            """
        }
    }

    @Test("Awaitful skips protocols", .tags(.macros))
    func awaitfulSkipsProtocols() {
        assertMacro {
            """
            @Awaitful
            protocol DataService {
                func fetchData() -> Promise<String>
            }
            """
        } expansion: {
            """
            protocol DataService {
                func fetchData() -> Promise<String>
            }
            """
        }
    }
}