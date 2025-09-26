//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessCore
import Dispatch
public import Foundation

extension Awaitless {
    // Executes an async closure synchronously with optional timeout.
    //
    // This variant allows you to specify a timeout for the async operation, helping prevent
    // indefinite blocking in synchronous contexts. The timeout is ignored on Linux due to
    // platform stability considerations.
    //
    // ⚠️ **Thread Blocking Warning**: Like the non-timeout version, this function blocks
    // the calling thread using DispatchSemaphore.wait() until completion or timeout.
    //
    // ⚠️ **Platform Limitation**: This function is not available on Linux due to complexity
    // and reliability concerns with timeout implementation on that platform.
    //
    // ## Basic Usage with Timeout
    //
    // ```swift
    // func fetchDataWithTimeout() -> Data? {
    //     do {
    //         let data = try Awaitless.run(timeout: 5.0) {
    //             try await URLSession.shared.data(from: slowEndpoint)
    //         }
    //         return data.0
    //     } catch AwaitlessError.timeout(let duration) {
    //         print("Operation timed out after \(duration) seconds")
    //         return nil
    //     } catch {
    //         print("Operation failed: \(error)")
    //         return nil
    //     }
    // }
    // ```
    //
    // ## Long-Running Operations
    //
    // ```swift
    // func processLargeDataset() -> ProcessingResult? {
    //     do {
    //         let result = try Awaitless.run(timeout: 60.0) {
    //             try await heavyProcessingTask()
    //         }
    //         return result
    //     } catch AwaitlessError.timeout {
    //         print("Processing took too long, cancelling...")
    //         return nil
    //     }
    // }
    // ```
    //
    // ## Network Requests with Fallback
    //
    // ```swift
    // func fetchWithFallback() -> APIResponse {
    //     // Try primary endpoint with short timeout
    //     if let response = try? Awaitless.run(timeout: 2.0) {
    //         try await primaryAPI.fetchData()
    //     } {
    //         return response
    //     }
    //
    //     // Fallback to secondary endpoint with longer timeout
    //     return try! Awaitless.run(timeout: 10.0) {
    //         try await fallbackAPI.fetchData()
    //     }
    // }
    // ```
    //
    // - Parameters:
    //   - timeout: Optional timeout duration in seconds. Ignored on Linux due to stability issues.
    //   - code: The async closure to execute synchronously.
    // - Returns: The result of the async closure.
    // - Throws: The error from the closure, or `AwaitlessError.timeout` if timeout exceeded.
    #if !os(Linux)
        @available(*, noasync, message: "This function blocks threads. Consider using async/await with TaskGroup.withTimeout when possible.")
        public static func run(
            timeout: TimeInterval? = nil,
            _ code: sending () async throws -> Success) throws
            -> Success
        {
            guard let timeout else {
                return try Awaitless<Success, any Error>.run(code)
            }

            // Optional debugging assistance for potentially problematic usage
            #if DEBUG
            if Thread.isMainThread && ProcessInfo.processInfo.environment["AWAITLESS_SUPPRESS_WARNINGS"] == nil {
                print("⚠️ AwaitlessKit: Awaitless.run(timeout:) called from main thread. Ensure async operation won't deadlock.")
            }
            #endif

            let semaphore = DispatchSemaphore(value: 0)
            nonisolated(unsafe) var result: Result<Success, any Error>? = nil

            withoutActuallyEscaping(code) {
                nonisolated(unsafe) let sendableCode = $0

                let coreTask = Task<Void, Never>.detached(priority: .userInitiated) { @Sendable () async in
                    do {
                        let value = try await withTaskCancellationHandler {
                            try await sendableCode()
                        } onCancel: {
                            // Task was cancelled by timeout
                        }
                        result = .success(value)
                    } catch is CancellationError {
                        result = .failure(AwaitlessError.timeout(timeout))
                    } catch {
                        result = .failure(error)
                    }
                }

                Task<Void, Never>.detached(priority: .userInitiated) {
                    await coreTask.value
                    semaphore.signal()
                }

                Task.detached(priority: .utility) { @Sendable () async in
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    coreTask.cancel()
                }

                semaphore.wait()
            }

            return try result!.get()
        }
    #endif
}
