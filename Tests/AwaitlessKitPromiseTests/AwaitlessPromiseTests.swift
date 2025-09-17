//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKitPromiseKit
import AwaitlessKitPromiseMacros
import MacroTesting
import PromiseKit
import Testing

@Suite(.macros(
    ["AwaitlessPromise": AwaitlessPromiseMacro.self],
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
}