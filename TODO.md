# TODO - Board Assistant Process Improvements

**Last Updated:** 2026-04-03

---

## ⏳ Fáze 2: Process Hardening (Zbývá)

### B3. Hygiene Gates - Integration Review 🟡 MEDIUM

**What:** Add pre-review checklist to Integration Review workflow

**Where:** `baker-tyme/chore-agor-test/ai/workflow/AI_WORKFLOW__INTEGRATION_REVIEW_TASK.md`

**Content to add:**
```markdown
## Pre-Review Checklist

Before starting integration review, verify worktree cleanliness:

- [ ] Run `git status` - check for unstaged/untracked files
- [ ] Categorize unstaged files:
  - Related to current area → stage and include in review
  - Unrelated artifacts → stash, commit separately, or delete
  - Build artifacts (translations, .uid) → usually safe to leave unstaged
- [ ] Document exceptions: if leaving files unstaged, note why in review

**Stash strategy:**
- Named stash: `git stash push -m "Area N deferred items" file1 file2`
- Retrieve later: `git stash list`, `git stash apply stash@{N}`

**Separate commit strategy:**
- Create WIP commit for orphaned files: `git commit -m "WIP: orphaned files from Area N"`
- Mark for manual review during UAT

**Delete strategy:**
- Only delete if certain file is stale/wrong
- Prefer stash over delete (recoverable)
```

**Effort:** ~15 minutes (inline edit)

**Why:** During feat-walls, dirty worktree carried files across areas → confusion, commit risk. Hygiene gate prevents this.

---

### A1. Agor State Sync at Session Start 🔴 HIGH

**What:** Automate sync of `memory/agor-state/*.json` when session starts

**Current state:**
- AGENTS.md line 87 says "sync Agor state at session start"
- BUT: not automated, files go stale
- Claude analysis (2026-03-29) found stale timestamps

**Design decision needed:**

**Option A: Skill** (`skills/agor-state-sync/`)
- Create skill with SKILL.md
- Orchestrator calls skill manually at session start
- PRO: explicit control, easy to debug
- CON: manual step (can be forgotten)

**Option B: Hook** (settings.json)
- Add `user-prompt-submit-hook` or session-start equivalent
- Auto-runs sync on every session start
- PRO: fully automated, never forget
- CON: adds latency to every session start

**Option C: Manual pattern in AGENTS.md**
- Document pattern: "First thing: run agor_worktrees_list, update worktrees.json"
- No automation, just guidance
- PRO: simple, no infrastructure
- CON: manual, can be skipped

**Recommendation:** Option A (Skill) - balance of automation and control

**Implementation:**
1. Create `skills/agor-state-sync/SKILL.md`
2. Document:
   - When to use (every session start)
   - Steps: call agor_worktrees_list, agor_sessions_list, update JSON files with timestamp
   - Error handling
3. Update AGENTS.md "Every Session" section to reference skill
4. Test in next session

**Effort:** ~30-45 minutes

**Why:** Stale state tracking undermines reliability. Sessions should start with accurate Agor resource state.

---

## ✅ Fáze 1: COMPLETE (2026-04-03)

- ✅ ORCHESTRATION_PATTERNS.md created (Codex subsession)
- ✅ 4x workflow docs updated with Commit Responsibility
- ✅ ORCHESTRATION_PATTERNS moved to agor-assistant (correct location)
- ✅ AGENTS.md linked to ORCHESTRATION_PATTERNS
- ✅ repos/TymeMaster-baker-tyme.md created (comprehensive context)

---

## ✅ Fáze 0: Initial Analysis (2026-03-29)

- ✅ Subsession testing (3x subsessions: Codex, Claude, Claude)
- ✅ Model override investigation (not supported, documented)
- ✅ Workflow rules finalized (role-model mapping, commit gate)
- ✅ Git infrastructure setup (origin, upstream, SSH)
- ✅ feat-walls development complete (moved to Done)

---

## 📋 Backlog - Fáze 3 (Long-term)

### Memory Promotion Process

**What:** Weekly review of `memory/learnings/*.md` → extract to `MEMORY.md`

**Where:** HEARTBEAT.md (add weekly task guidance)

**Why:** Prevent learnings from staying buried in daily logs, promote to long-term memory

**Effort:** ~20 minutes (documentation)

---

**Notes:**
- Agor MCP was disconnected during 2026-04-03 session (couldn't spawn subsessions)
- B3 was planned as Codex subsession but fell back to TODO due to MCP unavailability
- A1 requires design discussion before implementation
