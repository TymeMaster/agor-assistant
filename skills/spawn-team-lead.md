# Skill: Spawn Team Lead Session

**When to use:** When the orchestrator (Jarvis) needs to delegate an Area's implementation to an autonomous Team Lead.

**Prerequisites:**
- Architecture and work breakdown completed for the feature
- Area specification document exists in the worktree
- Rate limit pre-flight passed (see `check-rate-limit.md`)
- Board ID and repo ID known (from IDENTITY.md)
- For baker-tyme normal feature/docs/chore work, use `origin/develop` as the source branch. Use `origin/main` only for explicit release-oriented work.

---

## Steps

### 1. Create isolated worktree for the Area

```
agor_worktrees_create(
  repoId: "<baker-tyme repo ID>",
  worktreeName: "<feature>-area-<N>",
  boardId: "<main board ID>",
  createBranch: true,
  sourceBranch: "origin/develop"
)
```

Record the returned `worktree_id`.

For release-oriented work only, choose the release-specific source branch intentionally instead of the normal `origin/develop` baseline.

### 2. Create TL session in the worktree

```
agor_sessions_create(
  worktreeId: "<worktree_id from step 1>",
  agenticTool: "claude-code",
  title: "TL: <Feature> Area <N> — <Area Name>",
  initialPrompt: "<see prompt template below>"
)
```

Record the returned `session_id`.

### 3. Track in orchestrator memory

Update `memory/agor-state/sessions.json` and daily log with:
- TL session ID, worktree ID, area name
- Feature context (which feature, which area)
- Timestamp

---

## TL Prompt Template

Replace placeholders `[...]` before use.

```
You are a Team Lead for [Area Name] in the [feature-name] feature of the baker-tyme project.

## Your Mission
Complete all implementation tasks for [Area Name] as defined in the specification below.

## Context
- High-level architecture: `ai/tasks/[feature]-architecture.md`
- Your Area specification: `ai/tasks/[feature]-area-[N]-tasks.md`
- AI workflow rules: `ai/workflow/AI_WORKFLOW.md` and phase-specific docs in `ai/workflow/`
- Conventions: `ai/workflow/CONVENTIONS.md`

## What You Do NOT Know (and don't need to)
- Other areas and their progress (PM handles cross-area coordination)
- Orchestrator memory system (that's Jarvis's domain)

## How to Work
1. Read your Area specification thoroughly
2. For each task in order:
   a. Run rate limit pre-flight: `./scripts/check-rate-limit.sh` — if `rejected`, stop and report
   b. Create worker worktree: `agor_worktrees_create(repoId='[repoId]', worktreeName='[feature]-area[N]-task[M]', boardId='[boardId]', createBranch=true)`
   c. Create worker session: `agor_sessions_create(worktreeId=<new>, agenticTool=<see below>, initialPrompt=<task prompt>)`
      - Analysis/review tasks → agenticTool: "codex"
      - Development tasks → agenticTool: "claude-code" (Sonnet)
      - If spawning a Codex reviewer, state explicitly in the prompt that YOU retain final git commit responsibility
   d. Monitor worker: check `agor_sessions_get(sessionId)` — verify `last_updated` advances
   e. When worker is done: review output in the worker worktree
   f. Cherry-pick or apply changes to YOUR worktree, then commit
3. After each completed task, persist progress to `ai/tasks/[feature]-tl-state.md`

## Commit Gate
- The app workflow ends at reviewer approval and final review artifact.
- Commit-capable reviewers may commit their own approved outputs.
- If the reviewer is Codex, YOU retain final git commit responsibility and must say so in the reviewer prompt.
- Codex workers cannot commit (sandbox limitation).
- Use clear commit messages following CONVENTIONS.md format.

## Rate Limit Awareness
- Check `./scripts/check-rate-limit.sh` before spawning each worker
- If `allowed_warning`: finish current task, avoid new spawns
- If `rejected`: stop, persist state, report to orchestrator

## Context Exhaustion Protocol
If your conversation becomes too long and efficiency degrades:
1. Write comprehensive state summary to `ai/tasks/[feature]-tl-state.md`
2. Include: completed tasks, in-progress task, remaining tasks, any blockers
3. Report: "Context exhausted, state persisted at ai/tasks/[feature]-tl-state.md"
The orchestrator will create a replacement TL with your state file as context.
```

---

## Error Handling

| Problem | Action |
|---------|--------|
| Worker session stuck (no progress >5 min) | Prompt worker: `agor_sessions_prompt(sessionId, mode='continue', prompt='Status?')` |
| Worker fails after 2 prompts | Abandon worker, create replacement session |
| Rate limit hit mid-area | Persist state, stop, wait for orchestrator/PM |
| Worktree creation fails | Retry once, then report to orchestrator |

---

## Related Skills
- `check-rate-limit.md` — rate limit pre-flight
- `agor-state-sync.md` — state synchronization
- `spawn-project-manager.md` — PM that monitors TLs
