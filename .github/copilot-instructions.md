# AwaitlessKit

AwaitlessKit is a Swift package providing macros to automatically generate synchronous wrappers for async/await functions, enabling easy migration to Swift 6 Structured Concurrency with both APIs available.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Prerequisites
- Swift 6.0+ compiler required (uses Swift 6.1.2)
- This package works on Linux and macOS
- SwiftFormat is NOT installed but .swiftformat config exists
- Just command runner is NOT available on Linux systems

### Bootstrap and Build
- `cd /path/to/AwaitlessKit` - always work from repository root
- `swift build` - builds all targets including macros. Takes 3+ minutes initially. NEVER CANCEL. Set timeout to 10+ minutes.
- `swift package resolve` - resolves dependencies if needed (normally automatic)

### Testing
- `swift test` - runs full test suite. Takes 35-60 seconds. NEVER CANCEL. Set timeout to 5+ minutes.
- `swift test --parallel` - runs tests in parallel (default behavior)
- `swift test --filter "TestSuiteName"` - runs specific test suite (e.g., "AwaitlessAttachedTests")
- All tests should pass on Linux and macOS

### Code Validation
- **NO automatic formatting available** - SwiftFormat not installed, configuration exists but tool missing
- **NO automatic linting** - no linting tools available in environment
- Always run `swift build` and `swift test` to validate changes
- CI runs on Linux and macOS with GitHub Actions

## Validation Scenarios

### Core Macro Functionality Testing
After making changes to macro code, always validate by:
1. `swift build` - ensure macros compile without errors
2. `swift test --filter "AwaitlessAttachedTests"` - test @Awaitless macro generation
3. `swift test --filter "AwaitlessableTests"` - test @Awaitlessable protocol extensions
4. `swift test --filter "IsolatedSafeTests"` - test @IsolatedSafe property wrappers
5. `swift test --filter "AwaitlessCombineTests"` - test Combine publisher generation
6. `swift test --filter "AwaitlessFreestandingTests"` - test #awaitless() macro

### Integration Testing
- SampleApp is an Xcode project located in `SampleApp/` directory
- **SampleApp CANNOT be built or run on Linux** - requires Xcode and macOS
- Use test suite instead of SampleApp for validation on Linux systems
- SampleApp demonstrates real-world usage patterns for documentation

### Manual Validation
The macro functionality can be tested via the main test suite, but if you need to create a custom validation package:

**Important**: Due to Swift 6 strict concurrency and macro limitations, manual validation requires careful setup:

```bash
# Always validate via test suite first - this is the recommended approach
cd /path/to/AwaitlessKit
swift test --filter "AwaitlessAttachedTests"  # Validates @Awaitless macro generation
swift test --filter "AwaitlessableTests"     # Validates @Awaitlessable protocol extensions
```

For integration testing, refer to SampleApp examples in `SampleApp/SampleApp/` directory:
- `NetworkManager.swift` - Shows @Awaitless usage on class methods
- `DataService.swift` - Shows @Awaitlessable usage on protocols  
- `SampleApp.swift` - Shows complete usage patterns

**Note**: 
- The @Awaitless macro only works on class/struct methods, not global functions
- Manual validation packages may encounter Swift 6 strict concurrency warnings - this is expected behavior
- The macro generates synchronous versions with same names but different availability attributes
- Always use the comprehensive test suite for validation rather than manual test packages

## Repository Structure

### Key Directories
```
Sources/
├── AwaitlessKit/           # Main library with macro definitions
├── AwaitlessKitMacros/     # Macro implementation using SwiftSyntax
└── AwaitlessCore/          # Shared types and enums

Tests/
└── AwaitlessKitTests/      # Comprehensive test suite

SampleApp/                  # Xcode demo project (macOS only)
├── SampleApp/             # Swift source files
└── SampleApp.xcodeproj/   # Xcode project files

.github/workflows/          # CI/CD configuration
├── swift_test_linux.yml   # Linux testing
├── swift_test_xcode_latest.yml  # macOS Xcode latest
└── swift_test_xcode_stable.yml  # macOS Xcode stable
```

### Important Files
- `Package.swift` - Swift Package Manager configuration with dependencies
- `.swift-version` - Swift 6.0 toolchain requirement
- `.swiftformat` - Code formatting rules (tool not installed)
- `Justfile` - Build automation (just tool not available on Linux)
- `AGENTS.md` - Agent workflow guidelines

## Common Tasks

### Package Information
```bash
# View package structure
swift package describe --type json | jq .

# Show dependencies
swift package show-dependencies

# Clean build artifacts
swift package clean
```

### Dependency Management
- **swift-syntax** (601.0.1+) - Required for macro implementation
- **swift-macro-testing** (0.6.3+) - Required for macro testing
- Dependencies resolve automatically during build

### Working with Macros
- Macro implementations are in `Sources/AwaitlessKitMacros/`
- Macro definitions are in `Sources/AwaitlessKit/AwaitlessKitMacros.swift`
- Core types are in `Sources/AwaitlessCore/`
- Always test macro changes with full test suite

### CI/CD Expectations
- All PRs must pass Linux and macOS tests
- Build and test times are consistent across platforms
- No formatting or linting checks in CI (tools not available)

## Platform Limitations

### Linux Environment
- ✅ Swift compilation and testing works fully
- ✅ Package builds and all tests pass
- ❌ SampleApp cannot be built (requires Xcode)
- ❌ SwiftFormat not installed (config exists)
- ❌ Just command runner not available
- ❌ No Xcode-specific tools

### macOS Environment (when available)
- ✅ Full Swift toolchain with Xcode integration
- ✅ SampleApp can be built and run
- ✅ Justfile automation available
- ✅ SwiftFormat available for code formatting

## Troubleshooting

### Build Issues
- If build fails with dependency resolution errors: `swift package clean && swift build`
- If macro compilation fails: check SwiftSyntax API compatibility
- Long build times are normal for initial builds (3+ minutes)

### Test Issues
- If tests fail to find modules: ensure `swift build` completed successfully
- Use `--filter` to isolate failing test suites
- Parallel testing is enabled by default and should work

### Environment Issues
- SampleApp build errors on Linux are expected - this is normal
- Missing tool errors (swiftformat, just) are expected on Linux
- Use test suite instead of SampleApp for validation on Linux

## Performance Expectations

### Build Times
- Initial build: 3-4 minutes (includes dependency resolution)
- Incremental builds: 10-30 seconds
- Clean builds: 2-3 minutes

### Test Times
- Full test suite: 35-60 seconds
- Filtered test suites: 1-5 seconds each
- Individual tests: Under 1 second

NEVER CANCEL builds or tests - wait for completion even if they appear to hang.