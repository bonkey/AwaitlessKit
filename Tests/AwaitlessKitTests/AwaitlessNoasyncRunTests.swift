//
// Copyright (c) 2025 Daniel Bauke
//

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
}
