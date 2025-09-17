//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class AwaitlessCompletion: Sendable {
    @AwaitlessCompletion
    func fetchData() async throws -> String {
        await simulateProcessing()
        if Bool.random() {
            throw NSError(domain: "Demo", code: 2, userInfo: [NSLocalizedDescriptionKey: "Random failure"])
        }
        return "Completion handler data"
    }
    
    @AwaitlessCompletion(prefix: "callback_")
    func processRequest(_ request: String) async throws -> Bool {
        await simulateProcessing()
        return request.count > 5
    }
}