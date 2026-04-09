# Skill: Spawn Team Lead Session

**When to use:** When the orchestrator (Jarvis) needs to delegate an Area's implementation to an autonomous Team Lead.

**Prerequisites:**
- Architecture and work breakdown completed for the feature
- Area specification document exists in the feature worktree
- Rate limit pre-flight passed (see `check-rate-limit.md`)
- Feature worktree already exists (TL runs IN the feature worktree — no separate TL worktree)
- Board ID and repo ID known (from IDENTITY.md)

---

## Model

The TL runs **directly in the existing feature worktree** as a `sessions_create` session. Workers are spawned as `sessions_spawn` child subsessions inside the TL's session — no additional worktrees are created.

```
Feature Worktree
  └── TL Session (sessions_create)
        ├── Worker: Analyst/Reviewer (sessions_spawn child)
        ├── Worker: Developer (sessions_spawn child)
        └── Worker: Reviewer (sessions_spawn child)
```

Key consequences:
- TL can commit directly — no cherry-pick needed
- Workers are subsessions; they cannot commit (Codex sandbox limitation)
- Only the TL's session needs tracking in `memory/agor-state/`
- Worker sessions are ephemeral — track by task outcome, not by session ID

---

## Steps

### 1. Create TL session in the feature worktree

```
agor_sessions_create(
  worktreeId: "<feature worktree ID>",
  agenticTool: "claude-code",
  title: "TL: <Feature> Area <N> — <Area Name>",
  initialPrompt: "<see prompt template below>"
)
```

Record the returned `session_id`.

### 2. Track in orchestrator memory

Update the daily log with:
- TL session ID, feature worktree ID, area name
- Feature context (which feature, which area)
- Timestamp

Also update `memory/agor-state/sessions.json` if another session needs a short-term handoff cache.

---

## TL Prompt Template

Replace placeholders `[...]` before use.

```
You are a Team Lead for [Area Name] in the [feature-name] feature of the baker-tyme project.

## Your Mission
Complete all implementation tasks for [Area Name] as defined in the specification below.
Work directly in this worktree. Do NOT create additional worktrees.

## Context
- High-level architecture: `ai/tasks/[feature-task-id]/[feature-task-id]-architecture.md`
- Your Area specification: `ai/tasks/[feature-task-id]/[feature-task-id]-area-[N]-tasks.md`
- AI workflow rules: `ai/workflow/AI_WORKFLOW.md` and phase-specific docs in `ai/workflow/`
- Conventions: `ai/workflow/CONVENTIONS.md`

## What You Do NOT Know (and don't need to)
- Other areas and their progress (PM handles cross-area coordination)
- Orchestrator memory system (that's Jarvis's domain)

## How to Work

For each task in order:
1. Run rate limit pre-flight: `./scripts/check-rate-limit.sh` — if `rejected`, stop and report
2. Spawn worker as **child subsession** using `agor_sessions_spawn`:
   - Analysis/planning tasks → include `agenticTool: "codex"` in the spawn prompt context
   - Development tasks → subsession inherits your model (Sonnet)
   - Review tasks → subsession inherits your model or use Codex; see Commit Gate below
3. Include in the worker prompt:
   - The specific task instructions
   - Which files to read/modify
   - What artifact to produce
   - "Report your output as text in your final message so the TL can review it"
4. Wait for the worker subsession to complete (callback or poll with `agor_sessions_get`)
5. Review the worker's output
6. Apply any final adjustments and **commit** using CONVENTIONS.md format
7. Report to PM (if PM session exists):
   `agor_sessions_prompt(sessionId='[PM_SESSION_ID]', mode='continue', prompt='TL report: [AREA_NAME] — Task [N]/[TOTAL] complete. Status: [DONE/BLOCKED/IN_PROGRESS]. Details: [brief summary]')`
8. Persist progress: update `ai/tasks/[feature-task-id]/tl-state.md` after each task

## Commit Gate
- You (TL) hold the git commit responsibility for all tasks.
- Workers produce output and report it back; you review and commit.
- If spawning a Codex reviewer, state explicitly in the reviewer's prompt that YOU retain final git commit responsibility.
- Use clear commit messages following CONVENTIONS.md format.

## Rate Limit Awareness
- Check `./scripts/check-rate-limit.sh` before spawning each worker
- If `allowed_warning`: finish current task, avoid new spawns
- If `rejected`: stop, persist state, report to orchestrator

## Context Exhaustion Protocol
If your conversation becomes too long and efficiency degrades:
1. Write comprehensive state summary to `ai/tasks/[feature-task-id]/tl-state.md`
2. Include: completed tasks, in-progress task, remaining tasks, any blockers
3. Report: "Context exhausted, state persisted at ai/tasks/[feature-task-id]/tl-state.md"
The orchestrator will create a replacement TL with your state file as context.
```

---

## Error Handling

| Problem | Action |
|---------|--------|
| Worker subsession stuck (no progress >5 min) | Prompt worker: `agor_sessions_prompt(sessionId, mode='continue', prompt='Status?')` |
| Worker fails after 2 prompts | Abandon worker, spawn replacement subsession |
| Rate limit hit mid-area | Persist state, stop, wait for orchestrator/PM |
| Worker cannot commit | Expected — TL always commits, worker reports output only |

---

## What Changed vs. Old Model

The previous model created a separate worktree per Area and additional worker worktrees per task. This caused:
- Cherry-pick complexity (TL had to move changes across worktrees)
- Workers committed to wrong branch or not at all (Codex sandbox)
- Excessive worktree proliferation, hard to track

The new model: **one feature worktree, TL as `sessions_create`, workers as `sessions_spawn` subsessions.**

---

## Related Skills
- `check-rate-limit.md` — rate limit pre-flight
- `agor-state-sync.md` — optional local cache refresh
- `spawn-project-manager.md` — PM that monitors TLs
- `spawn-arch-team-lead.md` — Architecture phase TL (different pattern)
