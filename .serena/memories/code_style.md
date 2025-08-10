# AwaitlessKit Code Style and Conventions

## Formatting
- **Tool**: SwiftFormat with custom configuration (`.swiftformat`)
- **Indentation**: 4 spaces
- **Line Width**: 120 characters
- **Semicolons**: Never used
- **Import Organization**: testable-first grouping

## SwiftFormat Configuration
- Closing parentheses on same line
- Arguments/parameters wrapped before-first
- Collections wrapped before-first
- Extension access control on declarations
- Many enabled rules for consistency (see `.swiftformat` file)

## File Headers
All source files include a copyright header:
```swift
//
// Copyright (c) {year} Daniel Bauke
//
```

## Code Patterns
- Public imports using `public import` syntax
- Extensive use of macro attributes
- Clear separation of concerns across targets
- Comprehensive error handling with custom diagnostics
- Type-safe macro implementations using SwiftSyntax

## Documentation
- Uses DocC for documentation
- Inline documentation for public APIs
- Comprehensive README with examples
- Dedicated documentation targets in SPI configuration

## Naming Conventions
- Swift standard naming conventions
- Macro names use PascalCase with descriptive suffixes (e.g., `AwaitlessAttachedMacro`)
- Clear, descriptive variable and function names
- Consistent use of prefixes for generated code