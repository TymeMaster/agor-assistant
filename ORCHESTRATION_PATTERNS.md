# Orchestration Patterns for AI Workflow

> Guidance for Board Assistant when orchestrating multi-session AI workflows through Agor MCP.

## 3-Layer Orchestration Model

All AI work follows a 3-layer delegation model. Full design details in `memory/2026-04-04-orchestration-design.md`.

```
Human Leader
  │
  ▼
Layer 1: OPUS ORCHESTRATOR (Jarvis) — PASSIVE
  │  Delegates work, never implements. Communication gate with human.
  │
  ├── Layer 2b: SONNET PM — MANUAL TRIGGER
  │     Monitors TL progress, pushes stalled sessions.
  │     Triggered by Opus or human (no automated cron available).
  │     Escalates to Opus after 2x failed push.
  │
  ├── Layer 2a: SONNET TL (per Area) — AUTONOMOUS
  │     │  Full ownership of one Area. Delegates to workers, commits results.
  │     │  Persists state to file for context exhaustion resilience.
  │     │
  │     ├── Layer 3: Codex Worker (analysis/review)
  │     ├── Layer 3: Sonnet Worker (development)
  │     └── Layer 3: Codex Worker (integration review)
  │
  └── Layer 2a: SONNET TL (another Area) — same structure
```

### Key Rules

| Rule | Detail |
|------|--------|
| **Opus is passive** | Never polls, never monitors — only reacts to callbacks/prompts |
| **TL commits all code** | Workers produce changes, TL reviews and commits (commit gate) |
| **Codex can't commit** | Sandbox limitation — every branch needs ≥1 Sonnet session |
| **PM triggers manually** | Via `agor_sessions_prompt(mode='continue')` by Opus or human |
| **Token optimization** | Primary design constraint — Opus stays thin, Sonnet coordinates |

### Skills for Spawning

- **Team Lead:** [`skills/spawn-team-lead.md`](skills/spawn-team-lead.md) — prompt template, worktree setup, error handling
- **Project Manager:** [`skills/spawn-project-manager.md`](skills/spawn-project-manager.md) — prompt template, triggering cadence, push protocol

### Context Exhaustion Recovery

When a TL runs out of context:
1. TL persists state to `ai/tasks/<feature>-tl-state.md`
2. TL reports: "Context exhausted, state at [path]"
3. Orchestrator creates replacement TL with state file as context
4. Orchestrator updates PM with new TL session ID

---

## Subsession Health Checks

### Post-Spawn Verification (30-60s timeout)

When you spawn a subsession, verify it's alive within 30-60 seconds:

**Check pattern:**
1. Immediately after spawn, note session_id and timestamp
2. Wait 30-60 seconds
3. Call `agor_sessions_get(sessionId)`
4. Verify: `message_count > 0` OR tool activity visible
5. If still 0 messages/0 tools -> mark as stalled

**Stalled session indicators:**
- `message_count: 0` after 60s
- `status: "idle"` with no task progress
- No tool uses recorded

**Recovery actions:**
- Check Agor logs: `agor_environment_logs`
- Try prompt to existing session: `agor_sessions_prompt`
- If unrecoverable: spawn replacement session
- Document incident in daily log

### Continuous Monitoring

For long-running subsessions (>5min):
- Periodic health check every 2-3 minutes
- Verify message_count increments
- Check `last_updated` timestamp advances

## Orchestration Failure Recovery

### Common Failure Modes

**1. sessions_spawn / sessions_create fails**
- Error: DB insert failure, task creation error
- Symptom: API returns error, no session created

**2. sessions_prompt fails**
- Error: Task insert failure, routing error
- Symptom: Prompt not delivered, session stuck

**3. Session callback never arrives**
- Error: Silent failure, session completed but no callback
- Symptom: Waiting indefinitely for completion

### Failure Recovery Playbook

**Step 1: Retry Once (immediate)**
```text
If spawn/create/prompt fails:
  1. Log the error details
  2. Wait 2-3 seconds
  3. Retry the same operation once
  4. If succeeds -> continue normally
  5. If fails again -> proceed to Step 2
```

**Step 2: Alternative Path**
```text
For spawn failures:
  - Try sessions_create in existing worktree instead
  - Or: do the work inline (if analytical task)

For prompt failures:
  - Try direct session access via sessions_get
  - Check if session is actually responsive
  - Consider manual prompt via UI

For callback failures:
  - Poll session status: sessions_get every 30s
  - Check message_count and last_updated
  - Timeout after 5min, escalate to user
```

**Step 3: Manual Escalation**
```text
If automated recovery fails:
  1. Document the failure in daily log:
     - Operation attempted
     - Error received
     - Recovery steps tried
  2. Notify user via AskUserQuestion:
     - Explain what failed
     - Provide session/worktree IDs
     - Suggest manual intervention
  3. Provide fallback plan
```

### Logging Failures

Every orchestration failure should be logged:
```text
memory/YYYY-MM-DD.md:

## Orchestration Failure: [operation]
- Time: [timestamp]
- Operation: agor_sessions_spawn / create / prompt
- Error: [error message]
- Context: [what you were trying to do]
- Recovery: [what you tried]
- Outcome: [success / escalated to user]
```

## Rate Limit Pre-Flight

Before spawning sessions or creating worktrees for coding work, check rate limit status. This prevents wasted resources when the API is throttled.

**Skill reference:** [`skills/check-rate-limit.md`](skills/check-rate-limit.md)

### When to Check

| Actor | When | How |
|-------|------|-----|
| Orchestrator (Opus) | Before creating worktree + session | `./scripts/check-rate-limit.sh` |
| PM (Sonnet) | Before each push cycle | `./scripts/check-rate-limit.sh` |
| TL (Sonnet) | Before spawning worker sessions | `./scripts/check-rate-limit.sh` |
| Workers | Never (they hit limits naturally) | — |

### Action Matrix

| State | Detection | Action |
|-------|-----------|--------|
| **OK** | `status=allowed`, no overage | Proceed normally |
| **Warning** | `status=allowed_warning` | Finish in-progress work, avoid new spawns, prefer cheap models |
| **Overage** | `isUsingOverage=true`, `overageStatus=allowed` | Conserve — batch work, avoid exploratory spawns |
| **5h limit** | `status=rejected`, `overageStatus=allowed` | Minimal ops only — no new spawns, wait for reset |
| **All exhausted** | `status=rejected`, `overageStatus=rejected` | Full stop — notify user, defer all work |
| **Unknown** | Script failed | Treat as Warning (cautious) |

### Integration Pattern

```bash
# In orchestrator/TL/PM before spawning work:
RATE_JSON=$(./scripts/check-rate-limit.sh 2>/dev/null)
STATUS=$(echo "$RATE_JSON" | jq -r '.status')

if [ "$STATUS" = "rejected" ]; then
  # Log and skip — do not spawn
  echo "Rate limited, deferring work"
  exit 0
fi

if [ "$STATUS" = "allowed_warning" ]; then
  # Conserve — only proceed if work is critical
  echo "Rate warning — proceeding with caution"
fi
```

### Logging

Add to daily log after each check:
```
[HH:MM] Rate limit: <STATE> (resets in Xh Ym, overage: yes/no)
```

---

## Session Genealogy Best Practices

**Parent-Child Relationships:**
- Spawn subsessions for parallel research/analysis
- Enable callback for completion notification
- Track child session IDs in parent's daily log

**Isolation Boundaries:**
- Coding work: NEW worktree + NEW session (sessions_create)
- Research work: spawn subsession in current context
- Alternative exploration: fork from decision point

**Callback Management:**
- `enableCallback: true` for async work
- `includeLastMessage: true` for result payload
- Handle callbacks gracefully (may arrive late)

## When to Escalate vs. Retry

**Retry automatically:**
- Single API failures (spawn, create, prompt)
- Transient network issues
- Health check shows session recovering

**Escalate to user:**
- Repeated failures (2+ retries)
- Unknown error types
- Session stuck with blocking work
- Manual intervention needed (e.g., permissions, GitHub auth)

**Never:**
- Silently fail and continue (always log + handle)
- Infinite retry loops (max 2 attempts)
- Abandon work without documenting why
