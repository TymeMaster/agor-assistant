# MEMORY.md - Long-Term Memory

## Key Decisions

- **2026-03-28:** Bootstrap complete. Jarvis is the sole orchestrator on Baker Tyme — Features board. No duplicate assistants.
- **2026-03-29:** Model override NOT supported in Agor MCP - use agenticTool only. Opus sessions require manual GUI creation. Commit gate: orchestrator commits, workers don't.
- **2026-03-29:** Git strategy for agor-assistant: maintain in separate branch (`assistent-baker-tyme`), no PRs to upstream. Fork is for our workspace config, not feature contributions.

## Important Context

- **baker-tyme** is a Godot Android game (TymeMaster). Primary and only work repo for now.
- Board workflow: Backlog → Architecture → WB—Areas → WB—Tasks → Development → Done
- Human wants full transparency in early stages. Autonomy increases gradually.
- Future plan: split baker-tyme into modular repos for cross-app reuse.

## Active Work

- **feat-walls** — ✅ DONE (2026-03-29). All 3 Areas complete, comprehensive test suite (335/335 passing), complete integration review approved. Ready for UAT and merge. Worktree moved to Done zone.
- **chore-agor-test** — early Agor testing worktree, likely can be cleaned up.

## Workflow Rules

**Role-Model Mapping:**
- Architect: claude-opus-4-6 (manual GUI creation)
- Analyst: Codex (process review, consistency analysis)
- Developer: claude-sonnet-4-5 (cost-efficient implementation)
- Reviewer: Codex (thorough structured review)

**Commit Gate:**
- Board assistant or subsessions commit ALL code
- Worker sessions (Developer/Reviewer) produce code, never commit
- Avoids Codex sandbox git limitations

**Subsession Best Practices:**
- Use for parallel analytical work (research, review, analysis)
- Codex excellent for structured analysis without tool use
- Enable callback for completion notification
- Spawn creates child with fresh context

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
