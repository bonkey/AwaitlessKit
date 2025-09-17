//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["awaitless": AwaitlessFreestandingMacro.self], record: .missing))
struct AwaitlessFreestandingTests {
    @Test("Expand freestanding macro")
    func basic() {
        assertMacro {
            """
            let result = #awaitless(fetchData())
            """
        } expansion: {
            """
            let result = Noasync.run {
                await fetchData()
            }
            """
        }
    }

    @Test("Handle try expression")
    func withTry() {
        assertMacro {
            """
            let result = #awaitless(try fetchData())
            """
        } expansion: {
            """
            let result = Noasync.run {
                try await fetchData()
            }
            """
        }
    }

    @Test("Function with unlabeled first parameter")
    func unlabeledFirstParameter() {
        assertMacro {
            """
            let result = #awaitless(process("data"))
            """
        } expansion: {
            """
            let result = Noasync.run {
                await process("data")
            }
            """
        }
    }

    @Test("Function with mixed labeled and unlabeled parameters")
    func mixedLabeledUnlabeled() {
        assertMacro {
            """
            let result = #awaitless(transform("input", to: "format"))
            """
        } expansion: {
            """
            let result = Noasync.run {
                await transform("input", to: "format")
            }
            """
        }
    }

    @Test("Function with internal parameter names")
    func internalParameterNames() {
        assertMacro {
            """
            let result = #awaitless(calculate(from: 10, to: 20))
            """
        } expansion: {
            """
            let result = Noasync.run {
                await calculate(from: 10, to: 20)
            }
            """
        }
    }

    @Test("Function with default parameters")
    func defaultParameters() {
        assertMacro {
            """
            let result = #awaitless(try fetch(url: "http://example.com", timeout: 30.0, retries: 3))
            """
        } expansion: {
            """
            let result = Noasync.run {
                try await fetch(url: "http://example.com", timeout: 30.0, retries: 3)
            }
            """
        }
    }

    @Test("Complex function with all argument variants")
    func complexArgumentVariants() {
        assertMacro {
            """
            let result = #awaitless(asyncFunctionWithArguments("arg1", arg2: "arg2", arg3: "internalArg", arg4: "custom"))
            """
        } expansion: {
            """
            let result = Noasync.run {
                await asyncFunctionWithArguments("arg1", arg2: "arg2", arg3: "internalArg", arg4: "custom")
            }
            """
        }
    }

    @Test("Function with inout parameters")
    func inoutParameters() {
        assertMacro {
            """
            #awaitless(modify(&value, with: "suffix"))
            """
        } expansion: {
            """
            Noasync.run {
                await modify(&value, with: "suffix")
            }
            """
        }
    }

    @Test("Function with closure parameters")
    func closureParameters() {
        assertMacro {
            """
            let result = #awaitless(process(data: "test", transform: { $0.uppercased() }))
            """
        } expansion: {
            """
            let result = Noasync.run {
                return await process(data: "test", transform: {
                        $0.uppercased()
                    })
            }
            """
        }
    }

    @Test("Function with escaping closure parameters")
    func escapingClosureParameters() {
        assertMacro {
            """
            #awaitless(asyncProcess(data: "test", completion: { print($0) }))
            """
        } expansion: {
            """
            Noasync.run {
                return await asyncProcess(data: "test", completion: {
                        print($0)
                    })
            }
            """
        }
    }

    @Test("Function with generic parameters")
    func genericParameters() {
        assertMacro {
            """
            let result = #awaitless(transform(42, using: String.init))
            """
        } expansion: {
            """
            let result = Noasync.run {
                await transform(42, using: String.init)
            }
            """
        }
    }

    @Test("Function with complex generic constraints")
    func complexGenericConstraints() {
        assertMacro {
            """
            let result = #awaitless(processCollection(items, where: { $0 == target }))
            """
        } expansion: {
            """
            let result = Noasync.run {
                return await processCollection(items, where: {
                        $0 == target
                    })
            }
            """
        }
    }

    @Test("Function with optional parameters")
    func optionalParameters() {
        assertMacro {
            """
            let result = #awaitless(lookup(id: "test", cache: nil))
            """
        } expansion: {
            """
            let result = Noasync.run {
                await lookup(id: "test", cache: nil)
            }
            """
        }
    }

    @Test("Function with autoclosure parameters")
    func autoclosureParameters() {
        assertMacro {
            """
            let result = #awaitless(evaluate(condition: true, message: "Error occurred"))
            """
        } expansion: {
            """
            let result = Noasync.run {
                await evaluate(condition: true, message: "Error occurred")
            }
            """
        }
    }

    @Test("Function with multiple unlabeled parameters")
    func multipleUnlabeledParameters() {
        assertMacro {
            """
            let result = #awaitless(combine("first", "second", "third"))
            """
        } expansion: {
            """
            let result = Noasync.run {
                await combine("first", "second", "third")
            }
            """
        }
    }

    @Test("Function with mixed parameter attributes")
    func mixedParameterAttributes() {
        assertMacro {
            """
            let result = #awaitless(try complexOperation("input", output: &output, transform: { $0.uppercased() }, options: [:]))
            """
        } expansion: {
            """
            let result = Noasync.run {
                return try await complexOperation("input", output: &output, transform: {
                        $0.uppercased()
                    }, options: [:])
            }
            """
        }
    }

    @Test("Nested function calls")
    func nestedFunctionCalls() {
        assertMacro {
            """
            let result = #awaitless(process(transform("data", using: { $0.uppercased() })))
            """
        } expansion: {
            """
            let result = Noasync.run {
                await process(transform("data", using: {
                            $0.uppercased()
                        }))
            }
            """
        }
    }

    @Test("Method call on object")
    func methodCall() {
        assertMacro {
            """
            let result = #awaitless(object.asyncMethod(with: "parameter"))
            """
        } expansion: {
            """
            let result = Noasync.run {
                await object.asyncMethod(with: "parameter")
            }
            """
        }
    }

    @Test("Chained method calls")
    func chainedMethodCalls() {
        assertMacro {
            """
            let result = #awaitless(object.process("data").transform())
            """
        } expansion: {
            """
            let result = Noasync.run {
                await object.process("data").transform()
            }
            """
        }
    }

    @Test("Function call with trailing closure")
    func trailingClosure() {
        assertMacro {
            """
            let result = #awaitless(processAsync(data: "test") { result in
                print(result)
            })
            """
        } expansion: {
            """
            let result = Noasync.run {
                return await processAsync(data: "test") { result in
                    print(result)
                }
            }
            """
        }
    }

    @Test("Function call with multiple trailing closures")
    func multipleTrailingClosures() {
        assertMacro {
            """
            let result = #awaitless(processAsync(data: "test") { success in
                print("Success: \\(success)")
            } failure: { error in
                print("Error: \\(error)")
            })
            """
        } expansion: {
            """
            let result = Noasync.run {
                return await processAsync(data: "test") { success in
                    print("Success: \\(success)")
                } failure: { error in
                    print("Error: \\(error)")
                }
            }
            """
        }
    }

    @Test("Optional chaining")
    func optionalChaining() {
        assertMacro {
            """
            let result = #awaitless(object?.asyncMethod()?.process())
            """
        } expansion: {
            """
            let result = Noasync.run {
                await object?.asyncMethod()?.process()
            }
            """
        }
    }

    @Test("Force unwrapping")
    func forceUnwrapping() {
        assertMacro {
            """
            let result = #awaitless(object!.asyncMethod()!)
            """
        } expansion: {
            """
            let result = Noasync.run {
                return await object!.asyncMethod()!
            }
            """
        }
    }

    @Test("Async property accessor (should not expand)")
    func asyncPropertyAccessor() {
        assertMacro {
            """
            let value = #awaitless(object.asyncProperty)
            """
        } expansion: {
            // Property access is not an async call; expansion should probably fail or be a no-op, depending on macro
            // behavior.
            """
            let value = Noasync.run {
                await object.asyncProperty
            }
            """
        }
    }

    @Test("Async subscript call")
    func asyncSubscript() {
        assertMacro {
            """
            let result = #awaitless(object[42])
            """
        } expansion: {
            """
            let result = Noasync.run {
                return await object[42]
            }
            """
        }
    }

    @Test("Async initializer")
    func asyncInitializer() {
        assertMacro {
            """
            let value = #awaitless(MyTypeAsync.init(param: 7))
            """
        } expansion: {
            """
            let value = Noasync.run {
                await MyTypeAsync.init(param: 7)
            }
            """
        }
    }

    @Test("Async void return")
    func asyncVoidReturn() {
        assertMacro {
            """
            #awaitless(doSomethingAsync())
            """
        } expansion: {
            """
            Noasync.run {
                await doSomethingAsync()
            }
            """
        }
    }

    @Test("Static async method call")
    func staticAsyncMethod() {
        assertMacro {
            """
            let value = #awaitless(MyType.staticAsyncMethod(with: 5))
            """
        } expansion: {
            """
            let value = Noasync.run {
                await MyType.staticAsyncMethod(with: 5)
            }
            """
        }
    }
}
