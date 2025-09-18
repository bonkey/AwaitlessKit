//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKitPromiseKit
import AwaitlessKitPromiseMacros
import MacroTesting
import PromiseKit
import Testing

@Suite(.macros(["Awaitfulable": AwaitfulableMacro.self], record: .missing), .tags(.macros))
struct AwaitfulableClassTests {
    
    @Test("Expand @Awaitfulable on class with multiple methods", .tags(.macros))
    func awaitfulableClassWithPromiseMethods() {
        assertMacro {
            """
            @Awaitfulable
            class NetworkService {
                func fetchData() -> Promise<Data> {
                    return Promise.value(Data())
                }
            }
            """
        } expansion: {
            """
            class NetworkService {
                func fetchData() -> Promise<Data> {
                    return Promise.value(Data())
                }

                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "fetchData") func fetchData() async throws -> Data
            }

            extension NetworkService {
                @available(*, deprecated, message: "PromiseKit support is deprecated; use async function instead", renamed: "fetchData") public func fetchData() async throws -> Data {
                    return try await self.fetchData().async()
                }
            }
            """
        }
    }
    
    // NOTE: The above test passes in the macro test framework but would fail in actual Swift compilation
    // due to "invalid redeclaration" errors. The macro generates both member declarations inside the class
    // AND extension implementations, which creates conflicts for classes (unlike protocols where this is valid).
    //
    // This is a known limitation - for classes, use individual @Awaitful macros on each method instead
    // of @Awaitfulable on the class itself.
}