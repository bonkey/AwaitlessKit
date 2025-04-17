//
// Copyright (c) 2025 Daniel Bauke
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations are required for testing macros.
#if canImport(NoAsyncMacros)
    import NoAsyncMacros

    let testMacros: [String: Macro.Type] = [
        "noasync": NoAsyncMacro.self,
    ]
#endif

// MARK: - NoAsyncMacroTests

final class NoAsyncMacroTests: XCTestCase {
    func testNoAsyncBasic() throws {
        #if canImport(NoAsyncMacros)
            assertMacroExpansion(
                """
                @noasync
                func testAsync() async -> Int {
                    42
                }
                """,
                expandedSource: """
                func testAsync() async -> Int {
                    42
                }

                func noasyncTestAsync() -> Int {
                    Task.noasync {
                        await testAsync()
                    }
                }
                """,
                macros: testMacros)
        #else
            throw XCTSkip("Macros are only supported when running tests for the host platform.")
        #endif
    }

    func testNoAsyncThrows() throws {
        #if canImport(NoAsyncMacros)
            assertMacroExpansion(
                """
                @noasync
                public func testThrows() async throws -> String {
                    throw NSError(domain: "", code: 0)
                }
                """,
                expandedSource: """
                public func testThrows() async throws -> String {
                    throw NSError(domain: "", code: 0)
                }

                public func noasyncTestThrows() throws -> String {
                    try Task.noasync {
                        await testThrows()
                    }
                }
                """,
                macros: testMacros)
        #else
            throw XCTSkip("Macros are only supported when running tests for the host platform.")
        #endif
    }

    func testNoAsyncVoidReturn() throws {
        #if canImport(NoAsyncMacros)
            assertMacroExpansion(
                """
                @noasync
                func testVoid() async {
                    print("done")
                }
                """,
                expandedSource: """
                func testVoid() async {
                    print("done")
                }

                func noasyncTestVoid() {
                    Task.noasync {
                        await testVoid()
                    }
                }
                """,
                macros: testMacros)
        #else
            throw XCTSkip("Macros are only supported when running tests for the host platform.")
        #endif
    }

    func testNoAsyncWithArgs() throws {
        #if canImport(NoAsyncMacros)
            assertMacroExpansion(
                """
                @noasync
                func testArgs(value: Int, label name: String, _ unnamed: Double) async -> Bool {
                    true
                }
                """,
                expandedSource: """
                func testArgs(value: Int, label name: String, _ unnamed: Double) async -> Bool {
                    true
                }

                func noasyncTestArgs(value: Int, label name: String, _ unnamed: Double) -> Bool {
                    Task.noasync {
                        await testArgs(value: value, label: name, unnamed)
                    }
                }
                """,
                macros: testMacros)
        #else
            throw XCTSkip("Macros are only supported when running tests for the host platform.")
        #endif
    }

    func testErrorNotAsync() throws {
        #if canImport(NoAsyncMacros)
            assertMacroExpansion(
                """
                @noasync
                func testSync() -> Int { 42 }
                """,
                expandedSource: """
                func testSync() -> Int { 42 }
                """,
                diagnostics: [
                    DiagnosticSpec(message: "@noasync requires the function to be 'async'", line: 1, column: 1),
                ],
                macros: testMacros)
        #else
            throw XCTSkip("Macros are only supported when running tests for the host platform.")
        #endif
    }

    func testErrorNotFunction() throws {
        #if canImport(NoAsyncMacros)
            assertMacroExpansion(
                """
                @noasync
                struct TestStruct {}
                """,
                expandedSource: """
                struct TestStruct {}
                """,
                diagnostics: [
                    DiagnosticSpec(message: "@noasync can only be applied to functions", line: 1, column: 1),
                ],
                macros: testMacros)
        #else
            throw XCTSkip("Macros are only supported when running tests for the host platform.")
        #endif
    }
}
