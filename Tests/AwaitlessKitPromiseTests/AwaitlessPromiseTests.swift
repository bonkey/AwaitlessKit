//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKitPromiseKit
import AwaitlessKitPromiseMacros
import MacroTesting
import PromiseKit
import Testing

@Suite(.macros(
    ["AwaitlessPromise": AwaitlessPromiseMacro.self, "Awaitable": AwaitableMacro.self],
    record: .missing))
struct AwaitlessPromiseTests {
    @Test("Expand Promise wrapper for throwing function with return")
    func promiseThrowing() {
        assertMacro {
            """
            @AwaitlessPromise
            func fetch() async throws -> String {
                try await Task.sleep(nanoseconds: 1)
                return "OK"
            }
            """
        } expansion: {
            """
            func fetch() async throws -> String {
                try await Task.sleep(nanoseconds: 1)
                return "OK"
            }

            func fetch() -> Promise<String> {
                return Promise { seal in
                    Task() {
                        do {
                            let result = try await self.fetch()
                            seal.fulfill(result)
                        } catch {
                            seal.reject(error)
                        }
                    }
                }
            }
            """
        }
    }

    @Test("Expand Promise wrapper for non-throwing function with return")
    func promiseNonThrowing() {
        assertMacro {
            """
            @AwaitlessPromise
            func data() async -> Int { 1 }
            """
        } expansion: {
            """
            func data() async -> Int { 1 }

            func data() -> Promise<Int> {
                return Promise { seal in
                    Task() {
                        let result = await self.data()
                        seal.fulfill(result)
                    }
                }
            }
            """
        }
    }

    @Test("Expand Promise wrapper for void-returning function")
    func promiseVoid() {
        assertMacro {
            """
            @AwaitlessPromise
            func ping() async { }
            """
        } expansion: {
            """
            func ping() async { }

            func ping() -> Promise<Void> {
                return Promise { seal in
                    Task() {
                        await self.ping()
                        seal.fulfill(())
                    }
                }
            }
            """
        }
    }

    @Test("Expand Promise wrapper with prefix")
    func promiseWithPrefix() {
        assertMacro {
            """
            @AwaitlessPromise(prefix: "promise_")
            func calc() async -> Int { 2 }
            """
        } expansion: {
            """
            func calc() async -> Int { 2 }

            func promise_calc() -> Promise<Int> {
                return Promise { seal in
                    Task() {
                        let result = await self.calc()
                        seal.fulfill(result)
                    }
                }
            }
            """
        }
    }

    @Test("Expand Promise wrapper with parameters")
    func promiseWithParameters() {
        assertMacro {
            """
            @AwaitlessPromise
            func fetchUser(id: String, timeout: Double = 5.0) async throws -> User {
                // Implementation here
            }
            """
        } expansion: {
            """
            func fetchUser(id: String, timeout: Double = 5.0) async throws -> User {
                // Implementation here
            }

            func fetchUser(id: String, timeout: Double = 5.0) -> Promise<User> {
                return Promise { seal in
                    Task() {
                        do {
                            let result = try await self.fetchUser(id: id, timeout: timeout)
                            seal.fulfill(result)
                        } catch {
                            seal.reject(error)
                        }
                    }
                }
            }
            """
        }
    }

    @Test("Expand Promise wrapper with availability attribute")
    func promiseWithAvailability() {
        assertMacro {
            """
            @AwaitlessPromise(.deprecated("Use async version"))
            func legacy() async -> String { "data" }
            """
        } expansion: {
            """
            func legacy() async -> String { "data" }

            @available(*, deprecated, message: "Use async version", renamed: "legacy") func legacy() -> Promise<String> {
                return Promise { seal in
                    Task() {
                        let result = await self.legacy()
                        seal.fulfill(result)
                    }
                }
            }
            """
        }
    }

    @Test("Promise wrapper skips protocols")
    func promiseSkipsProtocols() {
        assertMacro {
            """
            @AwaitlessPromise
            protocol DataService {
                func fetchData() async -> String
            }
            """
        } expansion: {
            """
            protocol DataService {
                func fetchData() async -> String
            }
            """
        }
    }

    @Test("Promise wrapper with Void explicit return type") 
    func promiseExplicitVoid() {
        assertMacro {
            """
            @AwaitlessPromise
            func save() async -> Void {
                // Save implementation
            }
            """
        } expansion: {
            """
            func save() async -> Void {
                // Save implementation
            }

            func save() -> Promise<Void> {
                return Promise { seal in
                    Task() {
                        await self.save()
                        seal.fulfill(())
                    }
                }
            }
            """
        }
    }

    @Test("Promise wrapper with complex return type")
    func promiseComplexReturnType() {
        assertMacro {
            """
            @AwaitlessPromise
            func fetchData() async throws -> [String: Any] {
                return [:]
            }
            """
        } expansion: {
            """
            func fetchData() async throws -> [String: Any] {
                return [:]
            }

            func fetchData() -> Promise<[String: Any]> {
                return Promise { seal in
                    Task() {
                        do {
                            let result = try await self.fetchData()
                            seal.fulfill(result)
                        } catch {
                            seal.reject(error)
                        }
                    }
                }
            }
            """
        }
    }

    // MARK: - @Awaitable Macro Tests

    @Test("Expand async wrapper for Promise function")
    func awaitableBasic() {
        assertMacro {
            """
            @Awaitable
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

    @Test("Expand async wrapper with prefix")
    func awaitableWithPrefix() {
        assertMacro {
            """
            @Awaitable(prefix: "async_")
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

    @Test("Expand async wrapper with parameters")
    func awaitableWithParameters() {
        assertMacro {
            """
            @Awaitable
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

    @Test("Expand async wrapper with custom availability")
    func awaitableWithCustomAvailability() {
        assertMacro {
            """
            @Awaitable(.deprecated("Use the new async API"))
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

    @Test("Expand async wrapper for Void Promise")
    func awaitableVoidPromise() {
        assertMacro {
            """
            @Awaitable
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

    @Test("Awaitable skips protocols")
    func awaitableSkipsProtocols() {
        assertMacro {
            """
            @Awaitable
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