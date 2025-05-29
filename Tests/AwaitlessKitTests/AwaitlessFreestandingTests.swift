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
            let result = Noasync.run({
                    return await fetchData()
                })
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
            let result = Noasync.run({
                    return try await fetchData()
                })
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
            let result = Noasync.run({
                    return await process("data")
                })
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
            let result = Noasync.run({
                    return await transform("input", to: "format")
                })
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
            let result = Noasync.run({
                    return await calculate(from: 10, to: 20)
                })
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
            let result = Noasync.run({
                    return try await fetch(url: "http://example.com", timeout: 30.0, retries: 3)
                })
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
            let result = Noasync.run({
                    return await asyncFunctionWithArguments("arg1", arg2: "arg2", arg3: "internalArg", arg4: "custom")
                })
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
            Noasync.run({
                    return await modify(&value, with: "suffix")
                })
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
            let result = Noasync.run({
                    return await process(data: "test", transform: {
                            $0.uppercased()
                        })
                })
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
            Noasync.run({
                    return await asyncProcess(data: "test", completion: {
                            print($0)
                        })
                })
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
            let result = Noasync.run({
                    return await transform(42, using: String.init)
                })
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
            let result = Noasync.run({
                    return await processCollection(items, where: {
                            $0 == target
                        })
                })
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
            let result = Noasync.run({
                    return await lookup(id: "test", cache: nil)
                })
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
            let result = Noasync.run({
                    return await evaluate(condition: true, message: "Error occurred")
                })
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
            let result = Noasync.run({
                    return await combine("first", "second", "third")
                })
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
            let result = Noasync.run({
                    return try await complexOperation("input", output: &output, transform: {
                            $0.uppercased()
                        }, options: [:])
                })
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
            let result = Noasync.run({
                    return await process(transform("data", using: {
                                $0.uppercased()
                            }))
                })
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
            let result = Noasync.run({
                    return await object.asyncMethod(with: "parameter")
                })
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
            let result = Noasync.run({
                    return await object.process("data").transform()
                })
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
            let result = Noasync.run({
                    return await processAsync(data: "test") { result in
                        print(result)
                    }
                })
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
            let result = Noasync.run({
                    return await processAsync(data: "test") { success in
                        print("Success: \\(success)")
                    } failure: { error in
                        print("Error: \\(error)")
                    }
                })
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
            let result = Noasync.run({
                    return await object?.asyncMethod()?.process()
                })
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
            let result = Noasync.run({
                    return await object!.asyncMethod()!
                })
            """
        }
    }
}
