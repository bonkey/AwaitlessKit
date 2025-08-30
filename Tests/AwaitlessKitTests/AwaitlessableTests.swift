//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["Awaitlessable": AwaitlessableMacro.self], record: .missing))
struct AwaitlessableTests {
    @Test("Expand Awaitlessable on protocol with async methods")
    func protocolWithAsyncMethods() {
        assertMacro {
            """
            @Awaitlessable
            protocol DataService {
                func fetchUser(id: String) async throws -> User
                func fetchData() async -> Data
            }
            """
        } expansion: {
            """
            protocol DataService {
                func fetchUser(id: String) async throws -> User
                func fetchData() async -> Data

                func fetchUser(id: String) throws -> User

                func fetchData() -> Data
            }
            """
        }
    }

    @Test("Expand Awaitlessable on protocol with mixed methods")
    func protocolWithMixedMethods() {
        assertMacro {
            """
            @Awaitlessable
            protocol Service {
                func asyncMethod() async throws -> String
                func syncMethod() -> Int
                var readOnlyProperty: Bool { get }
                var readWriteProperty: [String] { get set }
            }
            """
        } expansion: {
            """
            protocol Service {
                func asyncMethod() async throws -> String
                func syncMethod() -> Int
                var readOnlyProperty: Bool { get }
                var readWriteProperty: [String] { get set }

                func asyncMethod() throws -> String
            }
            """
        }
    }
}
