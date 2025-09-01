# Agent Playbook

Authoritative guide for AI agents working in this repository. Follow this on every session.

## 0) Startup Checklist
- Read: `AGENTS.md`, `.github/pull_request_template.md`.
- Check open Issues and current milestone/labels: `gh issue list`.
- Confirm the task scope matches an existing Issue; otherwise create one.
- Sync `main` before branching: `git fetch origin && git checkout main && git pull --rebase`

## 1) Operating Mode
- Issue‑first: no work without an Issue. Link all branches/PRs to it.
- PR‑driven: no direct commits to `main`. Use small topic branches.
- Communicate: brief preambles and progress updates; keep users informed.

## 2) Branch & Commit
- Branch: `sr-XX/<topic>` (e.g., `sr-02/publisher-delivery`).
- Conventional commits: `feat(...)`, `fix(...)`, `chore(...)`, `docs(...)`, `test(...)`.
- Keep changes narrowly scoped to the Issue; avoid drive‑by changes.
- Always branch from up‑to‑date `main`. If drift occurs, `git fetch origin && git rebase origin/main` before pushing.

## 3) Pull Requests
- Open a Draft PR early: `gh pr create --title "SR-XX: <title>" --body "Closes #<n>\n\n<summary>" --draft`.
- Add labels (e.g., `sr-xx`, `feature`, `macros`, `cleanup`).
- Include tests and docs in the same PR when behavior changes.
- Keep diffs minimal and readable; explain the rationale in PR body.
- Merge strategy: squash merge after approval + green CI.

## 4) Testing & Build
- Run focused tests first: `swift test --filter '<Suite|Test>' -v`.
- Run full tests before marking PR Ready.
- Prefer surgical fixes; do not disable unrelated tests.

## 5) Documentation & Versioning
- Update README/examples when user‑facing APIs change.
- Note deprecations in PR body; remove them in a follow‑up SR.
- Follow SemVer when removing deprecated paths.

## 6) Labels & Status
- Use SR labels (`sr-01`..`sr-xx`) and domain labels (`macros`, `combine`, `cleanup`).
- Issues should have clear scope and acceptance criteria.

## 7) Safety & Secrets
- Never expose secrets/tokens. Use `gh` with configured auth.
- Avoid destructive commands (e.g., `git reset --hard`) unless explicitly requested.

## 8) Tooling
- Prefer `gh` for Issues/PRs. Example:
  - `gh issue create --title ... --body ... --label sr-xx,feature`
  - `gh pr create --draft --title ... --body ...`
  - `gh pr merge <num> --squash --delete-branch`

## 9) Finish & Handoff
- Merge or leave PR Ready with passing tests.
- Post concise next‑step suggestions (e.g., next SR).

