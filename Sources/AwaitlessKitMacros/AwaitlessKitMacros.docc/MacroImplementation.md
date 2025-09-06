# Macro Implementation Guide

Comprehensive guide to implementing and extending AwaitlessKit macros.

## Overview

This guide provides detailed information about how AwaitlessKit macros are implemented, how to extend them, and how to create custom macros that integrate with the configuration system.

## Macro Architecture

### Core Components

Each macro in AwaitlessKit follows a consistent architecture with these components:

1. **Declaration Parser** - Analyzes the Swift syntax tree
2. **Configuration Resolver** - Applies the four-level configuration hierarchy
3. **Code Generator** - Creates the wrapper implementation
4. **Error Reporter** - Provides helpful diagnostic messages

### Implementation Pattern

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

### Configuration Inheritance

Configuration inheritance works through a merge strategy:

- **Additive Properties** - Combine values (e.g., prefix concatenation)
- **Override Properties** - Replace values (e.g., availability attributes)
- **Contextual Properties** - Apply based on macro type (e.g., delivery for publishers)

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

## Error Handling

### Diagnostic Messages

Provide clear, actionable error messages:

```swift
enum MacroError: Error, DiagnosticMessage {
    case invalidDeclaration
    case unsupportedSyntax(String)
    case configurationConflict(String)
    
    var message: String {
        switch self {
        case .invalidDeclaration:
            return "@Awaitless can only be applied to async functions"
        case .unsupportedSyntax(let detail):
            return "Unsupported syntax: \(detail)"
        case .configurationConflict(let detail):
            return "Configuration conflict: \(detail)"
        }
    }
    
    var severity: DiagnosticSeverity { .error }
    var diagnosticID: MessageID { MessageID(domain: "AwaitlessKit", id: "\(self)") }
}
```

### Validation Rules

Implement comprehensive validation:

```swift
func validateDeclaration(_ function: FunctionDeclSyntax) throws {
    // Check for async modifier
    guard function.signature.effectSpecifiers?.asyncSpecifier != nil else {
        throw MacroError.invalidDeclaration
    }
    
    // Validate parameter types
    for parameter in function.signature.parameterClause.parameters {
        try validateParameterType(parameter.type)
    }
    
    // Check return type compatibility
    try validateReturnType(function.signature.returnClause?.type)
}
```

## Advanced Features

### Custom Configuration Types

Extend the configuration system with custom types:

```swift
// Define custom configuration
public struct CustomAwaitlessConfig {
    let timeout: TimeInterval?
    let retryCount: Int?
    let priority: TaskPriority?
}

// Integrate with macro system
extension MacroConfiguration {
    var custom: CustomAwaitlessConfig {
        get { customData["CustomAwaitlessConfig"] as? CustomAwaitlessConfig ?? CustomAwaitlessConfig() }
        set { customData["CustomAwaitlessConfig"] = newValue }
    }
}
```

### Macro Composition

Combine multiple macros for complex behavior:

```swift
@Awaitless
@AwaitlessPublisher  
@AwaitlessCompletion
func complexOperation() async throws -> Result {
    // Single async implementation generates three sync variants
}
```

### Performance Optimization

Optimize macro expansion performance:

1. **Cache Parsed Configurations** - Avoid re-parsing identical configurations
2. **Lazy Code Generation** - Generate code only when needed
3. **Minimize AST Traversal** - Efficient tree walking algorithms
4. **Batch Operations** - Group related operations

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
```

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
```

## Best Practices

### Macro Development

1. **Follow Naming Conventions** - Use consistent naming across all macros
2. **Provide Rich Diagnostics** - Help users understand and fix issues
3. **Optimize for Common Cases** - Make common usage patterns efficient
4. **Maintain Backward Compatibility** - Avoid breaking changes in macro behavior

### Configuration Design

1. **Hierarchical Thinking** - Design configurations to work well with the hierarchy
2. **Sensible Defaults** - Choose defaults that work for most users
3. **Clear Precedence** - Make the configuration precedence obvious
4. **Validation Early** - Catch configuration errors at compile time

### Testing Coverage

1. **Test All Configuration Combinations** - Ensure all hierarchy levels work
2. **Test Error Cases** - Verify error messages are helpful
3. **Performance Testing** - Ensure macros don't slow compilation
4. **Integration Testing** - Test with real-world usage patterns