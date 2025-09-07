//
// Copyright (c) 2025 Daniel Bauke
//

// Copyright Wade Tregaskis
// Source: https://wadetregaskis.com/calling-swift-concurrency-async-code-synchronously-in-swift/

import AwaitlessCore
import Dispatch
public import Foundation

extension Noasync {
    // Executes the given async closure synchronously, waiting for it to finish before returning.
    //
    // **Warning**: Do not call this from a thread used by Swift Concurrency (e.g. an actor, including global actors
    // like MainActor) if the closure - or anything it calls transitively via `await` - might be bound to that same
    // isolation context.  Doing so may result in deadlock.

    /// Executes an async closure synchronously; uses Swift 6 "sending" closure semantics.
    ///
    /// This is the foundational function that enables calling async code from synchronous contexts.
    /// All AwaitlessKit macros use this function internally to provide their synchronous wrappers.
    ///
    /// ## Basic Example
    ///
    /// ```swift
    /// // Call async function from sync context
    /// func syncFunction() -> String {
    ///     let result = Noasync.run {
    ///         try await URLSession.shared.data(from: url)
    ///     }
    ///     return String(data: result.0, encoding: .utf8) ?? ""
    /// }
    /// ```
    ///
    /// ## Error Handling
    ///
    /// ```swift
    /// func fetchUserData() -> User? {
    ///     do {
    ///         let user = try Noasync.run {
    ///             try await apiService.fetchUser(id: "123")
    ///         }
    ///         return user
    ///     } catch {
    ///         print("Failed to fetch user: \(error)")
    ///         return nil
    ///     }
    /// }
    /// ```
    ///
    /// ## Multiple Async Operations
    ///
    /// ```swift
    /// func loadDashboardData() -> DashboardData {
    ///     return Noasync.run {
    ///         async let users = fetchUsers()
    ///         async let posts = fetchPosts()
    ///         async let notifications = fetchNotifications()
    ///
    ///         return try await DashboardData(
    ///             users: users,
    ///             posts: posts,
    ///             notifications: notifications
    ///         )
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter code: The async closure to execute synchronously
    /// - Returns: The result of the async closure
    /// - Throws: Any error thrown by the async closure
    @available(*, noasync)
    public static func run(_ code: sending () async throws(Failure) -> Success) throws(Failure)
        -> Success
    {
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var result: Result<Success, Failure>? = nil

        withoutActuallyEscaping(code) {
            nonisolated(unsafe) let sendableCode = $0

            let coreTask = Task<Void, Never>.detached(priority: .userInitiated) { @Sendable () async in
                do {
                    result = try await .success(sendableCode())
                } catch {
                    result = .failure(error as! Failure)
                }
            }

            Task<Void, Never>.detached(priority: .userInitiated) {
                await coreTask.value
                semaphore.signal()
            }

            semaphore.wait()
        }

        return try result!.get()
    }

    // Executes an async closure synchronously with optional timeout.
    //
    // This variant allows you to specify a timeout for the async operation, helping prevent
    // indefinite blocking in synchronous contexts. The timeout is ignored on Linux due to
    // platform stability considerations.
    //
    // ## Basic Usage with Timeout
    //
    // ```swift
    // func fetchDataWithTimeout() -> Data? {
    //     do {
    //         let data = try Noasync.run(timeout: 5.0) {
    //             try await URLSession.shared.data(from: slowEndpoint)
    //         }
    //         return data.0
    //     } catch NoasyncError.timeout(let duration) {
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
    //         let result = try Noasync.run(timeout: 60.0) {
    //             try await heavyProcessingTask()
    //         }
    //         return result
    //     } catch NoasyncError.timeout {
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
    //     if let response = try? Noasync.run(timeout: 2.0) {
    //         try await primaryAPI.fetchData()
    //     } {
    //         return response
    //     }
    //
    //     // Fallback to secondary endpoint with longer timeout
    //     return try! Noasync.run(timeout: 10.0) {
    //         try await fallbackAPI.fetchData()
    //     }
    // }
    // ```
    //
    // - Parameters:
    //   - timeout: Optional timeout duration in seconds. Ignored on Linux due to stability issues.
    //   - code: The async closure to execute synchronously.
    // - Returns: The result of the async closure.
    // - Throws: The error from the closure, or `NoasyncError.timeout` if timeout exceeded.
    #if !os(Linux)
        @available(*, noasync)
        public static func run(
            timeout: TimeInterval? = nil,
            _ code: sending () async throws -> Success) throws
            -> Success
        {
            guard let timeout else {
                return try Noasync<Success, any Error>.run(code)
            }

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
                        result = .failure(NoasyncError.timeout(timeout))
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
