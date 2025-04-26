//
// Copyright (c) 2025 Daniel Bauke
//

// Copyright Wade Tregaskis
// Source: https://wadetregaskis.com/calling-swift-concurrency-async-code-synchronously-in-swift/

import Dispatch

extension Task {
    /// Executes the given async closure synchronously, waiting for it to finish before returning.
    ///
    /// **Warning**: Do not call this from a thread used by Swift Concurrency (e.g. an actor, including global actors
    /// like MainActor) if the closure - or anything it calls transitively via `await` - might be bound to that same
    /// isolation context.  Doing so may result in deadlock.
    
    #if compiler(>=6.0)
    @available(*, noasync)
    public static func noasync(_ code: sending () async throws(Failure) -> Success) throws(Failure) -> Success { // 1
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
    #else
    @available(*, noasync)
    public static func noasync(_ code: @Sendable () async throws(Failure) -> Success) throws(Failure) -> Success { // 1
        let semaphore = DispatchSemaphore(value: 0)

        nonisolated(unsafe) var result: Result<Success, Failure>? = nil // 2

        withoutActuallyEscaping(code) { // 3
            let sendableCode = $0 // removed nonisolated(unsafe) for compatibility with @Sendable

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
    #endif

}
