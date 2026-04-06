# Skill: Agor State Sync

**When to use:** When a session needs a short-term local snapshot for handoff, controlled restart protection, or temporary shared state.

**Purpose:** Refresh `memory/agor-state/` as an ephemeral operational cache. This cache is not persistent source of truth and may be incomplete/stale between refreshes. Before making critical orchestration decisions, query Agor MCP directly.

**Prerequisites:**
- Agor MCP tools available (`agor_worktrees_list`, `agor_sessions_list`, `agor_repos_list`)
- `IDENTITY.md` read (need Main Board ID)

---

## Steps

### 1. Fetch current state from Agor MCP

Run all three calls:

```
agor_worktrees_list          → all worktrees (no filter)
agor_sessions_list           → status: "running" (call 1)
                               status: "idle" (call 2)
                               ⚠️ Do NOT use boardId filter — it returns empty data (known bug)
                               Filter by board locally in step 3 instead
agor_repos_list              → all repos
```

**Failure rule:** If ANY call fails or returns empty results unexpectedly, do NOT overwrite the existing JSON. Log the failure in the daily log and proceed by querying Agor MCP directly as needed. Never write an empty or partial snapshot.

### 2. Prepare `worktrees.json`

Schema: separate MCP snapshot from local annotations.

```json
{
  "last_synced": "<ISO 8601 UTC timestamp>",
  "active_worktrees": [
    {
      "worktree_id": "<from MCP>",
      "name": "<from MCP>",
      "repo_slug": "<derived: repo name from MCP>",
      "board_id": "<from MCP>",
      "zone_id": "<from MCP, null if none>",
      "zone_label": "<from MCP, null if none>",
      "git_ref": "<from MCP ref field>",
      "notes": "<from MCP notes field, null if none>"
    }
  ],
  "annotations": {
    "<worktree_id>": {
      "purpose": "<manually maintained — short description of why this worktree exists>"
    }
  }
}
```

**Merge rule for annotations:** When rewriting the file, carry over existing `annotations` entries by `worktree_id`. If a worktree no longer exists in MCP snapshot, move its annotation to `archived_annotations` (keep for reference). Never discard annotations during sync.

### 3. Prepare `sessions.json`

Schema: clean snapshot of active sessions only. No history in this file.

```json
{
  "last_synced": "<ISO 8601 UTC timestamp>",
  "active_sessions": [
    {
      "session_id": "<from MCP>",
      "title": "<from MCP>",
      "worktree_id": "<from MCP>",
      "worktree_name": "<look up from worktrees snapshot — saves lookup later>",
      "agentic_tool": "<from MCP: claude-code / codex>",
      "status": "<from MCP: running / idle>",
      "last_updated": "<from MCP>",
      "parent_session_id": "<from MCP genealogy, null if root>"
    }
  ]
}
```

**Filter steps:**
1. Status filter: Include only `running` and `idle` sessions (fetched separately in step 1)
2. Board filter: Filter by `board_id` field matching Main Board ID from IDENTITY.md
   - Sessions without `board_id` → exclude
   - Sessions with different `board_id` → exclude
   - Sessions with matching `board_id` → include

**Why local filtering:** `agor_sessions_list` boardId parameter returns empty data (confirmed bug 2026-04-03). Call without filter, filter locally instead.

**Dedup rule:** If same `session_id` appears in both running and idle results, keep one entry (prefer running status).

### 4. Prepare `repos.json`

```json
{
  "last_synced": "<ISO 8601 UTC timestamp>",
  "repos": [
    {
      "repo_id": "<from MCP>",
      "name": "<from MCP>",
      "slug": "<from MCP: org/repo>",
      "default_branch": "<from MCP>"
    }
  ],
  "annotations": {
    "<repo_id>": {
      "local_path": "<manually maintained>",
      "notes": "<manually maintained>"
    }
  }
}
```

### 5. Validate before writing

Before overwriting any file, verify:
- `active_worktrees` array is non-empty (or explicitly zero if that's correct)
- `last_synced` timestamp is current (not copied from old file)
- JSON is valid

Then write all three files atomically (write all or none — if one write fails, note it in daily log).

### 6. Log the cache refresh

Add to today's daily log (`memory/YYYY-MM-DD.md`):

```
[HH:MM] Agor state cache refreshed: N worktrees, N sessions (running: X, idle: Y), N repos
```

If any fetch failed: `[HH:MM] Agor state cache refresh PARTIAL: worktrees OK, sessions FAILED (stale cache retained)`

---

## Outputs

- `memory/agor-state/worktrees.json` — updated
- `memory/agor-state/sessions.json` — updated
- `memory/agor-state/repos.json` — updated
- Daily log entry with sync summary

---

## Error Handling

| Situation | Action |
|---|---|
| MCP call fails (network/timeout) | Keep existing file, log failure, continue session |
| MCP returns empty array unexpectedly | Keep existing file, log warning |
| worktree exists in file but not in MCP | Remove from `active_worktrees`, move annotation to `archived_annotations` |
| New worktree in MCP not in file | Add to `active_worktrees`, no annotation needed initially |
| Session in file not in MCP | Remove from `active_sessions` (completed/failed, no longer tracked) |

---

## Phase 2 (future)

If cache refresh becomes frequent or schemas drift, replace manual steps 2–5 with a small script. The skill then becomes: "run the script, verify output, log result." Keep this skill as the spec.

---

**Related:** AGENTS.md "Every Session" checklist, IDENTITY.md (board ID), ORCHESTRATION_PATTERNS.md
