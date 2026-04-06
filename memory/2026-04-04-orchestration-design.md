# Orchestration Model Design — 2026-04-04

## Context

Brainstorming session with human leader to optimize token usage and orchestration efficiency.
Goal: Multi-layer model isolating competencies, minimizing Opus token burn.

**Post-experiment correction:** The original cron-based PM idea was tested in Exp.4 and failed in this Agor environment. The operational PM model is now **manual trigger** by Opus or human via `agor_sessions_prompt(mode='continue')`. Historical experiment notes below are preserved for context.

---

## Agreed Architecture: 3-Layer Model

```
Human Leader
  │  impulse / approval
  ▼
Layer 1: OPUS ORCHESTRÁTOR (Jarvis) — PASSIVE
  │  - Communication gate with human
  │  - Delegates work, never executes
  │  - Evidences orchestration problems
  │  - Minimal context = minimal token burn
  │  - Manually created via GUI (model override not in MCP)
  │
  ├── Layer 2b: SONNET PM (heartbeat controller) — MANUAL TRIGGER
  │     - Triggered manually by Opus or human, not long-running
  │     - Polls TL session status periodically
  │     - Pushes stalled TLs (prompt to resume)
  │     - Escalates to Opus after 2x failed push
  │     - Zero implementation knowledge
  │     - Handles dynamic TL list (TLs can be replaced)
  │     - Reports to Opus: only completion or 2x stall
  │
  ├── Layer 2a: SONNET TL-1 (Team Lead — Area X) — AUTONOMOUS
  │     │  - Full ownership of one Area
  │     │  - Knows: high-level architecture + own Area spec + AI workflow rules
  │     │  - Delegates: analysis → Codex, development → Sonnet, review → Codex
  │     │  - Commits prepared worker changes when acting as commit-capable fallback
  │     │  - Persists work state to file regularly
  │     │  - Context exhaustion → escalates to Opus → replacement TL
  │     │
  │     ├── Layer 3: Codex Worker (analysis/review)
  │     ├── Layer 3: Sonnet Worker (development)
  │     └── Layer 3: Codex Worker (integration review)
  │
  └── Layer 2a: SONNET TL-2 (Team Lead — Area Y) — AUTONOMOUS
        └── ... same structure ...
```

## Key Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Token optimization is PRIMARY constraint | Opus is scarcest resource; all design serves this |
| D2 | Opus is passive receiver | No polling, no monitoring, only reacts to impulses/callbacks |
| D3 | PM is manual-triggered | Cron/scheduled trigger failed in Exp.4; manual heartbeat avoids long-running PM token waste |
| D4 | PM escalation: 2x push then report | Avoids noise to Opus while catching real stalls |
| D5 | TL persists state to file | Resilience against context exhaustion |
| D6 | TL context exhaustion → Opus creates replacement | New TL gets resumé from state file |
| D7 | PM tracks dynamic TL list | Must distinguish: TL finished vs needs push vs dead |
| D8 | Every branch has ≥1 commit-capable session | Codex can't commit; Sonnet TL provides fallback when needed |
| D9 | Review is the final workflow gate | Reviewer owns the final verdict; commit execution may be delegated by orchestration |

## Communication Protocols

### Normal Flow
```
Human → Opus: "Implement feature X"
Opus → creates TL-1(Area1), TL-2(Area2), PM session
Opus/human → manually triggers PM heartbeat via agor_sessions_prompt
PM heartbeat → polls TL status
TL-N → spawns workers → monitors → commits results
TL-N(done) → callback → Opus
Opus → aggregates → informs Human
```

### Stall Recovery
```
PM detects TL-2 stalled (idle, no message_count change)
PM → prompts TL-2: "Resume work on Area Y"
  If TL-2 resumes → PM records recovery
  If TL-2 still stalled → PM prompts again (2nd attempt)
  If still stalled → PM reports to Opus: "TL-2 unresponsive after 2 pushes"
Opus → investigates, creates replacement TL or escalates to Human
```

### Context Exhaustion
```
TL-1 detects degraded efficiency (context too long)
TL-1 → writes final state summary to memory file
TL-1 → callback to Opus: "Context exhausted, state persisted at [path]"
Opus → creates new TL-1' with: state resumé + remaining tasks
Opus → updates PM: new TL session ID for Area 1
```

## TL Prompt Template (draft)

```
You are a Team Lead for [Area Name] in the baker-tyme project.

## Your Mission
Complete all implementation tasks for [Area Name] as defined in the specification below.

## What You Know
- High-level architecture: [link to architecture doc in worktree]
- Your Area specification: [link to area spec]
- AI workflow rules: [link to AI_WORKFLOW docs]

## What You Do NOT Know (and don't need to)
- Other areas and their progress (PM handles cross-area coordination)
- Orchestrator memory system (that's Jarvis's domain)

## How to Work
1. Read your Area specification thoroughly
2. Break down into tasks (if not already done)
3. For each task:
   a. Create worktree: agor_worktrees_create(repoId, worktreeName, boardId, createBranch=true)
   b. Create worker session: agor_sessions_create(worktreeId, agenticTool, initialPrompt)
      - Analysis/review tasks → agenticTool: "codex"
      - Development tasks → agenticTool: "claude-code" (Sonnet)
   c. Monitor worker (check session status)
   d. When worker is done: review output, commit changes if you retained commit ownership
4. Persist your progress to [state file path] after each completed task

## Commit Gate
- The app workflow ends at reviewer approval and final review artifact.
- If the reviewer is commit-capable, they may commit the approved output.
- If the reviewer is Codex, YOU retain commit ownership and perform the final git commit.
- Codex workers cannot commit (sandbox limitation).

## Context Exhaustion Protocol
If your conversation becomes too long and efficiency degrades:
1. Write comprehensive state summary to [state file path]
2. Include: completed tasks, in-progress tasks, remaining tasks, any blockers
3. Report to orchestrator via callback: "Context exhausted, state at [path]"
```

## PM Prompt Template (draft)

```
You are the Project Manager (heartbeat controller) for the baker-tyme development workflow.

## Your Mission
Ensure all Team Leads are making progress. You are a pusher, not an implementor.

## Active Team Leads
[Dynamic list — provided at each manual heartbeat invocation]
- TL-1: session_id=XXX, Area=Walls, worktree=YYY
- TL-2: session_id=XXX, Area=UI, worktree=YYY

## How to Work
1. For each TL, call agor_sessions_get(sessionId)
2. Check: message_count, last_updated, status
3. Classification:
   - ACTIVE: message_count increasing, last_updated recent → no action
   - FINISHED: status indicates completion → record, report to Opus
   - STALLED: idle for >N minutes, no progress → push (see below)
   - DEAD: session error or unresponsive after 2 pushes → escalate

## Push Protocol
If TL appears stalled:
1. First push: agor_sessions_prompt(sessionId, mode='append', prompt="Status check: please report your current progress and any blockers.")
2. Wait for next manual heartbeat invocation
3. If still stalled: Second push with urgency
4. If still stalled after 2nd push: Report to Opus orchestrator

## Reporting
- Report to Opus ONLY for: final completion of all areas, or 2x stall escalation
- Do NOT report routine status — you handle that silently

## Important
- TL list is DYNAMIC — TLs may be replaced (context exhaustion)
- You will receive updated TL list at each invocation
- Distinguish between "TL finished work" and "TL needs push"
```

---

## Experimental Verification Plan

### Prerequisites
- All experiments use baker-tyme board (94ca6016-0117-46b6-91af-aa0263e209a9)
- All experiments use baker-tyme repo (983414ea-f060-47eb-9b7f-691e24a9d996)
- Cleanup: delete test worktrees/sessions after each experiment

### Experiment 1: Sonnet + Agor MCP Access (CRITICAL)

**Goal:** Verify Sonnet session created via MCP can use Agor MCP tools (create worktrees, sessions).

**Steps:**
1. Opus creates worktree: `agor_worktrees_create(repoId=baker-tyme, worktreeName='exp1-tl-test', boardId=..., createBranch=true)`
2. Opus creates Sonnet session: `agor_sessions_create(worktreeId=..., agenticTool='claude-code', initialPrompt=...)`
3. Initial prompt for Sonnet:
   ```
   You are testing Agor MCP access. Please:
   1. List available Agor MCP tools (any tool starting with "agor_")
   2. Call agor_worktrees_list() and report how many worktrees exist
   3. Create a test worktree: agor_worktrees_create(repoId='983414ea-f060-47eb-9b7f-691e24a9d996', worktreeName='exp1-worker-test', boardId='94ca6016-0117-46b6-91af-aa0263e209a9', createBranch=true)
   4. Report success or failure with details
   ```
4. Verify: Check if `exp1-worker-test` worktree was created

**Success criteria:** Sonnet session successfully creates a worktree via Agor MCP.
**Failure impact:** If this fails, TL model needs redesign — TLs can't delegate.

### Experiment 2: Callback Chain (TL → Worker → TL)

**Goal:** Verify spawn + callback works within a Sonnet session.

**Depends on:** Experiment 1 success.

**Steps:**
1. In the Sonnet session from Exp.1
2. Prompt: `agor_sessions_prompt(sessionId=..., mode='append', prompt=...)`
   ```
   Now test the callback chain:
   1. Spawn a subsession with callback: agor_sessions_spawn(prompt="Write 'DONE' to /tmp/exp2-result.txt", enableCallback=true, includeLastMessage=true)
   2. Wait for the callback
   3. When callback arrives, report what you received
   4. Write the callback content to /tmp/exp2-callback-result.txt
   ```
3. Verify: Check callback arrived and TL continued processing

**Success criteria:** TL receives callback from worker and continues.
**Failure impact:** TL can't use async delegation — must poll instead.

### Experiment 3: PM Heartbeat Pattern

**Goal:** Verify a session can poll other sessions' status via MCP.

**Depends on:** Experiment 1 (need session IDs to poll).

**Steps:**
1. Create new Sonnet session (PM role) in orchestrator worktree
2. Prompt:
   ```
   You are testing the PM heartbeat pattern. Check the status of these sessions:
   - Session 1: [TL session ID from Exp.1]
   - Session 2: [Worker session ID from Exp.2, if available]

   For each session, call agor_sessions_get(sessionId) and report:
   - status (running/idle/completed)
   - message_count
   - last_updated
   - Whether it appears active or stalled
   ```
3. Verify: PM correctly reads and classifies session states

**Success criteria:** PM can read session status and classify liveness.
**Failure impact:** PM can't monitor — need alternative monitoring approach.

### Experiment 4 (optional): Cron-based PM

**Goal:** Verify Agor scheduled triggers can invoke PM pattern.

**Depends on:** Experiment 3 success.

**Steps:**
1. Explore Agor cron/scheduling capabilities (CronCreate tool)
2. Create a minimal cron job that invokes PM-like session
3. Verify it triggers on schedule

**Success criteria:** Automated periodic invocation works.
**Failure impact:** PM must be triggered manually or by Opus (less autonomous).

---

## Cleanup Plan

After experiments:
- Delete test worktrees: exp1-tl-test, exp1-worker-test
- Archive session IDs in daily log
- Document results in this file (update sections below)

---

## Experiment Results

### Exp.1: Sonnet + Agor MCP
- **Status:** PASS
- **Result:** Sonnet session has full Agor MCP access (38 tools). Successfully listed worktrees and created new worktree.
- **Session ID:** 936b7ef3-0085-457e-b741-57fd6def19aa
- **Created worktree:** exp1-worker-test (8fabfd53-113d-4f4c-8790-a83e2523d12e)
- **Conclusion:** TL model is technically feasible — Sonnet can fully delegate via MCP.

### Exp.2: Callback Chain
- **Status:** PASS
- **Result:** TL spawned worker → worker executed task → callback received by TL → TL continued processing. Full chain works.
- **Child session:** 82ae01d0-f662-4990-9ee0-80330648d9c5
- **Callback timing:** < 60 seconds
- **includeLastMessage:** Works correctly, returns worker's final response
- **Conclusion:** Async delegation pattern is production-ready.

### Exp.3: PM Heartbeat
- **Status:** PASS
- **Result:** PM session can read session metadata, classify liveness (ACTIVE/IDLE_COMPLETE/STALLED), and prompt stalled sessions.
- **PM session:** 7168289f-10b9-4e5b-9067-498b24f2039c
- **Key findings:**
  - agor_sessions_get provides: status, ready_for_prompt, last_updated, tasks, genealogy, last_message
  - agor_sessions_prompt(mode=continue) successfully pushes idle sessions
  - message_count may not be reliable (showed 0 for active sessions) — use last_updated + last_message instead
- **Limitation:** Stall detection requires timestamp heuristics, no built-in "error" status
- **Conclusion:** PM heartbeat pattern is fully viable.

### Exp.4: Cron PM
- **Status:** DONE — žádný automatický cron mechanismus nefunguje v tomto prostředí
- **Result:** FAIL — automatický PM heartbeat zatím není realizovatelný
- **Tested mechanisms (all failed):**
  - `RemoteTrigger` (Anthropic cloud): HTTP 500 + nemá přístup k lokálnímu Agor MCP → NEPOUŽITELNÝ
  - `CronCreate` (session-scoped): Joby se vytvoří ale nikdy nefirují, samy zmizí → NEFUNKČNÍ
  - `CronCreate durable:true`: Ignoruje durable flag, chová se jako session-only → NEFUNKČNÍ
  - `/loop` skill: Wrapper nad CronCreate, stejný problém → NEFUNKČNÍ
  - Agor `schedule_enabled`: Pole existuje na worktrees, chybí MCP API → NEIMPLEMENTOVÁNO
- **Root cause:** CronCreate vyžaduje REPL v idle stavu. V Agor-managed sessions se tento stav buď nedosahuje, nebo joby předčasně expirují.
- **Doporučení pro PM roli:**
  1. **Krátkodobě:** PM triggeruje human nebo Opus manuálně přes `agor_sessions_prompt` (ověřeno v Exp.3)
  2. **Střednědobě:** Zeptat se Agor týmu na `schedule_enabled` API a worktree-level scheduling
  3. **Dlouhodobě:** Systémový cron (Linux) volající Agor API přímo, mimo Claude session
