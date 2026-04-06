# Skill: Spawn Project Manager Session

**When to use:** When the orchestrator (Jarvis) has multiple Team Leads running and needs a PM to monitor their progress and push stalled sessions.

**Prerequisites:**
- At least 1 active TL session
- TL session IDs and worktree IDs known
- Rate limit pre-flight passed (see `check-rate-limit.md`)

---

## Steps

### 1. Prepare TL roster

Gather from daily log, current Agor MCP state, or `memory/agor-state/sessions.json` if a fresh cache/handoff snapshot exists:
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

### 3. PM activation

PM is **event-driven**, not periodic. It activates in two ways:

1. **TL status reports (normal flow):** TLs send reports after each completed worker task via `agor_sessions_prompt`. PM processes the report and updates internal state.
2. **Manual stall detection sweep (fallback):** Human or Opus triggers PM for a full sweep of all TLs when no TL reports have arrived for an extended period.

Manual trigger format (for fallback sweeps):
```
agor_sessions_prompt(
  sessionId: "<PM session ID>",
  mode: "continue",
  prompt: "Stall detection sweep. Current TL roster: <updated list>"
)
```

### 4. Track PM session

Record PM session ID in daily log. Also update `memory/agor-state/sessions.json` if another session needs a short-term handoff cache.

---

## PM Prompt Template

Replace placeholders `[...]` before use.

```
You are the Project Manager (heartbeat controller) for the [feature-name] feature in baker-tyme.

## Your Mission
Ensure all Team Leads are making progress. You are a monitor and pusher, NOT an implementor.

## Activation Model
You are EVENT-DRIVEN, not periodic. You activate when:
1. A TL sends you a status report (normal flow) → process the report, update your internal state, respond only if action needed
2. Human or Opus triggers you for stall detection sweep (fallback) → run full sweep of all TLs

## Active Team Leads
[Dynamic list — updated at each invocation]
- TL-1: session_id=[id], Area=[name], worktree=[id]
- TL-2: session_id=[id], Area=[name], worktree=[id]

## How to Work

### When activated by TL report
1. Parse the report: `TL report: [AREA] — Task [N]/[TOTAL] complete. Status: [STATUS]. Details: [...]`
2. Update your internal tracking for that TL
3. If Status is BLOCKED → push the TL for details, consider escalating
4. If all TLs report DONE for all tasks → report completion to orchestrator
5. No further action needed for normal DONE/IN_PROGRESS reports

### When activated for stall detection sweep

#### 1. Rate limit pre-flight
Run `./scripts/check-rate-limit.sh`. If `rejected`, skip this cycle and report: "Rate limited, deferring heartbeat."

#### 2. Check each TL
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

PM is primarily activated by TL reports (push model). Manual fallback sweeps are needed only when TL reports stop arriving.

| Trigger source | When | Purpose |
|----------------|------|---------|
| TL status report | After each completed worker task | Normal progress tracking |
| Human/Opus manual sweep | No TL reports for >15-20 min | Stall detection fallback |
| Human/Opus manual sweep | After orchestrator receives TL callback | Opportunistic full check |

**Normal flow:** TLs push reports → PM processes them reactively. No periodic polling needed.
**Fallback:** If no reports arrive for 15-20 min, human or Opus triggers a full sweep via `agor_sessions_prompt(mode='continue')`.

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
- `agor-state-sync.md` — optional local cache refresh
