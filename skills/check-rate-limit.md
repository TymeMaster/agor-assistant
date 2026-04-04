# Skill: Check Rate Limit

**When to use:**
- Before spawning new worker sessions (pre-flight check)
- In PM heartbeat to decide whether to push stalled TLs or wait
- When orchestrator needs to decide between Opus vs Sonnet vs defer
- On user request ("how much budget do we have?")
- After a session fails with rate limit error

**Prerequisites:**
- `claude` CLI available in PATH
- `/tmp` directory writable (used as clean cwd to avoid CLAUDE.md overhead)

---

## Quick Reference

```bash
# JSON output (for programmatic use)
./scripts/check-rate-limit.sh

# Human-readable (for logging / user display)
./scripts/check-rate-limit.sh --human
```

Cost: ~$0.02 per call (single Haiku request via standard mode).

---

## Steps (for agent use)

### 1. Run the utility

```bash
RATE_JSON=$(./scripts/check-rate-limit.sh 2>/dev/null)
```

If it fails (exit code 1), log the error and assume **unknown state** — do not assume OK.

### 2. Parse the result

JSON fields (vary by state — not all fields present in every response):

| Field | Values | Meaning |
|-------|--------|---------|
| `status` | `allowed` / `allowed_warning` / `rejected` | 5-hour window status |
| `rateLimitType` | `five_hour` | Always this value |
| `resetsAt` | unix timestamp | When 5h window resets |
| `utilization` | 0.0–1.0 (optional) | Usage fraction; present in `allowed_warning` state |
| `surpassedThreshold` | 0.0–1.0 (optional) | Warning threshold crossed; present in `allowed_warning` |
| `isUsingOverage` | `true` / `false` | Currently in overage zone |
| `overageStatus` | `allowed` / `rejected` (optional) | Weekly/billing limit; absent in `allowed_warning` |
| `overageResetsAt` | unix timestamp (optional) | When weekly limit resets; absent in `allowed_warning` |

### 3. Decide action based on state

| State | Detection | Action |
|-------|-----------|--------|
| **OK** | `status=allowed`, `isUsingOverage=false` | Normal operation — spawn freely |
| **Warning** | `status=allowed_warning` | Conserve — finish in-progress work, avoid new spawns, prefer cheap models |
| **Overage** | `isUsingOverage=true`, `overageStatus=allowed` | Conserve — prefer Sonnet/Haiku, batch work, avoid exploratory spawns |
| **5h limit hit** | `status=rejected`, `overageStatus=allowed` | Minimal ops only — finish in-progress work, no new spawns, wait for reset |
| **All exhausted** | `status=rejected`, `overageStatus=rejected` | Full stop — log state, notify user, defer all work |
| **Unknown** | Script failed or unrecognized status | Treat as Warning (cautious but not blocked) |

### 4. Log the result

Add to daily log:

```
[HH:MM] Rate limit check: <STATE> (5h resets in Xh Ym, overage: yes/no)
```

---

## Integration Points

**PM Heartbeat:** Check before prompting any TL. If limited, skip the push cycle.

**Orchestrator (Jarvis):** Check before creating worktree + session for coding work.

**Worker sessions:** Workers don't need to check — they'll hit the limit naturally and the error is visible in session status.

---

## Implementation Notes

- Script runs `claude -p` from `/tmp` — this avoids CLAUDE.md pickup which would cause agent startup behavior and timeout
- Cannot use `--bare` flag — it suppresses `rate_limit_event` from stream output
- The `rate_limit_event` is emitted as a separate JSON line in `stream-json` verbose output
- Rate limit status reflects state AFTER the probe request was processed

---

## Related

- `scripts/check-rate-limit.sh` — the underlying utility
- `ORCHESTRATION_PATTERNS.md` — where rate limit checks fit in orchestration flow
- `memory/2026-04-04-orchestration-design.md` — token optimization as primary constraint (D1)
