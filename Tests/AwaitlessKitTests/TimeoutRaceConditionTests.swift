//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessCore
import AwaitlessKit
import Dispatch
import Foundation
import Testing

/// Test suite specifically designed to reproduce and prevent race conditions in timeout version
struct TimeoutRaceConditionTests {
    #if !os(Linux)
        @Test("Stress test - rapid timeout operations to trigger race condition")
        func stressTestTimeoutRaceCondition() throws {
            // This test tries to trigger the race condition by rapidly executing
            // many timeout operations with very short timeouts
            for iteration in 1 ... 500 {
                for timeoutMs in [1, 2, 3, 5, 10] {
                    let timeout = Double(timeoutMs) / 1000.0

                    // Test case 1: Operation that completes just before timeout
                    do {
                        let result = try Noasync<String, any Error>.run(timeout: timeout) {
                            // Sleep for slightly less than timeout
                            try await Task.sleep(nanoseconds: UInt64(timeout * 0.8 * 1_000_000_000))
                            return "Success \(iteration)"
                        }
                        #expect(result == "Success \(iteration)")
                    } catch {
                        // This might timeout or succeed depending on timing
                    }

                    // Test case 2: Operation that will definitely timeout
                    do {
                        _ = try Noasync<String, any Error>.run(timeout: timeout) {
                            // Sleep for much longer than timeout
                            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000 * 1_000_000_000))
                            return "Should timeout"
                        }
                        #expect(Bool(false), "Should have timed out")
                    } catch is NoasyncError {
                        // Expected timeout
                    } catch {
                        throw error
                    }
                }
            }
        }

        @Test("Sequential timeout operations from multiple threads")
        func multiThreadedTimeoutOperations() throws {
            let queue = DispatchQueue(label: "test.queue", attributes: .concurrent)
            let group = DispatchGroup()

            for i in 0 ..< 20 {
                group.enter()
                queue.async {
                    defer { group.leave() }
                    do {
                        _ = try Noasync<Int, any Error>.run(timeout: 0.001) {
                            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                            return i
                        }
                    } catch {
                        // Ignore errors for this stress test
                    }
                }
            }

            group.wait()
        }

        @Test("Rapid sequential timeouts with varying durations")
        func rapidSequentialTimeouts() throws {
            // Rapidly switch between different timeout scenarios
            for _ in 0 ..< 50 {
                // Very short timeout that should fail
                do {
                    _ = try Noasync<String, any Error>.run(timeout: 0.0001) {
                        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                        return "timeout"
                    }
                } catch is NoasyncError {
                    // Expected
                } catch {
                    throw error
                }

                // Normal timeout that should succeed
                let result = try Noasync<String, any Error>.run(timeout: 0.1) {
                    try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                    return "success"
                }
                #expect(result == "success")

                // Edge case: zero sleep
                let instant = try Noasync<String, any Error>.run(timeout: 0.01) {
                    "instant"
                }
                #expect(instant == "instant")
            }
        }

        @Test("Task cancellation at exact timeout boundary")
        func timeoutBoundaryRaceCondition() throws {
            // Try to hit the exact moment where timeout and completion race
            for i in 1 ... 100 {
                let sleepNanos = UInt64(i * 100_000) // Gradually increase from 0.1ms to 10ms
                let timeoutSeconds = Double(sleepNanos) / 1_000_000_000

                do {
                    _ = try Noasync<String, any Error>.run(timeout: timeoutSeconds) {
                        try await Task.sleep(nanoseconds: sleepNanos)
                        return "completed"
                    }
                } catch {
                    // Either timeout or success is acceptable
                    // We're trying to trigger the race condition crash
                }
            }
        }

        @Test("Heavy task with immediate cancellation")
        func heavyTaskImmediateCancellation() throws {
            // Create a task that does significant work to increase retain count pressure
            for _ in 0 ..< 20 {
                do {
                    _ = try Noasync<[String], any Error>.run(timeout: 0.00001) { // 10 microseconds
                        var results: [String] = []
                        for j in 0 ..< 100 {
                            results.append("Item \(j)")
                            try await Task.sleep(nanoseconds: 100) // Very short sleep
                        }
                        return results
                    }
                } catch is NoasyncError {
                    // Expected timeout
                } catch {
                    throw error
                }
            }
        }

        @Test("Multiple nested closures with timeout")
        func nestedClosuresTimeout() throws {
            // Complex closure structure to stress reference counting
            for _ in 0 ..< 10 {
                do {
                    _ = try Noasync<String, any Error>.run(timeout: 0.001) {
                        let closure1 = { @Sendable () async throws -> String in
                            try await Task.sleep(nanoseconds: 500_000)
                            return "level1"
                        }

                        let closure2 = { @Sendable () async throws -> String in
                            let result = try await closure1()
                            return "level2: \(result)"
                        }

                        return try await closure2()
                    }
                } catch is NoasyncError {
                    // Expected
                } catch {
                    throw error
                }
            }
        }

        @Test("Timeout with throwing operations at different stages")
        func throwingOperationsAtDifferentStages() throws {
            enum TestError: Error {
                case beforeSleep
                case afterSleep
            }

            // Test throwing before any async work
            do {
                _ = try Noasync<String, any Error>.run(timeout: 0.1) {
                    throw TestError.beforeSleep
                }
                #expect(Bool(false), "Should have thrown")
            } catch TestError.beforeSleep {
                // Expected
            } catch {
                throw error
            }

            // Test throwing after some async work
            do {
                _ = try Noasync<String, any Error>.run(timeout: 0.1) {
                    try await Task.sleep(nanoseconds: 1_000_000)
                    throw TestError.afterSleep
                }
                #expect(Bool(false), "Should have thrown")
            } catch TestError.afterSleep {
                // Expected
            } catch {
                throw error
            }

            // Test timeout while processing error
            do {
                _ = try Noasync<String, any Error>.run(timeout: 0.0001) {
                    try await Task.sleep(nanoseconds: 10_000_000)
                    throw TestError.afterSleep
                }
                #expect(Bool(false), "Should have timed out")
            } catch is NoasyncError {
                // Expected timeout
            } catch {
                throw error
            }
        }

        @Test("Timeout API availability check")
        func timeoutAPIAvailability() throws {
            // Verify that timeout API works as expected
            let result = try Noasync<String, any Error>.run(timeout: 0.1) {
                "Available"
            }
            #expect(result == "Available")

            // Test timeout actually works
            do {
                _ = try Noasync<String, any Error>.run(timeout: 0.001) {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    return "Should timeout"
                }
                #expect(Bool(false), "Should have timed out")
            } catch let NoasyncError.timeout(duration) {
                #expect(duration == 0.001)
            } catch {
                throw error
            }
        }
    #endif

    @Test("Non-timeout version always works on all platforms")
    func nonTimeoutAlwaysWorks() throws {
        // This test should work on all platforms including Linux
        let result = try Noasync.run {
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            return "Cross-platform success"
        }
        #expect(result == "Cross-platform success")

        // Test with error handling
        enum TestError: Error {
            case testCase
        }

        do {
            _ = try Noasync.run {
                throw TestError.testCase
            }
            #expect(Bool(false), "Should have thrown")
        } catch TestError.testCase {
            // Expected
        } catch {
            throw error
        }
    }

    #if os(Linux)
        @Test("Linux platform timeout API is unavailable")
        func linuxTimeoutUnavailable() {
            // On Linux, the timeout API should not be available
            // This is a compile-time check - if this compiles, the API is properly hidden

            let result = try! Noasync.run {
                "Linux works without timeout"
            }
            #expect(result == "Linux works without timeout")

            // Note: We cannot test Noasync.run(timeout:_:) here because it should not compile on Linux
        }
    #endif
}
