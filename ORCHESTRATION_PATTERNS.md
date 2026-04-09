# Orchestration Patterns for AI Workflow

> Guidance for Board Assistant when orchestrating multi-session AI workflows through Agor MCP.

## 3-Layer Orchestration Model

All AI work follows a 3-layer delegation model. Full design details in `memory/2026-04-04-orchestration-design.md`.

```
Human Leader
  │  (minimal: Opus model switch + answer open arch decisions)
  ▼
Layer 1: OPUS ORCHESTRATOR (Jarvis) — PASSIVE
  │  Delegates work, never implements. Communication gate with human.
  │
  ├── Layer 2b: SONNET PM — EVENT-DRIVEN + MANUAL FALLBACK
  │     Monitors TL progress, pushes stalled sessions.
  │     Activated by TL status reports (normal) or Opus/human sweep (fallback).
  │     Escalates to Opus after 2x failed push.
  │
  ├── Layer 2a: SONNET ARCH-TL (Architecture phase) — AUTONOMOUS
  │     │  Full ownership of Architecture phase lifecycle.
  │     │  Runs in the feature worktree (no separate worktree).
  │     │  Escalates to Jarvis only for Opus model switch + human Q&A.
  │     │  Commits arch + review artifacts on completion.
  │     │
  │     ├── Layer 3: Opus Worker (Architect — model switched manually by human)
  │     └── Layer 3: Codex Worker (Architecture Reviewer)
  │
  ├── Layer 2a: SONNET TL (per Area, post-WB) — AUTONOMOUS
  │     │  Full ownership of one Area. Delegates to worker subsessions, owns all git commits.
  │     │  Codex workers cannot commit — TL always performs the final commit.
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
| **Arch-TL owns Architecture phase** | Spawns architect + reviewer, manages Q&A relay, commits artifacts — Jarvis stays passive |
| **Reviewer is the final gate** | App workflow ends at reviewer approval and review artifact, not orchestration details |
| **TL is the commit fallback** | If a Codex reviewer cannot commit, TL executes the final git commit on the approved output |
| **Codex can't commit** | Sandbox limitation — every branch needs ≥1 Sonnet session |
| **PM is event-driven** | TLs push status reports after each task; Opus/human trigger fallback sweeps when no reports arrive |
| **Token optimization** | Primary design constraint — Opus stays thin, Sonnet coordinates |
| **Workflow gate compliance** | Before any phase transition, read the relevant `AI_WORKFLOW__*_TASK.md` and verify all artifacts exist |

### Skills for Spawning

- **Arch Team Lead:** [`skills/spawn-arch-team-lead.md`](skills/spawn-arch-team-lead.md) — architecture phase lifecycle, Opus model relay, reviewer spawn, commit
- **Area Team Lead:** [`skills/spawn-team-lead.md`](skills/spawn-team-lead.md) — prompt template, TL session setup in existing feature worktree, error handling
- **Project Manager:** [`skills/spawn-project-manager.md`](skills/spawn-project-manager.md) — prompt template, triggering cadence, push protocol

### Context Exhaustion Recovery

When a TL runs out of context:
1. TL persists state to `ai/tasks/<feature>-tl-state.md`
2. TL reports: "Context exhausted, state at [path]"
3. Orchestrator creates replacement TL with state file as context
4. Orchestrator updates PM with new TL session ID

### Commit Fallback Protocol

When TL delegates the final review to a Codex reviewer:
1. TL tells the reviewer in the prompt that TL retains the git commit responsibility
2. Reviewer produces the final review artifact and approval/rejection verdict
3. If approved, TL applies any required final adjustments and performs the git commit
4. TL records in the summary that commit ownership was retained due to Codex sandbox limits

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
For spawn failures (worker subsession):
  - Retry sessions_spawn once (keeps TL genealogy intact)
  - If retry fails: use sessions_create in the same feature worktree as last resort (breaks genealogy — log explicitly)
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
- **Orchestrator**: track TL session IDs in daily log (TL is long-lived, needs monitoring)
- **TL**: track worker outcomes (summary + commit SHA), not worker session IDs (workers are ephemeral)

**Isolation Boundaries:**
- New feature/fix: NEW feature worktree + TL session (sessions_create) in that worktree
- Worker tasks within a feature: spawn subsession (sessions_spawn) inside TL session — NOT new worktrees
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
