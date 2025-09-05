# AwaitlessKit

AwaitlessKit is a Swift package providing macros to automatically generate synchronous wrappers for async/await functions, enabling easy migration to Swift 6 Structured Concurrency with both APIs available.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Prerequisites

- Swift 6.0+ compiler required
- This package works on Linux and macOS
- Do NOT install mise or just tools, but do use Justfile CONTENTS to identify commands to run, so if instructions say "just test", check the contents of Justfile for "test" command contents and run it without just.

### Bootstrap and Build

- `cd /path/to/AwaitlessKit` - always work from repository root
- `just build` - builds all targets including macros. Takes 3+ minutes initially. NEVER CANCEL. Set timeout to 10+ minutes.
- `swift package resolve` - resolves dependencies if needed (normally automatic)

### Testing

- `just test` - runs full test suite. Takes 35-60 seconds. NEVER CANCEL. Set timeout to 5+ minutes.
- `just test TestSuiteName` - runs specific test suite
- All tests should pass on Linux and macOS

### Code Validation

- `just fmt` - formats code using SwiftFormat
- CI runs on Linux and macOS with GitHub Actions

## Validation Scenarios

### Core Macro Functionality Testing

After making changes to macro code, always validate by:

1. `just build` - ensure macros compile without errors
2. `just test` - run full test suite (tests are fast, no need to filter)

### Integration Testing

- SampleApp is an Xcode project located in `SampleApp/` directory
- **SampleApp CANNOT be built or run on Linux** - requires Xcode and macOS
- Use test suite instead of SampleApp for validation on Linux systems
- SampleApp demonstrates real-world usage patterns for documentation

**Note**:

- The @Awaitless macro only works on class/struct methods, not global functions
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
- `.swiftformat` - Code formatting rules
- `.tool-versions` - Tool version specifications for mise
- `Justfile` - Build automation
- `AGENTS.md` - Agent workflow guidelines

## Common Tasks

### Package Information

```bash
# View package structure
just package-info

# Show dependencies
just package-deps

# Clean build artifacts
just clean
```

### Working with Macros

- Macro implementations are in `Sources/AwaitlessKitMacros/`
- Macro definitions are in `Sources/AwaitlessKit/AwaitlessKitMacros.swift`
- Core types are in `Sources/AwaitlessCore/`
- Always test macro changes with full test suite

### CI/CD Expectations

- All PRs must pass Linux and macOS tests
- Build and test times are consistent across platforms
- Formatting checks via SwiftFormat (installed via mise)

## Platform Limitations

### Linux Environment

- ✅ Swift compilation and testing works fully
- ✅ Package builds and all tests pass
- ✅ Tools available via mise (swiftformat, just)
- ❌ SampleApp cannot be built (requires Xcode)

### macOS Environment (when available)

- ✅ Full Swift toolchain with Xcode integration
- ✅ SampleApp can be built and run
- ✅ All tools available via mise

## Troubleshooting

### Build Issues

- If build fails with dependency resolution errors: `just clean`
- If macro compilation fails: check SwiftSyntax API compatibility
- Long build times are normal for initial builds (3+ minutes)

### Test Issues

- If tests fail to find modules: ensure `just build` completed successfully
- Use `<FILTER>` in `just test <FILTER>` to isolate failing test suites
- Parallel testing is enabled by default and should work

### Environment Issues

- SampleApp build errors on Linux are expected - this is normal
- Missing tool errors (swiftformat, just) are not expected on Linux, `mise install` should resolve it
- Use test suite instead of SampleApp for validation on Linux

## Performance Expectations

### Build Times

- Initial build: 3-4 minutes (includes dependency resolution)
- Incremental builds: 10-30 seconds
- Clean builds: 2-3 minutes

### Test Times

- Full test suite: 35-60 seconds
- Individual tests: Under 1 second

You can kill swift processes to cancel tests or builds after a few minutes and retry if needed.

## RFC Writing Guidelines

When creating or updating RFCs (Request for Comments) in the `/RFC` directory, follow this structure based on the comprehensive SR-05 example:

### RFC Document Structure

1. **Header Section**
   - RFC number and title
   - Status (Draft, Review, Approved, Rejected)
   - Author and date
   - Brief summary paragraph

2. **Problem Statement**
   - Clear description of the problem being solved
   - Current pain points with concrete examples
   - Impact metrics (e.g., "90% configuration boilerplate")

3. **Solution Overview** 
   - High-level description of the recommended approach
   - Key benefits and impact
   - Simple before/after examples

4. **Approaches Evaluated**
   - Document 3-4 different approaches considered
   - Each approach should include:
     - Design description with code examples
     - Detailed pros and cons analysis
     - Technical feasibility assessment
     - Implementation complexity notes

5. **Recommended Solution**
   - Clear rationale for the chosen approach
   - Address why other approaches were not selected
   - Technical implementation strategy
   - Migration path for existing code

6. **API Surface Design**
   - Complete API definitions with types and signatures
   - Usage examples covering common scenarios
   - Edge cases and error handling

7. **Implementation Strategy**
   - Phased implementation plan
   - Technical challenges and solutions
   - Integration with existing systems

8. **Comparison Matrix**
   - Table comparing all evaluated approaches
   - Objective criteria for evaluation
   - Clear winner identification

9. **Decision and Next Steps**
   - Formal decision statement
   - Implementation phases
   - Success criteria

### RFC Best Practices

- **Single File**: Consolidate all related content into one comprehensive document
- **Concrete Examples**: Use realistic code examples throughout
- **Quantified Benefits**: Include metrics like "90% reduction in boilerplate"
- **Technical Honesty**: Document limitations and challenges honestly
- **Migration Focus**: Always include migration strategy for existing users
- **Comparison Driven**: Evaluate multiple approaches objectively
- **Implementation Ready**: Include enough detail for implementers to proceed

### RFC Process

1. Create RFC document in `/RFC` directory with descriptive filename
2. Update `/RFC/README.md` index with new RFC entry
3. Use the RFC for design discussions before implementation
4. Keep RFC updated as decisions evolve
5. Mark status as "Approved" when ready for implementation

RFCs should be design-only documents. Implementation work should be tracked separately in issues after RFC approval.
