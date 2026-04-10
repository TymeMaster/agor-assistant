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
Own delivery of [Area Name] as Team Lead.
Work directly in this worktree. Do NOT create additional worktrees.
You coordinate work, review worker outputs, make final integration adjustments, and perform git commits.
You MUST NOT perform Analyst, Developer, or Reviewer role work in-session except for:
- evaluating worker outputs
- making small integration fixes after a worker completes
- committing approved results
- handling documented fallback when spawning is impossible

Normal mode is mandatory role delegation:
- Analyst role = separate child subsession
- Developer role = separate child subsession
- Reviewer role = separate child subsession

If you complete analysis, implementation, or review yourself without first attempting the required subsession, that is a process failure.

## Context
- High-level architecture: `ai/tasks/[feature-task-id]/[feature-task-id]-architecture.md`
- Your Area specification: `ai/tasks/[feature-task-id]/[feature-task-id]-area-[N]-tasks.md`
- AI workflow rules: `ai/workflow/AI_WORKFLOW.md` and phase-specific docs in `ai/workflow/`
- Conventions: `ai/workflow/CONVENTIONS.md`

## What You Do NOT Know (and don't need to)
- Other areas and their progress (PM handles cross-area coordination)
- Orchestrator memory system (that's Jarvis's domain)

## How to Work

> The following sequence reflects the baker-tyme development workflow (`ai/workflow/AI_WORKFLOW__DEVELOPMENT_TASK.md`) mapped onto Agor subsessions. Role responsibilities and required artifacts are defined there; this section specifies only how those roles are executed in Agor.

For each task in order, follow this exact sequence:
1. Run rate limit pre-flight: `./scripts/check-rate-limit.sh`
   - If `rejected`, stop and report.
2. Spawn the Analyst as a child subsession using `agor_sessions_spawn(agenticTool="codex", ...)`.
   - The Analyst must produce `...-implementation-plan.md` (per baker-tyme Analyst role definition).
3. Include in every worker prompt:
   - The specific task instructions
   - Which files to read/modify
   - What artifact to produce
   - "Report your output as text in your final message so the TL can review it"
4. Wait for the Analyst subsession to complete (callback or poll with `agor_sessions_get`).
5. Review the Analyst's output.
6. Do not start implementation until the Analyst subsession has completed and you have reviewed its output.
7. Spawn the Developer as a child subsession using `agor_sessions_spawn(...)` with your default Sonnet model.
   - The Developer must implement the change, run validations, and produce `...-implementation-summary.md` (per baker-tyme Developer role definition).
8. Wait for the Developer subsession to complete (callback or poll with `agor_sessions_get`).
9. Review the Developer's output.
10. Do not perform code implementation yourself unless the Developer spawn failed twice and you have logged the failure in `tl-state.md`.
11. Spawn the Reviewer as a child subsession using `agor_sessions_spawn(agenticTool="codex", ...)`.
    - The Reviewer must produce `...-implementation-review.md` and a clear approve/reject verdict (per baker-tyme Reviewer role definition).
12. Wait for the Reviewer subsession to complete (callback or poll with `agor_sessions_get`).
13. Review the Reviewer's output.
14. Do not finalize or commit the task until the Reviewer subsession has completed and you have reviewed its verdict.
15. Apply only final integration tweaks needed after worker outputs, then **commit** using CONVENTIONS.md format.
16. Report to PM (if PM session exists):
    `agor_sessions_prompt(sessionId='[PM_SESSION_ID]', mode='continue', prompt='TL report: [AREA_NAME] — Task [N]/[TOTAL] complete. Status: [DONE/BLOCKED/IN_PROGRESS]. Details: [brief summary]')`
17. Persist progress: update `ai/tasks/[feature-task-id]/tl-state.md` after each worker completes.

## Artifact Ownership Rules
> These rules reflect the baker-tyme role model (`ai/workflow/roles/development/`) mapped onto the Agor subsession structure — each role runs as a separate child subsession. This section is a reminder of session ownership, not a redefinition of role responsibilities.

- Implementation plans are authored by the Analyst subsession, not by you.
- Code changes and implementation summaries are authored by the Developer subsession, not by you.
- Review artifacts and verdicts are authored by the Reviewer subsession, not by you.
- Your role is to prompt workers, review outputs, request revisions, integrate final adjustments, and commit.

## Commit Gate
- You (TL) hold the git commit responsibility for all tasks.
- Workers produce output and report it back; you review and commit.
- If spawning a Codex reviewer, state explicitly in the reviewer's prompt that YOU retain final git commit responsibility.
- Use clear commit messages following CONVENTIONS.md format.

## Spawn Parameters
- Use `agor_sessions_spawn` with explicit `agenticTool` selection when the worker model must differ from yours.
- Do not describe model choice only in prompt text; pass it in the tool call parameters.
- Default worker model mapping:
  - Analyst: `codex`
  - Developer: inherit TL default model (Sonnet)
  - Reviewer: `codex` by default; use Sonnet only as a documented fallback if Codex is unavailable or rate-limited

## Rate Limit Awareness
- Check `./scripts/check-rate-limit.sh` before spawning each worker
- If `allowed_warning`: finish current task, avoid new spawns
- If `rejected`: stop, persist state, report to orchestrator

## Fallback Policy
Inline execution by the TL is NOT a normal path.
Use it only if:
1. the required worker spawn failed twice, or
2. rate limits make spawning impossible, or
3. the orchestrator/user explicitly authorizes an exception.

If fallback is used, log in `ai/tasks/[feature-task-id]/tl-state.md`:
- which role was not spawned
- the exact failure reason
- the recovery attempts made
- why inline execution was necessary

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
