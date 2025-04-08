//
// Copyright (c) 2025 Daniel Bauke
//

import Foundation
import NoasyncMacro
import TaskNoasync

final class Blah {
    @Noasync
    func blah() async -> String {
        "blah"
    }

    func baz() {
        let blah = noasync_blah()
    }
}
