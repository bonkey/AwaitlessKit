//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class NetworkManager: Sendable {
    @Awaitless
    func downloadFile(url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}
