# AwaitlessKit Tech Stack

## Core Technologies

- **Language**: Swift 6.0+ (with Swift 5.x language mode compatibility)
- **Package Manager**: Swift Package Manager (SPM)
- **Build System**: Just (Justfile) + Xcode
- **CI/CD**: GitHub Actions
- **Testing**: XCTest + SwiftSyntaxMacrosTestSupport + MacroTesting

## Dependencies

- **swift-syntax** (601.0.1+) - for macro implementation
- **swift-macro-testing** (0.6.3+) - for macro testing

## Project Structure

```
AwaitlessKit/
├── Sources/
│   ├── AwaitlessKit/           # Main library target
│   ├── AwaitlessKitMacros/     # Macro implementations
│   └── AwaitlessCore/          # Core types and utilities
├── Tests/
│   └── AwaitlessKitTests/      # All test files
├── SampleApp/                  # Example Xcode project
├── .github/workflows/          # CI configurations
└── Package.swift               # SPM configuration
```

## Compiler Features

The project uses several Swift 6.0 experimental and upcoming features:

- StrictConcurrency
- AccessLevelOnImport
- InternalImportsByDefault
- ConciseMagicFile
- And several others for forward compatibility

## Targets

- **AwaitlessKit** - main library
- **AwaitlessKitMacros** - macro implementations (CompilerPlugin)
- **AwaitlessCore** - shared types and utilities
- **AwaitlessKitTests** - comprehensive test suite
