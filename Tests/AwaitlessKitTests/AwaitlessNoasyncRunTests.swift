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
        let result = try Noasync.run {
            try await Task.sleep(nanoseconds: 100_000_000)
            return "Success"
        }

        #expect(result == "Success")
    }

    @Test("Handle different return types")
    func differentReturnTypes() throws {
        let intResult = try Noasync.run {
            try await Task.sleep(nanoseconds: 10_000_000)
            return 42
        }
        #expect(intResult == 42)

        struct TestData {
            let value: String
        }

        let structResult = try Noasync.run {
            try await Task.sleep(nanoseconds: 10_000_000)
            return TestData(value: "test")
        }
        #expect(structResult.value == "test")
    }

    @Test("Execute void-returning async operation")
    func voidReturn() throws {
        try Noasync.run {
            try await Task.sleep(nanoseconds: 10_000_000)
            #expect(Bool(true))
        }

        #expect(Bool(true))
    }

    @Test("Propagate errors correctly")
    func errorPropagation() throws {
        #expect(throws: TestError.simpleError) {
            try Noasync.run {
                throw TestError.simpleError
            }
        }
    }

    @Test("Catch errors from nested async calls")
    func nestedErrors() throws {
        do {
            try Noasync.run {
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
            let result = try Noasync.run {
                try await Task.sleep(for: .microseconds(Int.random(in: 10 ... 5000)))
                return i
            }
            results.append(result)
        }

        let expectedResults = Array(0 ..< count)

        #expect(results == expectedResults)
    }

    // MARK: - Safety Features Tests

    @Test("Execute with timeout - success case")
    func timeoutSuccess() throws {
        let result: String = try Noasync<String, any Error>.run(timeout: .milliseconds(100)) {
            try await Task.sleep(for: .milliseconds(10))
            return "Success"
        }

        #expect(result == "Success")
    }

    @Test("Execute with timeout - timeout case", .enabled(if: !isLinux))
    func timeoutFailure() throws {
        #expect(throws: NoasyncError.timeout(.milliseconds(50))) {
            try Noasync<String, any Error>.run(timeout: .milliseconds(50)) {
                try await Task.sleep(for: .milliseconds(200))
                return "Should not reach here"
            }
        }
    }

    @Test("Execute with timeout disabled (nil)")
    func timeoutDisabled() throws {
        let result: String = try Noasync<String, any Error>.run(timeout: nil) {
            try await Task.sleep(for: .milliseconds(10))
            return "Success"
        }

        #expect(result == "Success")
    }

    @Test("Timeout with void return type")
    func timeoutVoidReturn() throws {
        try Noasync<Void, any Error>.run(timeout: .milliseconds(100)) {
            try await Task.sleep(for: .milliseconds(10))
            #expect(Bool(true))
        }
    }

    @Test("Timeout with error propagation")
    func timeoutErrorPropagation() throws {
        #expect(throws: TestError.simpleError) {
            try Noasync<String, any Error>.run(timeout: .milliseconds(100)) {
                try await Task.sleep(for: .milliseconds(10))
                throw TestError.simpleError
            }
        }
    }

    @Test("Multiple timeout operations in sequence")
    func multipleTimeoutOperations() throws {
        for i in 0 ..< 10 {
            let result: Int = try Noasync<Int, any Error>.run(timeout: .milliseconds(50)) {
                try await Task.sleep(for: .milliseconds(5))
                return i
            }
            #expect(result == i)
        }
    }

    @Test("Very short timeout", .enabled(if: !isLinux))
    func veryShortTimeout() throws {
        #expect(throws: NoasyncError.timeout(.milliseconds(1))) {
            try Noasync<String, any Error>.run(timeout: .milliseconds(1)) {
                try await Task.sleep(for: .milliseconds(100))
                return "Should not reach here"
            }
        }
    }

    @Test("Different return types with timeout")
    func differentReturnTypesWithTimeout() throws {
        let intResult: Int = try Noasync<Int, any Error>.run(timeout: .milliseconds(100)) {
            try await Task.sleep(for: .milliseconds(10))
            return 42
        }
        #expect(intResult == 42)

        struct TestData {
            let value: String
        }

        let structResult: TestData = try Noasync<TestData, any Error>.run(timeout: .milliseconds(100)) {
            try await Task.sleep(for: .milliseconds(10))
            return TestData(value: "test")
        }
        #expect(structResult.value == "test")
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
