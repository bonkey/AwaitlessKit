//
// Copyright (c) 2025 Daniel Bauke
//

// Copyright Wade Tregaskis
// Source: https://wadetregaskis.com/calling-swift-concurrency-async-code-synchronously-in-swift/

import AwaitlessCore
import Dispatch
import Foundation

extension Awaitless {
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
    /// ## ⚠️ Important Performance and Threading Considerations
    ///
    /// **Thread Blocking Behavior**: This function **blocks the calling thread** using `DispatchSemaphore.wait()`
    /// until the async operation completes. This is a fundamental requirement for bridging sync-to-async contexts.
    ///
    /// **When to Avoid**: Consider using async/await directly instead of this function when:
    /// - You're already in an async context (use `await` directly)
    /// - Building new code (prefer async/await from the start)
    /// - Working in high-concurrency scenarios where thread blocking impacts performance
    ///
    /// **Deadlock Prevention**: Never call this function from:
    /// - Actor methods where the async operation might run on the same actor
    /// - `@MainActor` contexts where the async operation might also be `@MainActor`
    /// - Any context where the async operation might be bound to the same isolation domain
    ///
    /// **Best Practices**:
    /// - Use this primarily for migrating legacy synchronous code to work with modern async APIs
    /// - Prefer async/await patterns when building new applications
    /// - Consider the performance impact in high-throughput scenarios
    ///
    /// ## Basic Example
    ///
    /// ```swift
    /// // Call async function from sync context
    /// func syncFunction() -> String {
    ///     let result = Awaitless.run {
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
    ///         let user = try Awaitless.run {
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
    ///     return Awaitless.run {
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
    @available(*, noasync, message: "This function blocks threads. Consider using async/await directly when possible.")
    public static func run(_ code: sending () async throws(Failure) -> Success) throws(Failure)
        -> Success
    {
        // Optional debugging assistance for potentially problematic usage
        #if DEBUG
        if Thread.isMainThread && ProcessInfo.processInfo.environment["AWAITLESS_SUPPRESS_WARNINGS"] == nil {
            print("⚠️ AwaitlessKit: Awaitless.run called from main thread. Ensure async operation won't deadlock.")
        }
        #endif
        
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
}
