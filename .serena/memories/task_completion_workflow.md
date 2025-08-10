# AwaitlessKit Task Completion Workflow

## When a Task is Completed

### 1. Code Quality Checks
Run these commands in order:

1. **Format Code**
   ```bash
   just fmt
   ```
   - Formats all Swift files according to project standards
   - Must be run before committing

2. **Build Project**
   ```bash
   just build
   ```
   - Ensures code compiles without errors
   - Validates macro syntax and dependencies

3. **Run Tests**
   ```bash
   just test
   ```
   - Runs comprehensive test suite
   - Includes macro expansion tests
   - Validates both functionality and generated code

### 2. Additional Validation (if applicable)

4. **Test Sample App** (for major changes)
   ```bash
   just run-and-build-sample-app
   ```
   - Validates integration with real Xcode project
   - Tests actual macro behavior in practice

5. **Clean Build** (for release preparation)
   ```bash
   just clean
   just build
   ```
   - Ensures clean compilation from scratch
   - Validates no hidden dependencies

### 3. Documentation Updates
- Update README.md if public API changes
- Update DocC comments for new features
- Verify examples in documentation still work

### 4. Version Management
- Update version numbers if needed
- Update changelog or release notes
- Consider deprecation warnings for breaking changes

### 5. Quality Gates
- All tests must pass
- Code must be properly formatted
- No compiler warnings (the project uses strict settings)
- Sample app must build and run successfully

## Pre-Commit Checklist
- [ ] Code formatted with `just fmt`
- [ ] All tests pass with `just test`
- [ ] Clean build succeeds
- [ ] Documentation updated if needed
- [ ] No new compiler warnings