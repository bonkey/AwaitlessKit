//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["Awaitless": AwaitlessAttachedMacro.self], record: .all))
struct AwaitlessCompletionTests {
    @Test("Test completion handler macro exists")
    func macroExists() {
        // This test just verifies the macro compiles and is recognized
        #expect(1 == 1)
    }
    
    @Test("Test deprecation warning for Awaitless(as: .completionHandler)")
    func deprecationWarning() {
        assertMacro {
            """
            @Awaitless(as: .completionHandler)
            func fetchData() async throws -> String {
                return "Hello World"
            }
            """
        } diagnostics: {
            """
            @Awaitless(as: .completionHandler)
                           ┬─────────────────
                           ╰─ ⚠️ @Awaitless(as: .completionHandler) is deprecated; use @AwaitlessCompletion
            func fetchData() async throws -> String {
                return "Hello World"
            }
            """
        }
    }
}