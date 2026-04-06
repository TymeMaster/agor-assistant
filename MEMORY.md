# MEMORY.md - Long-Term Memory

## Key Decisions

- **2026-03-28:** Bootstrap complete. Jarvis is the sole orchestrator on Baker Tyme — Features board. No duplicate assistants.
- **2026-03-29:** Model override NOT supported in Agor MCP - use agenticTool only. Opus sessions require manual GUI creation. Commit gate is orchestration-dependent: app workflow ends at reviewer approval, but Agor TL may need to execute the final commit when the reviewer is a non-commit-capable Codex session.
- **2026-03-29:** Git strategy for agor-assistant: maintain in separate branch (`assistent-baker-tyme`), no PRs to upstream. Fork is for our workspace config, not feature contributions.
- **2026-04-06:** baker-tyme branch baseline rule: normal feature/docs/chore work starts from `origin/develop`; `origin/main` is only for release-oriented flow, such as preparing release PRs from `develop` to `main`.

## Important Context

- **baker-tyme** is a Godot Android game (TymeMaster). Primary and only work repo for now.
- For **baker-tyme**, create normal worktrees from `origin/develop` by default. Do not use `origin/main` unless the task is explicitly release-related.
- Board workflow: Backlog → Architecture → WB—Areas → WB—Tasks → Development → Done
- Human wants full transparency in early stages. Autonomy increases gradually.
- Future plan: split baker-tyme into modular repos for cross-app reuse.

## Active Work

- **feat-walls** — ✅ DONE (2026-03-29). All 3 Areas complete, comprehensive test suite (335/335 passing), complete integration review approved. Ready for UAT and merge. Worktree moved to Done zone.
- **chore-agor-test** — early Agor testing worktree, likely can be cleaned up.
- **docs-reviewer-final-gate** — `baker-tyme` docs/process cleanup branch. Recreated on top of `origin/develop` after the initial `origin/main` baseline mistake. Current remote branch `origin/docs-reviewer-final-gate` has commits `82c5dad` (branch baseline/PR target rules) and `bb255e4` (reviewer final gate). Backup of old `origin/main`-based version: `backup/docs-reviewer-final-gate`.

## Orchestration Model (decided 2026-04-04)

**3-Layer Architecture** — full design in `memory/2026-04-04-orchestration-design.md`

| Layer | Role | Model | Behavior |
|-------|------|-------|----------|
| 1 | Orchestrator (Jarvis) | Opus (manual GUI) | PASSIVE — delegates, never implements |
| 2a | Team Lead (per Area) | Sonnet | AUTONOMOUS — owns Area, delegates, and provides commit-capable fallback |
| 2b | Project Manager | Sonnet | Heartbeat controller, pushes stalled TLs |
| 3 | Workers | Sonnet (dev) / Codex (review) | Execute tasks in isolated worktrees |

**Primary constraint:** Token optimization. Opus stays thin, Sonnet coordinates, Codex analyzes.

**PM triggering:** Manual (by Opus or human) via `agor_sessions_prompt`. Automated cron not available (5 mechanisms tested, all failed — see design doc).

**Experimentally verified (2026-04-04):**
- Sonnet sessions have full Agor MCP access (38 tools) ✅
- Callback chain TL → Worker → TL works (< 60s) ✅
- PM can poll session status + push stalled sessions ✅

**Commit Gate:**
- baker-tyme workflow ends at reviewer approval and final review artifact
- Commit-capable reviewers may commit their own approved outputs
- If the reviewer is Codex, Team Lead executes the final commit on the reviewer's approved output
- Codex cannot commit (sandbox limitation)

**Context Exhaustion:** TL persists state to file → escalates to Opus → Opus creates replacement TL with resumé → updates PM with new session ID

## Open Process Follow-ups

- PM cron/manual trigger wording: operational docs now use manual PM triggering, but `memory/2026-04-04-orchestration-design.md` still contains original cron-based design language in historical sections. Decide whether to annotate as superseded or update for consistency.
- Agor state sync freshness: run `skills/agor-state-sync.md` and update `memory/agor-state/*.json` when appropriate.
- `docs-reviewer-final-gate`: after merge/closure, clean up `backup/docs-reviewer-final-gate` and the worktree if no longer needed.

**Session Start Checklist:**
1. Read SOUL.md, IDENTITY.md, USER.md, BOARD.md
2. Read today + yesterday daily logs
3. Sync Agor state (worktrees, sessions)
4. Check relevant repos/ context files

## Preferences Discovered

- Czech for human communication, English for everything in repos and agent prompts
- Address human as "šéfe" but don't overuse it
- Proactive suggestions welcome, but explain before acting
- No POC/hello-world test needed — human verified session setup manually
