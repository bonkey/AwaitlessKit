//
// Copyright (c) 2025 Daniel Bauke
//

import Foundation

extension Noasync {
    #if compiler(>=6.0)
    public static func withCompletion(
        _ code: sending () async throws(Failure) -> Success,
        _ completion: @Sendable @escaping (Result<Success, Failure>) -> Void)
    {
        let semaphore = DispatchSemaphore(value: 0)

        nonisolated(unsafe) var result: Result<Success, Failure>?

        withoutActuallyEscaping(code) {
            nonisolated(unsafe) let sendableCode = $0

            let coreTask = Task<Void, Never>
                .detached(priority: .userInitiated) { @Sendable () async in

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

        completion(result!)
    }
    #endif
}
