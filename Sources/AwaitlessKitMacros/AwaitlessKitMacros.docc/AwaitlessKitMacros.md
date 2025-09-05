# ``AwaitlessKitMacros``

Swift macros that automatically generate synchronous wrappers for async/await functions.

## Overview

AwaitlessKitMacros contains the implementation of all the macros provided by AwaitlessKit. These macros use SwiftSyntax to analyze your async code and automatically generate corresponding synchronous wrapper functions.

### Available Macros

The macros are organized into several categories based on their purpose:

#### Code Generation Macros

- **@Awaitless** - Generates synchronous wrapper functions for async methods
- **@AwaitlessPublisher** - Generates Combine publishers from async functions
- **@AwaitlessCompletion** - Generates completion-handler-based wrappers
- **@Awaitlessable** - Generates protocol extensions for async protocols

#### Configuration Macros

- **@AwaitlessConfig** - Member macro for setting type-scoped configuration defaults
- **#awaitless()** - Freestanding macro for inline async execution in sync contexts

#### Utility Macros

- **@IsolatedSafe** - Thread-safe property wrapper generation

### Macro Implementation Architecture

All macros follow a consistent architecture pattern:

1. **Syntax Analysis** - Parse the attached declaration using SwiftSyntax
2. **Configuration Resolution** - Apply the four-level configuration hierarchy
3. **Code Generation** - Generate appropriate wrapper code
4. **Integration** - Integrate generated code with existing declarations

### Configuration System Integration

The macros implement a sophisticated configuration hierarchy:

1. **Process-Level Defaults** - Global defaults set via `AwaitlessConfig.setDefaults()`
2. **Type-Scoped Configuration** - Per-type defaults via `@AwaitlessConfig` 
3. **Method-Level Configuration** - Per-method settings via macro parameters
4. **Built-in Defaults** - Fallback values when no configuration is provided

### Error Handling

All macros provide comprehensive error reporting:

- **Syntax Errors** - Clear messages for invalid usage patterns
- **Configuration Conflicts** - Warnings when configurations conflict
- **Type Safety** - Compile-time validation of generated code
- **Diagnostic Messages** - Helpful suggestions for fixing issues

### Performance Considerations

The macros are designed for optimal compile-time performance:

- **Lazy Evaluation** - Configuration is resolved only when needed
- **Caching** - Repeated analysis results are cached within compilation
- **Minimal Code Generation** - Only necessary wrapper code is generated
- **Swift Syntax Efficiency** - Direct AST manipulation without string processing

## Topics

### Core Implementation

- ``AwaitlessSyncMacro``
- ``AwaitlessPublisherMacro``
- ``AwaitlessCompletionMacro``
- ``AwaitlessableMacro``

### Configuration Implementation

- ``AwaitlessConfigMacro``
- ``AwaitlessFreestandingMacro``

### Utility Implementation

- ``IsolatedSafeMacro``

### Helper Types

- ``AwaitlessMacroHelpers``

### Plugin Registration

- ``AwaitlessKitMacrosPlugin``

## Advanced Usage

### Custom Macro Development

If you need to extend AwaitlessKit with custom macros, you can use the helper utilities:

```swift
import AwaitlessKitMacros

// Use helper functions for consistent behavior
let config = AwaitlessMacroHelpers.resolveConfiguration(
    from: declaration,
    in: context
)

// Generate code using established patterns
let wrapper = AwaitlessMacroHelpers.generateSyncWrapper(
    for: function,
    with: config
)
```

### Debugging Macro Expansion

To understand how macros expand your code:

1. **Use Xcode's Macro Expansion** - Right-click on macro usage → "Expand Macro"
2. **Add Debug Prints** - Temporarily add print statements in macro implementations
3. **Examine Generated Code** - Review the generated interface in Xcode's navigator

### Contributing to Macro Development

When contributing new macros or modifications:

1. **Follow Architecture Patterns** - Use established patterns for consistency
2. **Add Comprehensive Tests** - Cover all configuration combinations
3. **Document Behavior** - Update this documentation with new capabilities
4. **Performance Testing** - Ensure new macros don't impact compilation time

## Implementation Details

### Syntax Tree Processing

The macros work by transforming Swift AST nodes:

```swift
// Input: @Awaitless func fetchData() async throws -> Data
// Processing: Parse function signature, extract async/throws, generate wrapper
// Output: func sync_fetchData() throws -> Data { /* blocking wrapper */ }
```

### Configuration Resolution Algorithm

Configuration resolution follows this priority order:

1. **Explicit Parameters** - Direct parameters on the macro
2. **Type Configuration** - Settings from `@AwaitlessConfig` on the containing type
3. **Process Defaults** - Global defaults from `AwaitlessConfig.setDefaults()`
4. **Built-in Defaults** - Hardcoded fallback values

### Thread Safety

All macro implementations are thread-safe for concurrent compilation:

- **Immutable State** - No mutable global state in macro implementations
- **Context Isolation** - Each macro expansion has isolated context
- **Resource Safety** - No shared resources between expansions