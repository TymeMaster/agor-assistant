# Human Leader — Session Prompt Guide

Quick reference for opening new Jarvis sessions. Not every field is needed every time — use what's relevant.

---

## Template

```
## What
[What needs to happen. Feature description, bug to fix, or "continue X".]

## Where
[Current state. New task / which workflow phase / worktree name / session to continue.]

## How
[Preferences for this run.]
- Autonomy: autonomous / step-by-step / mixed
- Models: default / specific overrides (e.g., "use Opus for architect")
- Review: standard workflow / abbreviated / skip (with reason)

## Context
[Anything extra. Decisions already made, constraints, deadlines, related work.]
```

---

## Examples

### New feature (full workflow)
```
## What
Order panel: add closed slot status, coming queue preview, tap-to-recipe overlay.
[Detailed requirements...]

## Where
New task. No existing worktree.

## How
- Autonomy: autonomous implementation, manual UAT after all Areas done
- Models: Opus architect (manual GUI switch), rest default
- Review: standard workflow — don't skip reviewer phases

## Context
First test of revised orchestration flow. Available for architect Q&A.
```

### Continue existing work
```
## What
Continue feat/order-panel-enhancements — architecture review is done, proceed to WB.

## Where
Worktree: feat-order-panel-enhancements (947f8ed9)
Architecture: committed, reviewed
Phase: ready for WB — Areas

## How
- Autonomy: autonomous
- Models: Codex for WB analyst
```

### Quick fix / chore
```
## What
Fix branch naming in repos/TymeMaster-baker-tyme.md — add convention with slash.

## Where
agor-assistant repo, this session.

## How
- Direct edit, no workflow needed.
```

---

## What helps Jarvis most

| Info | Why it matters |
|------|---------------|
| **Current phase** | Prevents skipping workflow steps (Architecture → Review → WB → ...) |
| **Existing worktree/session IDs** | Avoids creating duplicates |
| **Autonomy level** | Determines when to ask vs. proceed |
| **Model preferences** | Some phases need manual GUI setup (Opus) |
| **"Don't skip review"** | Explicit reminder prevents the most common orchestration error |

---

## Minimum viable prompt

For continuing known work, even this is enough:

```
Continue feat/X. Architecture reviewed and committed. Start WB phase, autonomous, standard workflow.
```

The key signals: **what phase we're in**, **what's already done**, **how autonomous to be**.
