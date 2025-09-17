# AwaitlessKit Design Patterns and Guidelines

## Core Design Principles

### 1. Migration-First Design

- **Temporary Solution**: Designed explicitly as a migration tool, not permanent architecture
- **Backward Compatibility**: Maintains existing sync APIs during async transition
- **Gradual Adoption**: Enables incremental migration without "all-or-nothing" rewrites

### 2. Macro-Driven Architecture

- **Code Generation**: Uses Swift macros for automatic sync wrapper generation
- **Type Safety**: Leverages SwiftSyntax for safe code manipulation
- **Compile-Time Safety**: Validates async functions and generates appropriate diagnostics

### 3. Swift Concurrency Integration

- **Awaitless Bridge**: Core bridge between sync and async worlds
- **Isolation Awareness**: Respects actor boundaries and isolation
- **Safety Bypass**: Intentionally bypasses some concurrency safety (with warnings)

## Key Patterns

### Macro Implementation Pattern

```swift
public struct SomeMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext) throws -> [DeclSyntax]
    {
        // 1. Validate input declaration
        // 2. Extract parameters from attribute
        // 3. Generate peer declarations
        // 4. Return generated code
    }
}
```

### Error Handling Pattern

- Custom diagnostic messages for macro errors
- Clear validation of input requirements
- Graceful degradation (return empty array on invalid input)

### Code Generation Pattern

- Use SwiftSyntaxBuilder for generating code
- Maintain original function signatures with modifications
- Add appropriate availability annotations

## Architecture Guidelines

### Target Separation

- **AwaitlessCore**: Shared types and utilities
- **AwaitlessKit**: Public API and runtime
- **AwaitlessKitMacros**: Macro implementations
- **Tests**: Comprehensive macro and runtime testing

### API Design

- Simple, declarative macro syntax
- Sensible defaults with customization options
- Clear deprecation and migration paths
- Consistent naming conventions

### Testing Strategy

- Macro expansion testing using SwiftSyntaxMacrosTestSupport
- Runtime behavior testing
- Integration testing with sample app
- Cross-platform validation (macOS, iOS, Linux)

## Best Practices

### When Using AwaitlessKit

1. Use only during migration periods
2. Plan deprecation timeline
3. Test both sync and async versions
4. Monitor for concurrency issues
5. Remove macro usage once migration complete

### Code Organization

- Keep macro implementations focused and single-purpose
- Use clear diagnostic messages
- Maintain comprehensive test coverage
- Document intended usage patterns
- Provide migration examples

## Anti-Patterns to Avoid

- Using as permanent solution
- Ignoring concurrency safety warnings
- Skipping migration planning
- Over-relying on sync wrappers
- Missing test coverage for generated code
