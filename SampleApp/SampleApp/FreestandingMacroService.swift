//
// Copyright (c) 2025 Daniel Bauke
//

import Foundation

final class FreestandingMacroService: Sendable {
    func getNumber() async -> Int {
        try? await Task.sleep(nanoseconds: 1_000_000)
        return 42
    }
}
