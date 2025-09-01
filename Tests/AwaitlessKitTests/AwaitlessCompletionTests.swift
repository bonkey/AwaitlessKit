//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["AwaitlessCompletion": AwaitlessAttachedMacro.self], record: .missing))
struct AwaitlessCompletionTests {
    @Test("Expand basic completion handler macro")
    func basic() {
        assertMacro {
            """
            @AwaitlessCompletion
            func fetchData() async throws -> String {
                // simulate network request
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return "Hello World"
            }
            """
        } expansion: {
            """
            func fetchData() async throws -> String {
                // simulate network request
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return "Hello World"
            }

            func fetchData(completion: @escaping (Result<String, Error>) -> Void) {
                Task {
                    do {
                        let result = try await fetchData()
                        completion(.success(result))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
            """
        }
    }

    @Test("Expand completion handler macro with Void return")
    func voidReturn() {
        assertMacro {
            """
            @AwaitlessCompletion
            func performAction() async throws {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            """
        } expansion: {
            """
            func performAction() async throws {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }

            func performAction(completion: @escaping (Result<Void, Error>) -> Void) {
                Task {
                    do {
                        try await performAction()
                        completion(.success(()))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
            """
        }
    }

    @Test("Expand completion handler macro for non-throwing function")
    func nonThrowing() {
        assertMacro {
            """
            @AwaitlessCompletion
            func fetchData() async -> String {
                await Task.sleep(nanoseconds: 1_000_000_000)
                return "Hello World"
            }
            """
        } expansion: {
            """
            func fetchData() async -> String {
                await Task.sleep(nanoseconds: 1_000_000_000)
                return "Hello World"
            }

            func fetchData(completion: @escaping (Result<String, Error>) -> Void) {
                Task {
                    let result = await fetchData()
                    completion(.success(result))
                }
            }
            """
        }
    }

    @Test("Expand completion handler macro with prefix")
    func withPrefix() {
        assertMacro {
            """
            @AwaitlessCompletion(prefix: "callback")
            func fetchData() async throws -> String {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return "Hello World"
            }
            """
        } expansion: {
            """
            func fetchData() async throws -> String {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return "Hello World"
            }

            func callbackfetchData(completion: @escaping (Result<String, Error>) -> Void) {
                Task {
                    do {
                        let result = try await fetchData()
                        completion(.success(result))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
            """
        }
    }

    @Test("Expand completion handler macro with parameters")
    func withParameters() {
        assertMacro {
            """
            @AwaitlessCompletion
            func greet(name: String, loudly: Bool = false) async -> String {
                await Task.sleep(nanoseconds: 1_000_000)
                return loudly ? "HELLO, \\(name.uppercased())!" : "Hello, \\(name)."
            }
            """
        } expansion: {
            """
            func greet(name: String, loudly: Bool = false) async -> String {
                await Task.sleep(nanoseconds: 1_000_000)
                return loudly ? "HELLO, \\(name.uppercased())!" : "Hello, \\(name)."
            }

            func greet(name: String, loudly: Bool = false, completion: @escaping (Result<String, Error>) -> Void) {
                Task {
                    let result = await greet(name: name, loudly: loudly)
                    completion(.success(result))
                }
            }
            """
        }
    }
}