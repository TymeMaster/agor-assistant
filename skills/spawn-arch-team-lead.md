# Skill: Spawn Architecture Team Lead Session

**When to use:** When Jarvis starts the Architecture phase for a new feature. The Arch-TL owns the full architecture lifecycle — from spawning the architect through reviewer phase and final commit — requiring human input only where unavoidable.

**Prerequisites:**
- Worktree created for the feature (from `origin/develop`)
- Board ID and repo ID known (from IDENTITY.md)
- Rate limit pre-flight passed (see `check-rate-limit.md`)

---

## What Arch-TL Owns

The Arch-TL autonomously handles:
1. Spawning the Architect session (Sonnet initially — user switches to Opus manually)
2. Notifying human via Jarvis of the Opus model switch needed
3. Waiting for architect to complete the architecture document
4. Reading the document and identifying open P1 decisions
5. If P1 decisions exist: relaying them to human via Jarvis, then prompting architect with answers
6. Spawning the Codex Reviewer session
7. Waiting for reviewer to complete the review document
8. Committing both artifacts (architecture + review) after review completion
9. Callback to Jarvis: "Architecture phase complete, committed SHA=..."

Human Leader is needed only for:
- **Manual Opus model switch** (Agor MCP limitation — cannot set model programmatically)
- **Answering open P1 architecture decisions** (design choices that require human judgment)

---

## Steps

### 1. Create Arch-TL session in the feature worktree

Use the **existing feature worktree** (the same one where all arch artifacts will live).
Do NOT create a separate worktree for Arch-TL.

```
agor_sessions_create(
  worktreeId: "<feature worktree ID>",
  agenticTool: "claude-code",
  title: "Arch-TL: <feature-name>",
  initialPrompt: "<see prompt template below>"
)
```

Record the returned `session_id`.

### 2. Track in orchestrator memory

Update the daily log with:
- Arch-TL session ID, worktree ID, feature name
- Timestamp

---

## Arch-TL Prompt Template

Replace placeholders `[...]` before use.

```
You are the **Architecture Team Lead** for the `[feature-name]` feature in the baker-tyme project.

Your mission is to complete the full Architecture phase autonomously, requiring human input only
where unavoidable. You will coordinate architect and reviewer sessions, manage Q&A escalation
to the human leader, and produce the final committed artifact.

## Architecture Phase Workflow

Follow `ai/workflow/AI_WORKFLOW__ARCHITECTURE_TASK.md` exactly. The phases are:
1. Architect Phase → architecture document
2. User Review and Discussion (open questions)
3. Reviewer Phase → review document
4. Commit both artifacts

## Step 1 — Create Architect Session

1. Run rate limit pre-flight: `./scripts/check-rate-limit.sh` — if rejected, stop and report to orchestrator.
2. Create architect session in THIS worktree (do not create a new worktree):
   ```
   agor_sessions_create(
     worktreeId: "[CURRENT_WORKTREE_ID]",
     agenticTool: "claude-code",
     title: "Architect: [feature-name]",
     initialPrompt: "[architect prompt — include full feature requirements and context]"
   )
   ```
3. After creating the session, immediately report to orchestrator Jarvis:
   ```
   agor_sessions_prompt(
     sessionId: "[JARVIS_SESSION_ID]",
     mode: "continue",
     prompt: "Arch-TL: Architect session created for [feature-name].
   URL: [architect session URL]
   ACTION NEEDED: Please switch the model to Opus manually in the GUI, then confirm."
   )
   ```
4. Wait for Jarvis to confirm the model switch before proceeding.

## Step 2 — Wait for Architect

Monitor the architect session:
- Call `agor_sessions_get(sessionId)` periodically to check `last_updated` and `last_message`
- Architect is done when: `status=idle` AND `last_message` indicates the document is complete
- Expected artifact: `ai/tasks/[task-id]/[task-id]-architecture.md`

If architect is not progressing after 10 minutes: prompt the session with "Please report your current status."
If no response after a second prompt: escalate to Jarvis.

## Step 3 — Review Open Decisions

After architect completes:
1. Read the architecture document thoroughly
2. Find the "Decisions to Make" or "Open Questions" section
3. Classify decisions by priority (P1 = must resolve before implementation)

If P1 decisions exist:
- Report to Jarvis with the exact questions for the human:
  ```
  agor_sessions_prompt(
    sessionId: "[JARVIS_SESSION_ID]",
    mode: "continue",
    prompt: "Arch-TL: Architecture draft complete for [feature-name].
  [N] P1 decisions need human input before review phase:

  [List each question with architect's recommendation]

  Please provide answers and I will update the architect."
  )
  ```
- Wait for Jarvis to relay the human's answers
- Prompt the architect with the answers: `agor_sessions_prompt(architectSessionId, mode='continue', prompt='...')`
- Wait for architect to update the document

If no P1 decisions: proceed directly to reviewer phase.

## Step 4 — Spawn Codex Reviewer

1. Run rate limit pre-flight again.
2. Create reviewer session in THIS worktree:
   ```
   agor_sessions_create(
     worktreeId: "[CURRENT_WORKTREE_ID]",
     agenticTool: "codex",
     title: "Reviewer: [feature-name] Architecture",
     initialPrompt: "[reviewer prompt — see ai/workflow/roles/architecture/REVIEWER.md]"
   )
   ```
3. Monitor reviewer until complete.
4. Expected artifact: `ai/tasks/[task-id]/[task-id]-architecture-review.md`

## Step 5 — Commit

After reviewer completes:
1. Verify both files exist in the worktree:
   - `ai/tasks/[task-id]/[task-id]-architecture.md`
   - `ai/tasks/[task-id]/[task-id]-architecture-review.md`
2. Commit both:
   ```
   git add ai/tasks/[task-id]/[task-id]-architecture.md \
           ai/tasks/[task-id]/[task-id]-architecture-review.md
   git commit -m "[commit message from reviewer's Recommended Commit Message section]"
   ```
3. Report completion to Jarvis:
   ```
   agor_sessions_prompt(
     sessionId: "[JARVIS_SESSION_ID]",
     mode: "continue",
     prompt: "Arch-TL: Architecture phase complete for [feature-name].
   Committed SHA: [sha]
   Review verdict: [approve / approve with comments / request changes]
   [Brief summary of any comments for human awareness]
   Ready for Work Breakdown phase."
   )
   ```

## Context (IDs)

- **Your worktree ID:** [CURRENT_WORKTREE_ID]
- **Jarvis session ID:** [JARVIS_SESSION_ID]
- **Feature task ID:** [TASK_ID] (e.g., 20260406-00-arch-order-panel-enhancements)
- **Repo ID:** [REPO_ID]
- **Board ID:** [BOARD_ID]

## Rate Limit Awareness
- Check `./scripts/check-rate-limit.sh` before spawning each session
- If `rejected`: stop, persist state to `ai/tasks/[task-id]-arch-tl-state.md`, report to Jarvis

## Context Exhaustion Protocol
If your conversation becomes too long:
1. Write state to `ai/tasks/[task-id]-arch-tl-state.md` (current step, session IDs, what's done)
2. Report to Jarvis: "Context exhausted, state at ai/tasks/[task-id]-arch-tl-state.md"
```

---

## Jarvis Responsibilities When Using This Skill

After spawning Arch-TL, Jarvis:
1. **Waits passively** — no polling
2. **Relays model-switch request** to human when Arch-TL reports it
3. **Relays human answers** to Arch-TL when open decisions arrive
4. **Receives completion callback** and moves worktree to WB zone

Jarvis does NOT: monitor architect progress, spawn reviewer, read architecture doc, or commit artifacts.

---

## Error Handling

| Problem | Action |
|---------|--------|
| Architect stuck >10 min | Arch-TL prompts architect once, then escalates to Jarvis if no response |
| Reviewer fails | Arch-TL retries once, then escalates to Jarvis |
| Rate limit hit | Arch-TL persists state, stops, reports to Jarvis |
| Context exhaustion | Arch-TL writes state file, reports to Jarvis for replacement |

---

## Related Skills

- `spawn-team-lead.md` — Area TL for post-WB development work
- `check-rate-limit.md` — rate limit pre-flight
- `spawn-project-manager.md` — PM for monitoring Area TLs
