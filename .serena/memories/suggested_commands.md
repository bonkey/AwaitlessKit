# AwaitlessKit Development Commands

## Essential Just Commands (using Justfile)

### Building and Testing

- `just build` or `just b` - Build the package
- `just test` or `just t` - Run all tests
- `just clean` or `just c` - Clean build artifacts and kill Xcode
- `just reset` - Full reset including derived data

### Code Formatting

- `just fmt` or `just f` - Format code using SwiftFormat

### Sample App

- `just run-sample-app` or `just r` - Run the sample app
- `just run-and-build-sample-app` or `just rb` - Build and run sample app
- `just build-sample-app` - Build sample app only

### Xcode Integration

- `just resolve-package` - Resolve package dependencies for Xcode workspace
- `just resolve-sample-app` - Resolve dependencies for sample app
- `just kill-xcode` - Force quit Xcode processes

## Direct Swift Commands

- `swift build` - Standard SPM build
- `swift test` - Run tests via SPM
- `swift package clean` - Clean package build artifacts
- `swift package reset` - Reset package state

## CI/CD

The project uses GitHub Actions with multiple workflows:

- Tests on Xcode 16 (macOS 15)
- Tests on Linux
- Cirrus CI integration

## Development Tools

- **xcbeautify** or **xcpretty** - Output formatting (if available)
- **SwiftFormat** - Code formatting
- **Xcode** - IDE support with workspace at `.swiftpm/xcode/package.xcworkspace`

## Useful Xcode Commands

- Use Xcode 16+ for development (requires Swift 6.0+ compiler)
- Derived data stored in `.xcodeDerivedData/`
