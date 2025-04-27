//
// Copyright (c) 2025 Daniel Bauke
//

import Foundation

#if compiler(>=6.0)
public enum Noasync<Success: Sendable, Failure: Sendable & Error> {}
#else
public enum Noasync<Success: Sendable> {}
#endif
