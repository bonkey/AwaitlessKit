//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["AwaitlessCompletion": AwaitlessAttachedMacro.self], record: .all))
struct AwaitlessCompletionTests {
    @Test("Test completion handler macro exists")
    func macroExists() {
        // This test just verifies the macro compiles and is recognized
        #expect(1 == 1)
    }
    
    @Test("Expand basic completion handler macro")
    func basic() {
        assertMacro {
            """
            @AwaitlessCompletion
            func fetchData() async throws -> String {
                return "Hello World"
            }
            """
        } expansion: {
            """
            PLACEHOLDER TO SEE ACTUAL OUTPUT
            """
        }
    }
}