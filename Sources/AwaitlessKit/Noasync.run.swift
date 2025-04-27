//
// Copyright (c) 2025 Daniel Bauke
//

// Copyright Wade Tregaskis
// Source: https://wadetregaskis.com/calling-swift-concurrency-async-code-synchronously-in-swift/

import Dispatch

extension Noasync {
    // Executes the given async closure synchronously, waiting for it to finish before returning.
    //
    // **Warning**: Do not call this from a thread used by Swift Concurrency (e.g. an actor, including global actors
    // like MainActor) if the closure - or anything it calls transitively via `await` - might be bound to that same
    // isolation context.  Doing so may result in deadlock.

    #if compiler(>=6.0)
        /// only Swift 6.0 support "sending"
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
    #else
        @available(*, noasync)
        public static func run(_ code: @escaping () async throws -> Success) throws -> Success {
            let semaphore = DispatchSemaphore(value: 0)

            nonisolated(unsafe) var result: Result<Success, Error>? = nil

            withoutActuallyEscaping(code) { escapableCode in
                // Create a detached task to run the async code
                let coreTask = Task<Void, Never>.detached(priority: .userInitiated) {
                    do {
                        result = try await .success(escapableCode())
                    } catch {
                        result = .failure(error)
                    }
                }

                // Create another task to wait for the completion and signal the semaphore
                Task<Void, Never>.detached(priority: .userInitiated) {
                    await coreTask.value
                    semaphore.signal()
                }

                semaphore.wait()
            }

            do {
                return try result!.get()
            } catch let error as Failure {
                throw error
            } catch {
                // In Swift 5.x we can't constrain the thrown error type in the function signature
                // This fallback should never happen if used correctly
                fatalError("Unexpected error type: \(type(of: error))")
            }
        }
    #endif
}
