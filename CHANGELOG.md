# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed
- **BREAKING CHANGE**: Removed deprecated `@Awaitless(as: .publisher|.completion)` syntax. Use the dedicated `@AwaitlessPublisher` and `@AwaitlessCompletion` macros instead.
- Removed `AwaitlessOutputType` enum as it's no longer needed.
- Removed deprecation warning diagnostics for the old `as:` parameter.

### Changed
- **BREAKING CHANGE**: Refactored `AwaitlessAttachedMacro` into three dedicated macro types:
  - `AwaitlessSyncMacro` for `@Awaitless`
  - `AwaitlessPublisherMacro` for `@AwaitlessPublisher`
  - `AwaitlessCompletionMacro` for `@AwaitlessCompletion`
- Extracted shared functionality into `AwaitlessMacroHelpers` to eliminate code duplication.
- Eliminated conditional logic based on attribute names, providing clearer separation of concerns.

### Developer Notes
This release completes the removal of deprecated legacy syntax as outlined in SR-04. The codebase is now cleaner with dedicated macro types and no dual API paths.