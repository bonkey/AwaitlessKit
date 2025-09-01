# AwaitlessKit — Feature Tracks and Task Breakdown

Purpose: Capture small, well‑scoped, independently shippable tasks for upcoming features you approved. Each track lists goals, API sketch, acceptance criteria, and a step‑by‑step plan you can take in separate sessions.

---

## 1) Macro Split: Split Publisher from Sync

- Goal: Split the single `@Awaitless` entry point into three explicit macros for clarity, discoverability, and future growth.
- New Public Macros (SR‑01 scope):
  - `@Awaitless` – generates synchronous wrappers only (status quo for sync generation).
  - `@AwaitlessPublisher` – generates Combine publisher wrappers.
  - Note: `@AwaitlessCompletion` will be added in SR‑03 (not part of SR‑01).
- Migration Strategy:
  - Keep `@Awaitless(as: .publisher|.completionHandler)` working for one transition release.
  - SR‑01: Emit deprecation diagnostics only for `@Awaitless(as: .publisher)` → suggest `@AwaitlessPublisher`.
  - SR‑03: Add `@AwaitlessCompletion` and then emit deprecation diagnostics for `@Awaitless(as: .completionHandler)`.
  - Update README/tests/examples to the new APIs; maintain a “legacy usage” section during the transition.
- Compatibility: No behavioral change for existing code; only new warnings when `as:` is used.

Tasks
- API Surface: Add `@AwaitlessPublisher` entry point in `AwaitlessKitMacros.swift` (public interface).
- Parsing/Codegen: Factor common generation into shared helpers; `@AwaitlessPublisher` selects publisher path.
- Diagnostics: Add deprecation only for `@Awaitless(as: .publisher)` in SR‑01; keep completion handler path untouched for now.
- Tests: Duplicate key snapshot cases using `@AwaitlessPublisher`; keep a small legacy suite covering `as: .publisher` + deprecation.
- Docs: Update examples; add a migration note and quick‑fix section for publisher split.

Acceptance Criteria
- `@Awaitless` (sync) and `@AwaitlessPublisher` compile and generate expected code paths with existing tests adapted.
- Using `@Awaitless(as: .publisher)` produces clear, actionable deprecation diagnostics; `.completionHandler` remains non‑deprecated in SR‑01.
- README shows new publisher usage; legacy section covers the transition window.

---

## 2) Publisher Delivery Control

- Goal: Allow `@Awaitless(as: .publisher)` to optionally control delivery context for UI and non‑UI consumers.
- API Sketch: `@AwaitlessPublisher(deliverOn: .main | .current)`
  - New core enum: `AwaitlessDelivery { case main, current }`
  - Semantics:
    - `.main`: append `.receive(on: DispatchQueue.main)` to the produced publisher.
    - `.current` (or omitted): no `.receive(on:)` is added; delivery occurs on the context used by the internal `Task` (status quo).
- Non‑Goals (initial): custom schedulers, run loops, arbitrary queues, or Rx interop.
- Compatibility: No breaking changes; parameter is optional. Still respects `canImport(Combine)` guard.
- Notes: Keep it Combine‑only; where Combine is unavailable, reuse existing diagnostic.

Tasks
- Core type: Add `AwaitlessDelivery` (Core).
- Macro parsing: Accept labeled arg `deliverOn: .main | .current` in `@AwaitlessPublisher` (Macros).
- Codegen: In publisher body, append `.receive(on: DispatchQueue.main)` when `.main` is set; omit for `.current` (Macros).
- Tests: Macro expansion snapshots covering throwing/nonthrowing, with/without prefix, and `deliverOn: .main` vs `.current` (Tests).
- Docs: README examples and a short migration note (Docs).

Acceptance Criteria
- Builds on Apple platforms with Combine; emits existing diagnostic when Combine is missing.
- Snapshot tests show `.receive(on: DispatchQueue.main)` only for `deliverOn: .main`; no `.receive(on:)` for `.current`/omitted.
- No API changes for existing usage; no additional allocations when `deliverOn` is omitted.

---

## 3) Completion Handler Output (Result)

- Goal: Generate legacy completion‑handler wrappers for async functions to aid incremental migration.
- API Sketch: `@AwaitlessCompletion`
  - For `async throws -> T`: `func f(..., completion: @escaping (Result<T, Error>) -> Void)`
  - For `async -> T`: `func f(..., completion: @escaping (Result<T, Error>) -> Void)` (always `.success` in v1)
  - For `async -> Void`: `func f(..., completion: @escaping (Result<Void, Error>) -> Void)`
  - Implementation uses `Task { ... }` (non‑blocking) and calls completion with `.success`/`.failure`.
- Non‑Goals (initial): overloading for non‑Result signatures, multiple completion styles, ObjC interop.
- Compatibility: Names and argument labels match the original; adds a new overload not requiring `throws`.
- Notes: Prefer uniform `Result<T, Error>` even for non‑throwing to simplify call sites.

Tasks
- Core: No new output case if split; provide dedicated macro that generates the completion handler variant.
- Macro parsing: Support any needed labeled args (future‑proofing); v1 has none.
- Signature synthesis: Add trailing `completion:` param; no `async`/`throws` in wrapper (Macros).
- Body generation: Wrap original call in `Task { ... }` and route to `completion` (Macros).
- Tests: Snapshot expansions for throwing, non‑throwing, `Void`, and prefixed names (Tests).
- Docs: Examples + guidance on migration sequencing (Docs).

Acceptance Criteria
- Generated functions compile and call through correctly in unit tests.
- Snapshot tests validate exact signatures and bodies.
- Non‑blocking behavior (no use of `Noasync.run` in this output mode).

---

## 4) Config Defaults (Discuss Separately)

- Goal: Provide opt‑in defaults for teams without linting: prefix, default output type, and delivery.
- Initial Direction: Type‑scoped `@AwaitlessConfig` attribute (vs. true module‑global) for feasibility.
- Open Questions: Macro lookup of nearest enclosing config; override precedence; per‑file alternative via freestanding directive.

Exploration Tasks
- Design: Two prototypes — type‑scoped `@AwaitlessConfig(...)` and file‑scoped `#awaitless(config: ...)`.
- Feasibility: Confirm MacroExpansionContext access to ancestors or alternate discovery strategy.
- DX Spec: Precedence rules (attribute arg > type config > file config), diagnostics, and examples.
- RFC: Write a short design doc and pick one approach.

---

## 5) Safety: Deadlock Guards, Timeouts (Discuss Separately)

- Goal: Best‑effort safety tools for `Noasync.run` without guaranteeing correctness.
- Candidates:
  - Timeout: `Noasync.run(timeout: Duration?, ...)` cancels the inner task and throws `NoasyncError.timeout`.
  - Main‑thread guard: Optional assert/warn when calling from main thread and suspected main‑actor work.
  - Cancellation bridging: If outer Task is cancelled, cancel the inner detached work.
  - Diagnostics: Opt‑in debug logging for blocked durations over a threshold.

Exploration Tasks
- API design: `Noasync.Policy` (timeouts, logging, guards) vs. `run` parameters.
- Prototyping: Implement timeout + cancellation first; measure overhead on hot paths.
- Tests: Deterministic time‑based tests using small durations; ensure no leaks.
- Docs: Prominent caveats; migration‑only positioning.

---

## Suggested Sequence (Small, Shippable Steps)

1) Macro split (Publisher from Sync)
   - Introduce `@AwaitlessPublisher`; keep `@Awaitless` for sync only; deprecate `as: .publisher` usage.
2) Publisher delivery (.main | .current) in `@AwaitlessPublisher`
   - Low risk, contained change; immediate UI value.
3) Completion handler (Result) — add `@AwaitlessCompletion`
   - Introduce macro; then deprecate `as: .completionHandler` usage.
4) Remove deprecated `@Awaitless(as: ...)` code paths
   - After SR‑03 ships, delete legacy `as:` handling and tests; update docs accordingly.
5) Config defaults (type‑scoped)
   - Requires design agreement; implement after a brief RFC.
6) Safety (timeouts/guards)
   - Prototype behind flags; iterate with caution.

---

## Session‑Ready Work Items

SR‑01 Macro Split (Publisher from Sync)
- Add `@AwaitlessPublisher`; keep `@Awaitless` for sync.
- Add deprecation diagnostics for `@Awaitless(as: .publisher)` with guidance.
- Update core tests and README; keep a minimal legacy test suite for `.publisher` during transition.
- Exit: New publisher macro validated; legacy publisher path warns but works.

SR‑02 Publisher Delivery (.main | .current)
- Implement `AwaitlessDelivery` + parsing in `@AwaitlessPublisher` + codegen + tests + docs.
- Exit: New examples in README; green tests.

SR‑03 Completion Handler Output (Result)
- Introduce `@AwaitlessCompletion` and generate signatures/bodies + tests + docs.
- Add deprecation diagnostics for `@Awaitless(as: .completionHandler)`.
- Exit: Snapshot tests cover 4 shapes (throw/non‑throw/Void/prefix); migration note present.

SR‑04 Deprecation Removal (Post SR‑03)
- Remove `@Awaitless(as: .publisher | .completionHandler)` parsing and code paths.
- Delete legacy snapshot tests and examples that rely on `as:`.
- Update README to drop legacy usage; keep a CHANGELOG entry and migration note.
- Consider a minor/major version bump aligned with SemVer expectations.
- Exit: No references to legacy `as:` flows; CI stays green.

SR‑05 Config Defaults (Design RFC)
- 2–3 page doc comparing type‑scoped vs. file‑scoped; choose one.
- Exit: Approved direction + sketched API.

SR‑06 Noasync Safety Prototype
- Add timeout param + cancellation; behind feature flag.
- Exit: Basic tests passing; perf note recorded.
