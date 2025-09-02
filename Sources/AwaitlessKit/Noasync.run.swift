//
// Copyright (c) 2025 Daniel Bauke
//

// Copyright Wade Tregaskis
// Source: https://wadetregaskis.com/calling-swift-concurrency-async-code-synchronously-in-swift/

import Dispatch
import AwaitlessCore
import Foundation

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
    { // 1
        let semaphore = DispatchSemaphore(value: 0)

        nonisolated(unsafe) var result: Result<Success, Failure>? = nil // 2

        withoutActuallyEscaping(code) { // 3
            nonisolated(unsafe) let sendableCode = $0 // 4

            let coreTask = Task<Void, Never>.detached(priority: .userInitiated) { @Sendable () async in // 5
                do {
                    result = try await .success(sendableCode())
                } catch {
                    result = .failure(error as! Failure)
                }
            }

            Task<Void, Never>.detached(priority: .userInitiated) { // 6
                await coreTask.value
                semaphore.signal()
            }

            semaphore.wait()
        }

        return try result!.get() // 7
    }
    
    /// Executes an async closure synchronously with optional safety features.
    ///
    /// - Parameters:
    ///   - timeout: Optional timeout duration. If exceeded, throws `NoasyncError.timeout`.
    ///   - enableLogging: Whether to enable debug logging for long waits.
    ///   - code: The async closure to execute synchronously.
    /// - Returns: The result of the async closure.
    /// - Throws: The error from the closure, or `NoasyncError.timeout` if the timeout is exceeded.
    ///
    /// **Warning**: Do not call this from a thread used by Swift Concurrency (e.g. an actor, including global actors
    /// like MainActor) if the closure - or anything it calls transitively via `await` - might be bound to that same
    /// isolation context.  Doing so may result in deadlock.
    @available(*, noasync)
    public static func run(
        timeout: Duration? = nil,
        enableLogging: Bool = false,
        _ code: sending () async throws -> Success
    ) throws -> Success {
        let startTime = ContinuousClock.now
        let semaphore = DispatchSemaphore(value: 0)
        
        nonisolated(unsafe) var result: Result<Success, any Error>? = nil
        nonisolated(unsafe) var coreTask: Task<Success, any Error>? = nil
        
        withoutActuallyEscaping(code) {
            nonisolated(unsafe) let sendableCode = $0
            
            // Core task that executes the user's code
            coreTask = Task<Success, any Error>.detached(priority: .userInitiated) { @Sendable () async throws in
                return try await sendableCode()
            }
            
            // Create a completion task that handles both timeout and normal completion
            Task<Void, Never>.detached(priority: .userInitiated) { @Sendable () async in
                if let timeout = timeout {
                    // Capture the core task in a sendable way
                    let localCoreTask = coreTask!
                    
                    // Track if we timed out
                    nonisolated(unsafe) var timedOut = false
                    
                    // Start timeout task that will cancel the core task after timeout
                    Task {
                        try? await Task.sleep(for: timeout)
                        timedOut = true
                        if enableLogging {
                            print("[Noasync] Operation timed out after \(timeout)")
                        }
                        localCoreTask.cancel()
                    }
                    
                    // Wait for the core task result
                    let coreResult = await localCoreTask.result
                    
                    // If we timed out and the core task failed with cancellation, return timeout error
                    if timedOut, case .failure(let error) = coreResult, error is CancellationError {
                        result = .failure(NoasyncError.timeout(timeout))
                    } else {
                        result = coreResult
                    }
                } else {
                    // No timeout, just wait for completion
                    result = await coreTask!.result
                }
                
                let elapsed = ContinuousClock.now - startTime
                if enableLogging {
                    print("[Noasync] Operation completed in \(elapsed)")
                }
                
                semaphore.signal()
            }
            
            semaphore.wait()
        }
        
        return try result!.get()
    }
}
