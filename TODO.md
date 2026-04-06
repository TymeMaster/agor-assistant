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
- ✅ Agor state snapshot freshness resolved as policy: `memory/agor-state/*.json` is an ephemeral operational cache, not persistent source of truth. It may be incomplete/stale/uncommitted; verify current resource state through Agor MCP before acting.

Next actions:
- Process `baker-tyme` branch `docs-reviewer-final-gate` against `develop`.
- After merge/closure, clean up `backup/docs-reviewer-final-gate` and the worktree.

### B3. Hygiene Gates - Integration Review ✅ DONE (2026-04-04)

Pre-review checklist already present in `AI_WORKFLOW__INTEGRATION_REVIEW_TASK.md` (added during 2026-04-03 session).

### B4. Rate Limit Pre-Flight Integration ✅ DONE (2026-04-04)

Integrated `scripts/check-rate-limit.sh` into orchestration workflow:
- `ORCHESTRATION_PATTERNS.md` — new "Rate Limit Pre-Flight" section with action matrix
- `AGENTS.md` — step 0 in coding work isolation pattern, step 9 in session start checklist
- Skill reference: `skills/check-rate-limit.md`

---

### A1. Agor State Cache Policy ✅ DONE (2026-04-06)

**What:** Define `memory/agor-state/*.json` as optional ephemeral cache rather than persistent source of truth

**Current state:**
- Persistent state lives in git-tracked docs: `MEMORY.md`, daily logs, `TODO.md`, `repos/*.md`, and `skills/*.md`.
- Current Agor resource truth comes from Agor MCP at decision time.
- `memory/agor-state/*.json` is gitignored, optional, and allowed to be stale/incomplete.
- Use it only for short-term handoff, controlled restart protection, or ad-hoc shared session/worktree notes.
- Do not base critical orchestration decisions solely on this cache.

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
