//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessCore
import AwaitlessKit
import Dispatch
import Foundation
import Testing

struct AwaitlessNoasyncRunTests {
    enum TestError: Error, Equatable {
        case simpleError
    }

    @Test("Execute basic async operation synchronously")
    func basicExecution() throws {
        let result = try Awaitless.run {
            try await Task.sleep(nanoseconds: 100_000_000)
            return "Success"
        }

        #expect(result == "Success")
    }

    @Test("Handle different return types")
    func differentReturnTypes() throws {
        let intResult = try Awaitless.run {
            try await Task.sleep(nanoseconds: 10_000_000)
            return 42
        }
        #expect(intResult == 42)

        struct TestData {
            let value: String
        }

        let structResult = try Awaitless.run {
            try await Task.sleep(nanoseconds: 10_000_000)
            return TestData(value: "test")
        }
        #expect(structResult.value == "test")
    }

    @Test("Execute void-returning async operation")
    func voidReturn() throws {
        try Awaitless.run {
            try await Task.sleep(nanoseconds: 10_000_000)
            #expect(Bool(true))
        }

        #expect(Bool(true))
    }

    @Test("Propagate errors correctly")
    func errorPropagation() throws {
        #expect(throws: TestError.simpleError) {
            try Awaitless.run {
                throw TestError.simpleError
            }
        }
    }

    @Test("Catch errors from nested async calls")
    func nestedErrors() throws {
        do {
            try Awaitless.run {
                try await Task.sleep(nanoseconds: 10_000_000)
                throw TestError.simpleError
            }
        } catch {
            #expect(error is TestError)
        }
    }

    @Test("Execute 1000 tasks and verify sequential output")
    func multipleTasksSequentialOutput() throws {
        let count = 1000
        var results: [Int] = []

        for i in 0 ..< count {
            let result = try Awaitless.run {
                try await Task.sleep(for: .microseconds(Int.random(in: 10 ... 5000)))
                return i
            }
            results.append(result)
        }

        let expectedResults = Array(0 ..< count)

        #expect(results == expectedResults)
    }

    // MARK: - Safety Features Tests

    @Test("Execute with timeout - success case", .enabled(if: !isLinux))
    func timeoutSuccess() throws {
        #if !os(Linux)
            let result: String = try Awaitless<String, any Error>.run(timeout: 0.1) {
                try await Task.sleep(for: .milliseconds(10))
                return "Success"
            }

            #expect(result == "Success")
        #endif
    }

    @Test("Execute with timeout - timeout case", .enabled(if: !isLinux))
    func timeoutFailure() throws {
        #if !os(Linux)
            #expect(throws: AwaitlessError.timeout(0.05)) {
                try Awaitless<String, any Error>.run(timeout: 0.05) {
                    try await Task.sleep(for: .milliseconds(200))
                    return "Should not reach here"
                }
            }
        #endif
    }

    @Test("Execute with timeout disabled (nil)", .enabled(if: !isLinux))
    func timeoutDisabled() throws {
        #if !os(Linux)
            let result: String = try Awaitless<String, any Error>.run(timeout: nil) {
                try await Task.sleep(for: .milliseconds(10))
                return "Success"
            }

            #expect(result == "Success")
        #endif
    }

    @Test("Timeout with void return type", .enabled(if: !isLinux))
    func timeoutVoidReturn() throws {
        #if !os(Linux)
            try Awaitless<Void, any Error>.run(timeout: 0.1) {
                try await Task.sleep(for: .milliseconds(10))
                #expect(Bool(true))
            }
        #endif
    }

    @Test("Timeout with error propagation", .enabled(if: !isLinux))
    func timeoutErrorPropagation() throws {
        #if !os(Linux)
            #expect(throws: TestError.simpleError) {
                try Awaitless<String, any Error>.run(timeout: 0.1) {
                    try await Task.sleep(for: .milliseconds(10))
                    throw TestError.simpleError
                }
            }
        #endif
    }

    @Test("Multiple timeout operations in sequence", .enabled(if: !isLinux))
    func multipleTimeoutOperations() throws {
        #if !os(Linux)
            for i in 0 ..< 10 {
                let result: Int = try Awaitless<Int, any Error>.run(timeout: 0.05) {
                    try await Task.sleep(for: .milliseconds(5))
                    return i
                }
                #expect(result == i)
            }
        #endif
    }

    @Test("Very short timeout", .enabled(if: !isLinux))
    func veryShortTimeout() throws {
        #if !os(Linux)
            #expect(throws: AwaitlessError.timeout(0.001)) {
                try Awaitless<String, any Error>.run(timeout: 0.001) {
                    try await Task.sleep(for: .milliseconds(100))
                    return "Should not reach here"
                }
            }
        #endif
    }

    @Test("Different return types with timeout", .enabled(if: !isLinux))
    func differentReturnTypesWithTimeout() throws {
        #if !os(Linux)
            let intResult: Int = try Awaitless<Int, any Error>.run(timeout: 0.1) {
                try await Task.sleep(for: .milliseconds(10))
                return 42
            }
            #expect(intResult == 42)

            struct TestData {
                let value: String
            }

            let structResult: TestData = try Awaitless<TestData, any Error>.run(timeout: 0.1) {
                try await Task.sleep(for: .milliseconds(10))
                return TestData(value: "test")
            }
            #expect(structResult.value == "test")
        #endif
    }

    /// Platform detection for conditional testing
    private static let isLinux: Bool = {
        #if os(Linux)
            return true
        #else
            return false
        #endif
    }()
}
