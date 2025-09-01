//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation
import Combine

class CombineService {
    @AwaitlessPublisher
    func fetchItems() async -> [String] {
        try? await Task.sleep(nanoseconds: 1_000_000)
        return ["Item 1 from Combine", "Item 2 from Combine", "Item 3 from Combine"]
    }
}
