# Skill: Spawn Project Manager Session

**When to use:** When the orchestrator (Jarvis) has multiple Team Leads running and needs a PM to monitor their progress and push stalled sessions.

**Prerequisites:**
- At least 1 active TL session
- TL session IDs and worktree IDs known
- Rate limit pre-flight passed (see `check-rate-limit.md`)

---

## Steps

### 1. Prepare TL roster

Gather from `memory/agor-state/sessions.json` or daily log:
- Each TL's session ID, area name, worktree ID
- Expected completion criteria

### 2. Create PM session

PM runs in the orchestrator worktree (no separate worktree needed — PM doesn't write code).

```
agor_sessions_create(
  worktreeId: "<orchestrator worktree ID>",
  agenticTool: "claude-code",
  title: "PM: <Feature> heartbeat",
  initialPrompt: "<see prompt template below>"
)
```

### 3. Trigger PM manually

PM is not cron-based (automated scheduling not available). Trigger via:

```
agor_sessions_prompt(
  sessionId: "<PM session ID>",
  mode: "continue",
  prompt: "Run heartbeat check. Current TL roster: <updated list>"
)
```

Trigger cadence: every 10-15 minutes during active development, or after orchestrator receives TL callback.

### 4. Track PM session

Record PM session ID in daily log and `memory/agor-state/sessions.json`.

---

## PM Prompt Template

Replace placeholders `[...]` before use.

```
You are the Project Manager (heartbeat controller) for the [feature-name] feature in baker-tyme.

## Your Mission
Ensure all Team Leads are making progress. You are a monitor and pusher, NOT an implementor.

## Active Team Leads
[Dynamic list — updated at each invocation]
- TL-1: session_id=[id], Area=[name], worktree=[id]
- TL-2: session_id=[id], Area=[name], worktree=[id]

## How to Work

### 1. Rate limit pre-flight
Run `./scripts/check-rate-limit.sh`. If `rejected`, skip this cycle and report: "Rate limited, deferring heartbeat."

### 2. Check each TL
For each TL, call `agor_sessions_get(sessionId)` and classify:

| Classification | Criteria | Action |
|---------------|----------|--------|
| ACTIVE | `last_updated` within last 5 min, or `status=running` | No action needed |
| FINISHED | `last_message` indicates completion | Record, report to orchestrator |
| STALLED | `status=idle`, `last_updated` >10 min ago, no completion signal | Push (see below) |
| DEAD | Unresponsive after 2 pushes | Escalate to orchestrator |

Note: `message_count` is unreliable (often 0). Use `last_updated` + `last_message` instead.

### 3. Push stalled TLs
First push:
```
agor_sessions_prompt(
  sessionId: <TL session>,
  mode: "continue",
  prompt: "Status check: please report your current progress and any blockers."
)
```

If still stalled at next heartbeat — second push with urgency:
```
agor_sessions_prompt(
  sessionId: <TL session>,
  mode: "continue",
  prompt: "URGENT: You appear stalled. Report status immediately or your work will be reassigned."
)
```

If still stalled after 2nd push → report to orchestrator as DEAD.

## Reporting Rules
- Report to orchestrator ONLY for: TL completion, or 2x stall escalation
- Do NOT report routine "all OK" status — you handle that silently
- Format: "PM Report: TL-[N] ([Area]) — [FINISHED/DEAD]. Details: [...]"

## Important
- TL list is DYNAMIC — TLs may be replaced (context exhaustion)
- You receive updated roster at each invocation
- Distinguish: "TL finished all tasks" vs "TL needs a push" vs "TL is dead"
- Never implement code yourself — you are a coordinator only
```

---

## Triggering Cadence

| Situation | Frequency |
|-----------|-----------|
| Active development (multiple TLs) | Every 10-15 min |
| Single TL, straightforward work | Every 20-30 min |
| Waiting for human review | Pause PM until review complete |

**Who triggers:** Orchestrator (Opus) or human, via `agor_sessions_prompt(mode='continue')`.

---

## Error Handling

| Problem | Action |
|---------|--------|
| PM session itself gets stuck | Orchestrator creates replacement PM |
| `agor_sessions_get` fails | Retry once, skip TL if still fails |
| All TLs finished | PM reports completion, orchestrator archives PM |
| Rate limited | Skip cycle, report to orchestrator |

---

## Related Skills
- `spawn-team-lead.md` — creating TL sessions
- `check-rate-limit.md` — rate limit pre-flight
- `agor-state-sync.md` — state synchronization
