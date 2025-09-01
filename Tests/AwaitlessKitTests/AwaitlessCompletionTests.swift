//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["Awaitless": AwaitlessAttachedMacro.self, "AwaitlessCompletion": AwaitlessAttachedMacro.self], record: .missing))
struct AwaitlessCompletionTests {
    @Test("Expand completion wrapper for throwing function with return")
    func completionThrowing() {
        assertMacro {
            """
            @AwaitlessCompletion
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

            func fetch(completion: @escaping (Result<String, Error>) -> Void) {
                Task() {
                    do {
                        let result = try await self.fetch()
                        completion(.success(result))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
            """
        }
    }

    @Test("Expand completion wrapper for non-throwing function with return")
    func completionNonThrowing() {
        assertMacro {
            """
            @AwaitlessCompletion
            func data() async -> Int { 1 }
            """
        } expansion: {
            """
            func data() async -> Int { 1 }

            func data(completion: @escaping (Result<Int, Error>) -> Void) {
                Task() {
                    let result = await self.data()
                    completion(.success(result))
                }
            }
            """
        }
    }

    @Test("Expand completion wrapper for void-returning function")
    func completionVoid() {
        assertMacro {
            """
            @AwaitlessCompletion
            func ping() async { }
            """
        } expansion: {
            """
            func ping() async { }

            func ping(completion: @escaping (Result<Void, Error>) -> Void) {
                Task() {
                    await self.ping()
                    completion(.success(()))
                }
            }
            """
        }
    }

    @Test("Expand completion wrapper with prefix")
    func completionWithPrefix() {
        assertMacro {
            """
            @AwaitlessCompletion(prefix: "c_")
            func calc() async -> Int { 2 }
            """
        } expansion: {
            """
            func calc() async -> Int { 2 }

            func c_calc(completion: @escaping (Result<Int, Error>) -> Void) {
                Task() {
                    let result = await self.calc()
                    completion(.success(result))
                }
            }
            """
        }
    }
}

