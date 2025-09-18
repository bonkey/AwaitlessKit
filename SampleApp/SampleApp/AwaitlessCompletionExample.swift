//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class AwaitlessCompletionExample: Sendable {
    @AwaitlessCompletion
    func fetchData() async throws -> String {
        await simulateProcessing()
        return "Completion handler data"
    }

    @AwaitlessCompletion(prefix: "callback_")
    func processRequest(_ request: String) async throws -> Bool {
        await simulateProcessing()
        return request.count > 5
    }
}
