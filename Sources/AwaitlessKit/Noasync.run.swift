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
    ///   - timeout: Optional timeout duration. **Currently disabled on Linux due to stability issues.**
    ///   - enableLogging: Whether to enable debug logging for long waits.
    ///   - code: The async closure to execute synchronously.
    /// - Returns: The result of the async closure.
    /// - Throws: The error from the closure, or `NoasyncError.timeout` if timeout exceeded.
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
        
        #if os(Linux)
        // Disable timeout on Linux due to SIGILL crashes with Swift 6 concurrency
        let result = try Noasync<Success, any Error>.run(code)
        
        if let timeout = timeout {
            print("[Noasync] Warning: Timeout functionality is currently disabled due to Linux compatibility issues.")
        }
        #else
        // Enable timeout functionality on non-Linux platforms
        let result: Success
        if let timeout = timeout {
            result = try runWithTimeout(timeout: timeout, code: code)
        } else {
            result = try Noasync<Success, any Error>.run(code)
        }
        #endif
        
        let elapsed = ContinuousClock.now - startTime
        if enableLogging {
            print("[Noasync] Operation completed in \(elapsed)")
        }
        
        return result
    }
    
    #if !os(Linux)
    /// Helper function to run with timeout on non-Linux platforms
    @available(*, noasync)
    private static func runWithTimeout<Success>(
        timeout: Duration,
        code: sending () async throws -> Success
    ) throws -> Success {
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var result: Result<Success, any Error>? = nil
        nonisolated(unsafe) var timedOut = false
        
        withoutActuallyEscaping(code) {
            nonisolated(unsafe) let sendableCode = $0
            
            let coreTask = Task<Void, Never>.detached(priority: .userInitiated) { @Sendable () async in
                do {
                    let value = try await sendableCode()
                    result = .success(value)
                } catch {
                    result = .failure(error)
                }
                semaphore.signal()
            }
            
            // Set up timeout using DispatchQueue
            DispatchQueue.global().asyncAfter(deadline: .now() + .nanoseconds(Int(timeout.components.seconds * 1_000_000_000) + timeout.components.attoseconds / 1_000_000_000)) {
                timedOut = true
                coreTask.cancel()
                semaphore.signal()
            }
            
            semaphore.wait()
        }
        
        if timedOut {
            throw NoasyncError.timeout(timeout)
        }
        
        return try result!.get()
    }
    #endif
}
