# Macro Implementation Guide

Technical guide for extending AwaitlessKit macros and understanding their implementation.

## Overview

AwaitlessKit macros use SwiftSyntax to parse async functions and generate synchronous wrappers. All macros follow a consistent four-step pattern: parse declaration, resolve configuration, generate code, return syntax nodes.

## Implementation Pattern

```swift
public struct ExampleMacro: AttachedMacro {
    public static func expansion<T, U>(
        of node: AttributeSyntax,
        providingMembers: T.Type,
        providingExtensionsOf: U.Type,
        in context: some MacroExpansionContext
    ) throws -> [T] {
        // 1. Parse the declaration
        guard let declaration = parseDeclaration(node) else {
            throw MacroError.invalidDeclaration
        }

        // 2. Resolve configuration
        let config = resolveConfiguration(from: node, in: context)

        // 3. Generate code
        let generatedCode = generateWrapper(for: declaration, with: config)

        // 4. Return syntax nodes
        return [generatedCode]
    }
}
```

## Configuration Resolution

### Resolution Algorithm

The configuration resolution follows this detailed algorithm:

```swift
func resolveConfiguration(
    from node: AttributeSyntax,
    in context: MacroExpansionContext
) -> MacroConfiguration {
    var config = MacroConfiguration()

    // 1. Start with built-in defaults
    config.prefix = ""
    config.availability = .none
    config.delivery = .current
    config.strategy = .concurrent

    // 2. Apply process-level defaults
    if let processDefaults = AwaitlessConfig.processDefaults {
        config.merge(with: processDefaults)
    }

    // 3. Apply type-scoped configuration
    if let typeConfig = findTypeConfiguration(in: context) {
        config.merge(with: typeConfig)
    }

    // 4. Apply method-level configuration
    if let methodConfig = parseMethodConfiguration(from: node) {
        config.merge(with: methodConfig)
    }

    return config
}
```

Configuration follows a four-level hierarchy: built-in defaults → process defaults → type configuration → method parameters. Higher levels override lower ones.

## Code Generation

### Syntax Tree Manipulation

AwaitlessKit macros work directly with Swift's Abstract Syntax Tree (AST):

```swift
// Input AST node
let asyncFunction = FunctionDeclSyntax(
    name: "fetchData",
    signature: FunctionSignatureSyntax(
        effects: FunctionEffectSpecifiersSyntax(
            asyncSpecifier: .async,
            throwsSpecifier: .throws
        )
    )
)

// Generated wrapper AST
let syncFunction = FunctionDeclSyntax(
    name: "sync_fetchData",
    signature: FunctionSignatureSyntax(
        effects: FunctionEffectSpecifiersSyntax(
            throwsSpecifier: .throws
        )
    ),
    body: generateSyncBody(from: asyncFunction)
)
```

### Wrapper Generation Strategies

Different strategies are used based on the macro type:

#### @Awaitless Strategy

```swift
func generateAwaitlessWrapper(
    for function: FunctionDeclSyntax,
    with config: MacroConfiguration
) -> FunctionDeclSyntax {
    // Remove async, keep throws
    let signature = removingAsync(from: function.signature)

    // Generate blocking implementation
    let body = """
        return Noasync.run {
            try await \(function.name)(\(parameters))
        }
        """

    return FunctionDeclSyntax(
        attributes: generateAvailabilityAttributes(config.availability),
        name: "\(config.prefix)\(function.name)",
        signature: signature,
        body: body
    )
}
```

#### @AwaitlessPublisher Strategy

```swift
func generatePublisherWrapper(
    for function: FunctionDeclSyntax,
    with config: MacroConfiguration
) -> FunctionDeclSyntax {
    // Convert return type to Publisher
    let returnType = "AnyPublisher<\(function.returnType), Error>"

    // Generate publisher implementation
    let body = """
        return Future { promise in
            Task {
                do {
                    let result = try await \(function.name)(\(parameters))
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: \(config.delivery.schedulerCode))
        .eraseToAnyPublisher()
        """

    return FunctionDeclSyntax(
        name: "\(config.prefix)\(function.name)",
        returnType: returnType,
        body: body
    )
}
```

#### @AwaitlessCompletion Strategy

```swift
func generateCompletionWrapper(
    for function: FunctionDeclSyntax,
    with config: MacroConfiguration
) -> FunctionDeclSyntax {
    // Add completion parameter
    let completionParameter = "completion: @escaping (Result<\(function.returnType), Error>) -> Void"

    // Generate completion-based implementation
    let body = """
        Task {
            do {
                let result = try await \(function.name)(\(parameters))
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
        """

    return FunctionDeclSyntax(
        name: "\(config.prefix)\(function.name)",
        parameters: function.signature.parameters + [completionParameter],
        body: body
    )
}
```

## Error Handling

### Diagnostic Messages

Provide clear, actionable error messages:

```swift
enum MacroError: Error, DiagnosticMessage {
    case invalidDeclaration
    case unsupportedSyntax(String)
    case configurationConflict(String)
    case missingAsyncModifier
    case unsupportedReturnType(String)

    var message: String {
        switch self {
        case .invalidDeclaration:
            return "@Awaitless can only be applied to async functions"
        case .unsupportedSyntax(let detail):
            return "Unsupported syntax: \(detail)"
        case .configurationConflict(let detail):
            return "Configuration conflict: \(detail)"
        case .missingAsyncModifier:
            return "Function must be marked as 'async' to use @Awaitless"
        case .unsupportedReturnType(let type):
            return "Return type '\(type)' is not supported for sync wrapper generation"
        }
    }

    var severity: DiagnosticSeverity { .error }
    var diagnosticID: MessageID { MessageID(domain: "AwaitlessKit", id: "\(self)") }
}
```

### Comprehensive Error Reporting

All macros provide comprehensive error reporting:

- **Syntax Errors** - Clear messages for invalid usage patterns
- **Configuration Conflicts** - Warnings when configurations conflict
- **Type Safety** - Compile-time validation of generated code
- **Diagnostic Messages** - Helpful suggestions for fixing issues

### Validation Rules

Implement comprehensive validation:

```swift
func validateDeclaration(_ function: FunctionDeclSyntax) throws {
    // Check for async modifier
    guard function.signature.effectSpecifiers?.asyncSpecifier != nil else {
        throw MacroError.missingAsyncModifier
    }

    // Validate parameter types
    for parameter in function.signature.parameterClause.parameters {
        try validateParameterType(parameter.type)
    }

    // Check return type compatibility
    try validateReturnType(function.signature.returnClause?.type)

    // Validate function context (must be in class/struct/actor)
    try validateContext(function)
}

func validateParameterType(_ type: TypeSyntax?) throws {
    // Ensure parameter types are compatible with sync wrappers
    guard let type = type else { return }

    // Check for unsupported types like isolated parameters
    if containsIsolatedParameters(type) {
        throw MacroError.unsupportedSyntax("Isolated parameters not supported in sync wrappers")
    }
}

func validateReturnType(_ returnType: TypeSyntax?) throws {
    // Validate return type can be used in sync context
    guard let returnType = returnType else { return }

    // Check for actor-isolated return types
    if isActorIsolated(returnType) {
        throw MacroError.unsupportedReturnType("Actor-isolated types cannot be returned from sync wrappers")
    }
}
```

## Macro Composition

Multiple macros can be applied to generate different wrapper styles:

```swift
@Awaitless
@AwaitlessPublisher
@AwaitlessCompletion
func complexOperation() async throws -> Result {
    // Generates three wrappers from one async implementation
}
```

## Testing Strategies

### Unit Testing Macros

Test macro expansion in isolation:

```swift
func testAwaitlessMacroExpansion() {
    let input = """
        @Awaitless
        func fetchData() async throws -> Data {
            // Implementation
        }
        """

    let expected = """
        func fetchData() throws -> Data {
            return Noasync.run {
                try await fetchData()
            }
        }
        """

    assertMacroExpansion(input, expandedSource: expected)
}

func testConfigurationInheritance() {
    let input = """
        @AwaitlessConfig(prefix: "sync_")
        class APIService {
            @Awaitless
            func fetchUser() async throws -> User {
                // Implementation
            }
        }
        """

    let expected = """
        class APIService {
            func sync_fetchUser() throws -> User {
                return Noasync.run {
                    try await fetchUser()
                }
            }
        }
        """

    assertMacroExpansion(input, expandedSource: expected)
}
```

### Integration Testing

### Integration Testing

Test macros with real code:

```swift
func testMacroWithConfiguration() {
    AwaitlessConfig.setDefaults(prefix: "test_")

    @AwaitlessConfig(availability: .deprecated("Test"))
    class TestClass {
        @Awaitless
        func testMethod() async -> Int { 42 }
    }

    // Verify generated code behavior
    let instance = TestClass()
    let result = instance.test_testMethod()
    XCTAssertEqual(result, 42)
}

func testErrorHandling() {
    @AwaitlessConfig(prefix: "failing_")
    class ErrorTestClass {
        @Awaitless
        func throwingMethod() async throws -> String {
            throw TestError.example
        }
    }

    let instance = ErrorTestClass()
    XCTAssertThrowsError(try instance.failing_throwingMethod()) { error in
        XCTAssertTrue(error is TestError)
    }
}
```

## Debugging Macro Expansion

To understand how macros expand your code:

1. **Use Xcode's Macro Expansion** - Right-click on macro usage → "Expand Macro"
2. **Add Debug Prints** - Temporarily add print statements in macro implementations
3. **Examine Generated Code** - Review the generated interface in Xcode's navigator
4. **Use Compiler Flags** - Add `-Xfrontend -dump-macro-expansions` for detailed output

### Common Debugging Scenarios

```swift
// Debug configuration resolution
@Awaitless  // Add breakpoint here to examine resolved config
func debugMethod() async -> String {
    return "debug"
}

// Debug error messages
@Awaitless
func nonAsyncMethod() -> String {  // This will generate helpful error
    return "error"
}

// Debug generated code
@Awaitless(prefix: "debug_")
func complexMethod(param: String) async throws -> [String] {
    // Examine generated wrapper in Xcode's navigator
    return [param]
}
```

## Extending AwaitlessKit

To create custom macros, follow the established pattern:

1. Parse the Swift syntax tree
2. Resolve configuration hierarchy
3. Generate wrapper code
4. Provide clear error messages

Test both macro expansion and runtime behavior with realistic use cases.
