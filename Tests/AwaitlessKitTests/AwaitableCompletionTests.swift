//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["AwaitableCompletion": AwaitableCompletionMacro.self], record: .missing), .tags(.macros))
struct AwaitableCompletionTests {
    @Test("Expand AwaitableCompletion on completion handler function", .tags(.macros))
    func completionFunction() {
        assertMacro {
            """
            @AwaitableCompletion
            func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {
                // Implementation
            }
            """
        } expansion: {
            """
            func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {
                // Implementation
            }

            @available(*, deprecated, message: "Completion handler support is deprecated; use async function instead", renamed: "fetchData") func fetchData() async throws -> Data {
                return try await withCheckedThrowingContinuation { continuation in
                    self.fetchData(completion: { result in
                            continuation.resume(with: result)
                        })
                }
            }
            """
        }
    }

    @Test("Expand AwaitableCompletion with prefix", .tags(.macros))
    func completionFunctionWithPrefix() {
        assertMacro {
            """
            @AwaitableCompletion(prefix: "async_")
            func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void) {
                // Implementation
            }
            """
        } expansion: {
            """
            func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void) {
                // Implementation
            }

            @available(*, deprecated, message: "Completion handler support is deprecated; use async function instead", renamed: "fetchUser") func async_fetchUser(id: String) async throws -> User {
                return try await withCheckedThrowingContinuation { continuation in
                    self.fetchUser(id: id, completion: { result in
                            continuation.resume(with: result)
                        })
                }
            }
            """
        }
    }

    @Test("Expand AwaitableCompletion with Void result", .tags(.macros))
    func completionFunctionWithVoidResult() {
        assertMacro {
            """
            @AwaitableCompletion
            func saveData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
                // Implementation
            }
            """
        } expansion: {
            """
            func saveData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
                // Implementation
            }

            @available(*, deprecated, message: "Completion handler support is deprecated; use async function instead", renamed: "saveData") func saveData(_ data: Data) async throws {
                try await withCheckedThrowingContinuation { continuation in
                    self.saveData(data, completion: { result in
                            continuation.resume(with: result)
                        })
                }
            }
            """
        }
    }

    @Test("AwaitableCompletion requires function", .tags(.macros))
    func requiresFunction() {
        assertMacro {
            """
            @AwaitableCompletion
            var data: String = ""
            """
        } diagnostics: {
            """
            @AwaitableCompletion
            ╰─ 🛑 @AwaitableCompletion can only be applied to functions
            var data: String = ""
            """
        }
    }

    @Test("AwaitableCompletion requires completion handler parameter", .tags(.macros))
    func requiresCompletionHandler() {
        assertMacro {
            """
            @AwaitableCompletion
            func fetchData() -> String {
                return "data"
            }
            """
        } diagnostics: {
            """
            @AwaitableCompletion
            func fetchData() -> String {
                 ┬────────
                 ╰─ 🛑 @AwaitableCompletion requires the function to have a completion handler parameter
                return "data"
            }
            """
        }
    }
}
