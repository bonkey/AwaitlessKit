//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["CompletionBlock": CompletionBlockAttachedMacro.self], record: .missing))
struct CompletionBlockMacroTests {
    @Test("Expand basic completion block macro")
    func basic() {
        assertMacro {
            """
            @CompletionBlock
            func fetchData() async throws -> [String] {
                // simulate network request
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return ["Hello", "World"]
            }
            """
        } expansion: {
            """
            func fetchData() async throws -> [String] {
                // simulate network request
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return ["Hello", "World"]
            }

            func fetchDataWithCompletion(completion: @escaping (Result<[String], Error>) -> Void) {
                Task {
                    do {
                        let result = try await fetchData()
                        completion(Result.success(result))
                    } catch {
                        completion(Result.failure(error))
                    }
                }
            }
            """
        }
    }

    @Test("Expand macro with function parameters")
    func withParams() {
        assertMacro {
            """
            @CompletionBlock
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

            func greetWithCompletion(name: String, loudly: Bool = false, completion: @escaping (Result<String, Error>) -> Void) {
                Task {
                    let result = await greet(name: name, loudly: loudly)
                    completion(Result.success(result))
                }
            }
            """
        }
    }

    @Test("Expand macro with void return type")
    func voidReturn() {
        assertMacro {
            """
            @CompletionBlock
            func performAction() async throws {
                try await Task.sleep(nanoseconds: 1_000_000)
                print("Action completed")
            }
            """
        } expansion: {
            """
            func performAction() async throws {
                try await Task.sleep(nanoseconds: 1_000_000)
                print("Action completed")
            }

            func performActionWithCompletion(completion: @escaping (Result<Void, Error>) -> Void) {
                Task {
                    do {
                        try await performAction()
                        completion(Result.success(()))
                    } catch {
                        completion(Result.failure(error))
                    }
                }
            }
            """
        }
    }

    @Test("Expand macro with custom prefix")
    func customPrefix() {
        assertMacro {
            """
            @CompletionBlock(prefix: "Callback")
            func downloadFile(url: URL) async throws -> Data {
                let (data, _) = try await URLSession.shared.data(from: url)
                return data
            }
            """
        } expansion: {
            """
            func downloadFile(url: URL) async throws -> Data {
                let (data, _) = try await URLSession.shared.data(from: url)
                return data
            }

            func downloadFileCallback(url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
                Task {
                    do {
                        let result = try await downloadFile(url: url)
                        completion(Result.success(result))
                    } catch {
                        completion(Result.failure(error))
                    }
                }
            }
            """
        }
    }

    @Test("Expand macro with deprecated availability")
    func deprecated() {
        assertMacro {
            """
            @CompletionBlock(.deprecated("Use async version instead"))
            func legacyFunction() async -> String {
                await Task.sleep(nanoseconds: 1_000_000)
                return "Legacy result"
            }
            """
        } expansion: {
            """
            func legacyFunction() async -> String {
                await Task.sleep(nanoseconds: 1_000_000)
                return "Legacy result"
            }

            @available(*, deprecated, message: "Use async version instead", renamed: "legacyFunction")
            func legacyFunctionWithCompletion(completion: @escaping (Result<String, Error>) -> Void) {
                Task {
                    let result = await legacyFunction()
                    completion(Result.success(result))
                }
            }
            """
        }
    }

    @Test("Expand macro with unavailable availability")
    func unavailable() {
        assertMacro {
            """
            @CompletionBlock(.unavailable("This completion version is not supported"))
            func modernFunction() async throws -> Int {
                try await Task.sleep(nanoseconds: 1_000_000)
                return 42
            }
            """
        } expansion: {
            """
            func modernFunction() async throws -> Int {
                try await Task.sleep(nanoseconds: 1_000_000)
                return 42
            }

            @available(*, unavailable, message: "This completion version is not supported")
            func modernFunctionWithCompletion(completion: @escaping (Result<Int, Error>) -> Void) {
                Task {
                    do {
                        let result = try await modernFunction()
                        completion(Result.success(result))
                    } catch {
                        completion(Result.failure(error))
                    }
                }
            }
            """
        }
    }

    @Test("Expand macro with non-throwing async function")
    func nonThrowing() {
        assertMacro {
            """
            @CompletionBlock
            func simpleAsync() async -> String {
                await Task.sleep(nanoseconds: 1_000_000)
                return "Simple result"
            }
            """
        } expansion: {
            """
            func simpleAsync() async -> String {
                await Task.sleep(nanoseconds: 1_000_000)
                return "Simple result"
            }

            func simpleAsyncWithCompletion(completion: @escaping (Result<String, Error>) -> Void) {
                Task {
                    let result = await simpleAsync()
                    completion(Result.success(result))
                }
            }
            """
        }
    }

    @Test("Error: macro applied to non-function")
    func nonFunction() {
        assertMacro {
            """
            @CompletionBlock
            var someProperty: String = "test"
            """
        } diagnostics: {
            """
            @CompletionBlock
            ┬───────────────
            ╰─ 🛑 @CompletionBlock can only be applied to functions
            var someProperty: String = "test"
            """
        }
    }

    @Test("Error: macro applied to non-async function")
    func nonAsync() {
        assertMacro {
            """
            @CompletionBlock
            func syncFunction() -> String {
                return "sync result"
            }
            """
        } diagnostics: {
            """
            @CompletionBlock
            func syncFunction() -> String {
                 ┬──────────
                 ╰─ 🛑 @CompletionBlock requires the function to be 'async'
                return "sync result"
            }
            """
        }
    }
}

