# BOARD.md - Baker Tyme Features Board

- **Board ID:** 94ca6016-0117-46b6-91af-aa0263e209a9
- **Board Name:** Baker Tyme — Features
- **Board URL:** http://localhost:3030/b/baker-tyme-features

---

## Zones and Workflow

### Backlog

- **Zone ID:** zone-backlog
- **Purpose:** New features/tasks waiting to be picked up
- **Workflow State:** backlog
- **Border:** dashed gray on white

### Architecture

- **Zone ID:** zone-architecture
- **Purpose:** Design and architecture phase — research, exploration, high-level decisions
- **Workflow State:** architecture
- **Trigger:** show_picker (agent selection on drop)
- **Agent creates:** `*-architecture.md`
- **Role files:** `ARCHITECT.md` + `REVIEWER.md`

### WB — Areas (Work Breakdown)

- **Zone ID:** zone-work-breakdown
- **Purpose:** Break architecture into implementation areas
- **Workflow State:** work-breakdown-areas
- **Trigger:** show_picker
- **Agent creates:** `*-work-breakdown.md`
- **Role files:** `ANALYST.md` + `REVIEWER.md`

### WB — Tasks

- **Zone ID:** zone-wb-tasks
- **Purpose:** Break areas into concrete implementation tasks
- **Workflow State:** work-breakdown-tasks
- **Trigger:** show_picker
- **Agent creates:** `*-area-N-tasks.md`
- **Role files:** `ANALYST.md` + `REVIEWER.md`

### Development

- **Zone ID:** zone-development
- **Purpose:** Active coding — implementation of tasks
- **Workflow State:** development
- **Trigger:** show_picker
- **Agent creates:** `*-implementation-plan.md`, `*-implementation-summary.md`
- **Role files:** `ANALYST.md` + `DEVELOPER.md` + `REVIEWER.md`

### Done

- **Zone ID:** zone-done
- **Purpose:** Completed and merged work
- **Workflow State:** done

---

## Workflow Transitions

```
Backlog → Architecture → WB—Areas → WB—Tasks → Development → Done
```

Each transition includes a human review/approval gate.

---

## Current Board State (2026-04-04)

### Active Worktrees

| Worktree | Repo | Zone | Status |
|---|---|---|---|
| `chore-agor-test` | baker-tyme | *(no zone)* | Early Agor testing worktree, candidate for cleanup |
| `feat-walls` | baker-tyme | Done | Feature complete (335/335 tests passing), ready for UAT and merge |
| `assistent-baker-tyme` | agor-assistant | *(no zone)* | This orchestrator (Jarvis) |

### Experiment Worktrees (safe to delete)

| Worktree | Notes |
|---|---|
| `exp1-tl-test` | Orchestration model experiment — TL + PM sessions |
| `exp1-worker-test` | Created by TL in Exp.1 |
