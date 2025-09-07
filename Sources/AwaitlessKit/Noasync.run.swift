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

    /// Executes an async closure synchronously with optional timeout.
    ///
    /// - Parameters:
    ///   - timeout: Optional timeout duration in seconds. Ignored on Linux due to stability issues.
    ///   - code: The async closure to execute synchronously.
    /// - Returns: The result of the async closure.
    /// - Throws: The error from the closure, or `NoasyncError.timeout` if timeout exceeded.
    @available(*, noasync)
    public static func run(
        timeout: TimeInterval? = nil,
        _ code: sending () async throws -> Success) throws
        -> Success
    {
        #if os(Linux)
            // Timeout disabled on Linux for stability
            return try Noasync<Success, any Error>.run(code)
        #else
            guard let timeout else {
                return try Noasync<Success, any Error>.run(code)
            }

            let semaphore = DispatchSemaphore(value: 0)
            nonisolated(unsafe) var result: Result<Success, any Error>? = nil

            withoutActuallyEscaping(code) {
                nonisolated(unsafe) let sendableCode = $0

                let task = Task<Void, Never>.detached(priority: .userInitiated) { @Sendable () async in
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
                    semaphore.signal()
                }

                Task.detached(priority: .utility) { @Sendable () async in
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    task.cancel()
                }

                semaphore.wait()
            }

            return try result!.get()
        #endif
    }
}
