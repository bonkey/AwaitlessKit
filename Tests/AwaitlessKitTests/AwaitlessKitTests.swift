//
//  AwaitlessKitTests.swift
//  AwaitlessKit
//
//  Created by Daniel Bauke on 18.04.25.
//

import Testing
import MacroTesting
@testable import AwaitlessKit
import AwaitlessKitMacros

@Suite(
  .macros(
    ["IsolatedSafe": IsolatedSafeMacro.self],
    record: .missing
  )
)
struct StringifyMacroSwiftTestingTests {
  @Test
  func testIsolatedSafe() {
    assertMacro {
      """
          @IsolatedSafe(queueName: "blah")
          private nonisolated(unsafe) var _unsafeStrings: [String] = ["Hello", "World"]
      """
    } expansion: {
      """
          private nonisolated(unsafe) var _unsafeStrings: [String] = ["Hello", "World"]

          internal var strings: [String] {
              get {
                  blah.sync {
                      self._unsafeStrings
                  }
              }
          }

          private let blah = DispatchQueue(label: "blah", attributes: .concurrent)
      """
    }
  }
}
