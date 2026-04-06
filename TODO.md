# TODO - Board Assistant Process Improvements

**Last Updated:** 2026-04-06

---

## ⏳ Fáze 2: Process Hardening (Zbývá)

### Review Cleanup Follow-ups (2026-04-06)

Status from workflow cleanup review:
- ✅ Commit gate inconsistency resolved: `baker-tyme` app workflow now treats reviewer as the final gate; Agor orchestration handles Codex commit fallback via TL.
- ✅ `origin/main` baseline mistake resolved for `docs-reviewer-final-gate`: intended changes were reapplied on top of `origin/develop`, backup branch preserved as `backup/docs-reviewer-final-gate`.
- ✅ Integration-review workflow reference is no longer blocking for normal work because `origin/develop` contains the workflow docs that `main` lacked.
- ✅ PM cron/manual trigger wording resolved: `memory/2026-04-04-orchestration-design.md` now marks cron as a failed original hypothesis and uses manual PM heartbeat trigger in the operational design sections.
- ⏳ Agor state snapshot freshness still needs a state sync pass.

Next actions:
- Process `baker-tyme` branch `docs-reviewer-final-gate` against `develop`.
- After merge/closure, clean up `backup/docs-reviewer-final-gate` and the worktree.
- Run `skills/agor-state-sync.md` and commit updated state if appropriate.

### B3. Hygiene Gates - Integration Review ✅ DONE (2026-04-04)

Pre-review checklist already present in `AI_WORKFLOW__INTEGRATION_REVIEW_TASK.md` (added during 2026-04-03 session).

### B4. Rate Limit Pre-Flight Integration ✅ DONE (2026-04-04)

Integrated `scripts/check-rate-limit.sh` into orchestration workflow:
- `ORCHESTRATION_PATTERNS.md` — new "Rate Limit Pre-Flight" section with action matrix
- `AGENTS.md` — step 0 in coding work isolation pattern, step 9 in session start checklist
- Skill reference: `skills/check-rate-limit.md`

---

### A1. Agor State Sync at Session Start ✅ DONE (2026-04-03)

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

### Memory Promotion Process ✅ DONE (2026-04-03)

Added to HEARTBEAT.md as weekly task with concrete steps.

---

**Notes:**
- Agor MCP was disconnected during 2026-04-03 session (couldn't spawn subsessions)
- B3 was planned as Codex subsession but fell back to TODO due to MCP unavailability
- A1 requires design discussion before implementation
