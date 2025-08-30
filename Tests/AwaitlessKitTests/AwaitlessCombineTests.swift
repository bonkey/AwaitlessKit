//
// Copyright (c) 2025 Daniel Bauke
//

#if canImport(Combine)
@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["Awaitless": AwaitlessAttachedMacro.self], record: .missing))
struct AwaitlessCombineTests {
    @Test("Expand macro with publisher output")
    func publisherOutput() {
        assertMacro {
            """
            @Awaitless(as: .publisher)
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

            func fetchData() -> AnyPublisher<[String], Error> {
                Future.init({ promise in
                        Task() {
                            do {
                                let result = try await self.fetchData()
                                promise(.success(result))
                            } catch {
                                promise(.failure(error))
                            }
                        }
                    }).eraseToAnyPublisher()
            }
            """
        }
    }

    @Test("Expand macro with publisher output for non-throwing function")
    func publisherOutputNonThrowing() {
        assertMacro {
            """
            @Awaitless(as: .publisher)
            func fetchData() async -> [String] {
                await Task.sleep(nanoseconds: 1_000_000_000)
                return ["Hello", "World"]
            }
            """
        } expansion: {
            """
            func fetchData() async -> [String] {
                await Task.sleep(nanoseconds: 1_000_000_000)
                return ["Hello", "World"]
            }

            func fetchData() -> AnyPublisher<[String], Never> {
                Future.init({ promise in
                        Task() {
                            let result = await self.fetchData()
                            promise(.success(result))
                        }
                    }).eraseToAnyPublisher()
            }
            """
        }
    }

    @Test("Expand macro with publisher output and prefix")
    func publisherWithPrefix() {
        assertMacro {
            """
            @Awaitless(prefix: "publisher_", as: .publisher)
            func fetchData() async throws -> [String] {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return ["Hello", "World"]
            }
            """
        } expansion: {
            """
            func fetchData() async throws -> [String] {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return ["Hello", "World"]
            }

            func publisher_fetchData() -> AnyPublisher<[String], Error> {
                Future.init({ promise in
                        Task() {
                            do {
                                let result = try await self.fetchData()
                                promise(.success(result))
                            } catch {
                                promise(.failure(error))
                            }
                        }
                    }).eraseToAnyPublisher()
            }
            """
        }
    }
}
#endif
