//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["Awaitless": AwaitlessAttachedMacro.self], record: .missing))
struct AwaitlessArgumentVariantsTests {

    @Test("Function with unlabeled first parameter")
    func unlabeledFirstParameter() {
        assertMacro {
            """
            @Awaitless
            func process(_ data: String) async -> String {
                return data.uppercased()
            }
            """
        } expansion: {
            """
            func process(_ data: String) async -> String {
                return data.uppercased()
            }

            @available(*, noasync) func process(_ data: String) -> String {
                Noasync.run({
                        await process(data)
                    })
            }
            """
        }
    }

    @Test("Function with mixed labeled and unlabeled parameters")
    func mixedLabeledUnlabeled() {
        assertMacro {
            """
            @Awaitless
            func transform(_ input: String, to format: String) async -> String {
                return input + format
            }
            """
        } expansion: {
            """
            func transform(_ input: String, to format: String) async -> String {
                return input + format
            }

            @available(*, noasync) func transform(_ input: String, to format: String) -> String {
                Noasync.run({
                        await transform(input, to: format)
                    })
            }
            """
        }
    }

    @Test("Function with internal parameter names")
    func internalParameterNames() {
        assertMacro {
            """
            @Awaitless
            func calculate(from startValue: Int, to endValue: Int) async -> Int {
                return endValue - startValue
            }
            """
        } expansion: {
            """
            func calculate(from startValue: Int, to endValue: Int) async -> Int {
                return endValue - startValue
            }

            @available(*, noasync) func calculate(from startValue: Int, to endValue: Int) -> Int {
                Noasync.run({
                        await calculate(from: startValue, to: endValue)
                    })
            }
            """
        }
    }

    @Test("Function with default parameters")
    func defaultParameters() {
        assertMacro {
            """
            @Awaitless
            func fetch(url: String, timeout: Double = 30.0, retries: Int = 3) async throws -> Data {
                return Data()
            }
            """
        } expansion: {
            """
            func fetch(url: String, timeout: Double = 30.0, retries: Int = 3) async throws -> Data {
                return Data()
            }

            @available(*, noasync) func fetch(url: String, timeout: Double = 30.0, retries: Int = 3) throws -> Data {
                try Noasync.run({
                        try await fetch(url: url, timeout: timeout, retries: retries)
                    })
            }
            """
        }
    }

    @Test("Complex function with all argument variants")
    func complexArgumentVariants() {
        assertMacro {
            """
            @Awaitless
            func asyncFunctionWithArguments(
                _ arg1: String,
                arg2: String,
                arg3 internalArg: String,
                arg4: String = "default",
                args: String...) async -> String {
                return arg1 + arg2 + internalArg + arg4 + args.joined()
            }
            """
        } expansion: {
            """
            func asyncFunctionWithArguments(
                _ arg1: String,
                arg2: String,
                arg3 internalArg: String,
                arg4: String = "default") async -> String {
                return arg1 + arg2 + internalArg + arg4 + args.joined()
            }

            @available(*, noasync) func asyncFunctionWithArguments(
                _ arg1: String,
                arg2: String,
                arg3 internalArg: String,
                arg4: String = "default") -> String {
                Noasync.run({
                        await asyncFunctionWithArguments(arg1, arg2: arg2, arg3: internalArg, arg4: arg4)
                    })
            }
            """
        }
    }

    @Test("Function with inout parameters")
    func inoutParameters() {
        assertMacro {
            """
            @Awaitless
            func modify(_ value: inout String, with suffix: String) async {
                value += suffix
            }
            """
        } expansion: {
            """
            func modify(_ value: inout String, with suffix: String) async {
                value += suffix
            }

            @available(*, noasync) func modify(_ value: inout String, with suffix: String) {
                Noasync.run({
                        await modify(&value, with: suffix)
                    })
            }
            """
        }
    }

    @Test("Function with closure parameters")
    func closureParameters() {
        assertMacro {
            """
            @Awaitless
            func process(data: String, transform: (String) -> String) async -> String {
                return transform(data)
            }
            """
        } expansion: {
            """
            func process(data: String, transform: (String) -> String) async -> String {
                return transform(data)
            }

            @available(*, noasync) func process(data: String, transform: (String) -> String) -> String {
                Noasync.run({
                        await process(data: data, transform: transform)
                    })
            }
            """
        }
    }

    @Test("Function with escaping closure parameters")
    func escapingClosureParameters() {
        assertMacro {
            """
            @Awaitless
            func asyncProcess(data: String, completion: @escaping (String) -> Void) async {
                completion(data)
            }
            """
        } expansion: {
            """
            func asyncProcess(data: String, completion: @escaping (String) -> Void) async {
                completion(data)
            }

            @available(*, noasync) func asyncProcess(data: String, completion: @escaping (String) -> Void) {
                Noasync.run({
                        await asyncProcess(data: data, completion: completion)
                    })
            }
            """
        }
    }

    @Test("Function with generic parameters")
    func genericParameters() {
        assertMacro {
            """
            @Awaitless
            func transform<T>(_ input: T, using mapper: (T) -> String) async -> String {
                return mapper(input)
            }
            """
        } expansion: {
            """
            func transform<T>(_ input: T, using mapper: (T) -> String) async -> String {
                return mapper(input)
            }

            @available(*, noasync) func transform<T>(_ input: T, using mapper: (T) -> String) -> String {
                Noasync.run({
                        await transform(input, using: mapper)
                    })
            }
            """
        }
    }

    @Test("Function with complex generic constraints")
    func complexGenericConstraints() {
        assertMacro {
            """
            @Awaitless
            func processCollection<T: Collection>(_ items: T, where predicate: (T.Element) -> Bool) async -> [T.Element] where T.Element: Equatable {
                return items.filter(predicate)
            }
            """
        } expansion: {
            """
            func processCollection<T: Collection>(_ items: T, where predicate: (T.Element) -> Bool) async -> [T.Element] where T.Element: Equatable {
                return items.filter(predicate)
            }

            @available(*, noasync) func processCollection<T: Collection>(_ items: T, where predicate: (T.Element) -> Bool) -> [T.Element] where T.Element: Equatable {
                Noasync.run({
                        await processCollection(items, where: predicate)
                    })
            }
            """
        }
    }

    @Test("Function with optional parameters")
    func optionalParameters() {
        assertMacro {
            """
            @Awaitless
            func lookup(id: String, cache: [String: String]? = nil) async -> String? {
                return cache?[id]
            }
            """
        } expansion: {
            """
            func lookup(id: String, cache: [String: String]? = nil) async -> String? {
                return cache?[id]
            }

            @available(*, noasync) func lookup(id: String, cache: [String: String]? = nil) -> String? {
                Noasync.run({
                        await lookup(id: id, cache: cache)
                    })
            }
            """
        }
    }

    @Test("Function with autoclosure parameters")
    func autoclosureParameters() {
        assertMacro {
            """
            @Awaitless
            func evaluate(condition: Bool, message: @autoclosure () -> String) async -> String {
                return condition ? "Success" : message()
            }
            """
        } expansion: {
            """
            func evaluate(condition: Bool, message: @autoclosure () -> String) async -> String {
                return condition ? "Success" : message()
            }

            @available(*, noasync) func evaluate(condition: Bool, message: @autoclosure () -> String) -> String {
                Noasync.run({
                        await evaluate(condition: condition, message: message)
                    })
            }
            """
        }
    }

    @Test("Function with multiple unlabeled parameters")
    func multipleUnlabeledParameters() {
        assertMacro {
            """
            @Awaitless
            func combine(_ first: String, _ second: String, _ third: String) async -> String {
                return first + second + third
            }
            """
        } expansion: {
            """
            func combine(_ first: String, _ second: String, _ third: String) async -> String {
                return first + second + third
            }

            @available(*, noasync) func combine(_ first: String, _ second: String, _ third: String) -> String {
                Noasync.run({
                        await combine(first, second, third)
                    })
            }
            """
        }
    }

    @Test("Function with mixed parameter attributes")
    func mixedParameterAttributes() {
        assertMacro {
            """
            @Awaitless
            func complexOperation(
                _ input: String,
                output: inout String,
                transform: @escaping (String) -> String,
                options: [String: Any] = [:]) async throws -> Bool {
                output = transform(input)
                return flags.allSatisfy { $0 }
            }
            """
        } expansion: {
            """
            func complexOperation(
                _ input: String,
                output: inout String,
                transform: @escaping (String) -> String,
                options: [String: Any] = [:]) async throws -> Bool {
                output = transform(input)
                return flags.allSatisfy { $0 }
            }

            @available(*, noasync) func complexOperation(
                _ input: String,
                output: inout String,
                transform: @escaping (String) -> String,
                options: [String: Any] = [:]) throws -> Bool {
                try Noasync.run({
                        try await complexOperation(input, output: output, transform: transform, options: options)
                    })
            }
            """
        }
    }
}
