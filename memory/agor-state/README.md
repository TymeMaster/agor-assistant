# Agor State Cache

This directory is an ephemeral operational cache for Agor resources.

It is **not** persistent source of truth. The JSON files in this directory are gitignored by default and may be incomplete, stale, uncommitted, or specific to one session's short-term needs.

Use this cache for:
- Short-term handoff between sessions
- Controlled restart protection
- Temporary sharing of worktree/session IDs
- Local scratchpad notes that are useful right now but not worth promoting to persistent memory

Do not use it as the only input for critical orchestration decisions. Before acting on worktrees, sessions, boards, or repos, verify current state through Agor MCP. Persistent decisions and workflow state belong in git-tracked docs such as `MEMORY.md`, `memory/YYYY-MM-DD.md`, `TODO.md`, `repos/*.md`, and `skills/*.md`.

---

## Files

### repos.json
Optional local snapshot of configured repositories in Agor.

**Structure:**
```json
{
  "configured_repos": [
    {
      "repo_id": "UUIDv7",
      "name": "repo-name",
      "slug": "org/repo-name",
      "notes": "Optional context"
    }
  ],
  "last_updated": "ISO 8601 timestamp"
}
```

### worktrees.json
Optional local snapshot of active worktrees the agent is managing.

**Structure:**
```json
{
  "active_worktrees": [
    {
      "worktree_id": "UUIDv7",
      "name": "worktree-name",
      "purpose": "What this worktree is for",
      "repo_id": "UUIDv7",
      "created": "ISO 8601 timestamp",
      "notes": "Optional context"
    }
  ],
  "last_synced": "ISO 8601 timestamp"
}
```

### sessions.json
Optional local snapshot of active sessions and their genealogy (parent-child relationships).

**Structure:**
```json
{
  "tracked_sessions": [
    {
      "session_id": "UUIDv7",
      "purpose": "What this session is doing",
      "worktree_id": "UUIDv7 or null",
      "parent": "parent session_id or null",
      "created": "ISO 8601 timestamp",
      "status": "running | completed | failed",
      "notes": "Optional context"
    }
  ],
  "genealogy": {
    "session_id": {
      "parent": "parent_id or null",
      "children": ["child_id", ...],
      "depth": 0
    }
  },
  "last_synced": "ISO 8601 timestamp"
}
```

---

## Usage

The agent should:
1. **Initialize** these files during bootstrap (copy from .template files)
2. **Refresh** them when a short-term handoff/cache snapshot is useful
3. **Update** them after creating/modifying resources only if another session will benefit from the scratchpad
4. **Verify** current state via Agor MCP before making decisions

---

## Templates

The `.template` files show the structure. Copy and customize during bootstrap.
