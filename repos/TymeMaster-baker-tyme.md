# baker-tyme

**Slug:** TymeMaster/baker-tyme  
**Repo ID:** 983414ea-f060-47eb-9b7f-691e24a9d996  
**Type:** Godot Android game  
**Tech Stack:** Godot 4.x, GDScript, GUT (Godot Unit Test)  
**Default Branch:** main  
**Development Branch:** develop

## Workflow

### Branch Baseline

- Default source for normal feature/docs/chore work: `origin/develop`
- Use `origin/main` only for release-oriented flow, such as preparing release PRs from `develop` to `main`
- PRs for normal work target `develop`, not `main`

### Before Starting Work

- [ ] Read AI workflow docs in `ai/workflow/` for phase-specific guidance
- [ ] Check `ai/workflow/CONVENTIONS.md` for naming, structure, commit format
- [ ] Verify the worktree was created from `origin/develop` unless this is explicitly release work
- [ ] Verify Godot 4.x is installed and accessible via `godot` command
- [ ] For new features: start from Architecture phase (see AI Workflow below)

### During Development

- [ ] Follow GDScript conventions (snake_case, explicit typing where helpful)
- [ ] Write GUT tests for new functionality in `tests/` directory
- [ ] Use temporary HOME/XDG dirs for headless Godot runs (prevents polluting user config)
- [ ] Run GUT test suite frequently during development

### Before Committing

- [ ] Run full GUT test suite: `HOME=/tmp XDG_CONFIG_HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- [ ] Verify all tests pass (check output for pass/fail summary)
- [ ] Import validation: `HOME=/tmp XDG_CONFIG_HOME=/tmp XDG_DATA_HOME=/tmp godot --headless --path . --import --quit`
- [ ] Use TymeMaster git identity: `TymeMaster <207343622+TymeMaster@users.noreply.github.com>`
- [ ] Follow conventional commit format (see Conventions below)

### Opening PRs

- [ ] Ensure all tests pass on the branch
- [ ] Create PR from feature branch to `develop` (not `main`)
- [ ] Include test coverage summary in PR description
- [ ] Link related task artifacts from `ai/tasks/` if applicable
- [ ] Attach PR URL to worktree via Agor MCP: `agor_worktrees_update(worktreeId, pullRequestUrl)`

## AI Workflow

baker-tyme uses a structured AI-assisted development workflow documented in `ai/workflow/`.

### Workflow Phases

1. **Architecture** (`AI_WORKFLOW__ARCHITECTURE_TASK.md`)
   - High-level technical design
   - Roles: Architect (Opus), Reviewer (Codex)
   
2. **Work Breakdown** (`AI_WORKFLOW__WORK_BREAKDOWN_TASK.md`)
   - Decompose architecture into Areas and Tasks
   - Roles: Analyst (Codex), Reviewer (Codex)
   
3. **Development** (`AI_WORKFLOW__DEVELOPMENT_TASK.md`)
   - Implementation of individual tasks
   - Roles: Analyst (Codex), Developer (Sonnet), Reviewer (Codex)
   
4. **Integration Review** (`AI_WORKFLOW__INTEGRATION_REVIEW_TASK.md`)
   - Validate completed areas or entire feature
   - Roles: Reviewer (Codex)

### Task Artifacts

All AI task artifacts live in `ai/tasks/YYYYMMDD-NN-task-slug/`:
- Architecture documents
- Work breakdown documents
- Implementation plans, summaries, reviews
- Integration reviews (area-level and complete)

### Finalization Responsibility

**Reviewer is the final workflow gate.**

- Worker sessions (Architect, Analyst, Developer, Reviewer) produce code/docs
- The reviewer is the last role in the task flow and produces the final review verdict
- After reviewer approval, the task is finalized with a commit
- Which session executes the git commit is an orchestration concern, not an app workflow rule

See `ORCHESTRATION_PATTERNS.md` in the agor-assistant repo for orchestration-specific commit handling.

## Tech Stack Details

### Godot 4.x

- **Engine:** Godot 4.x (exact version in `project.godot`)
- **Language:** GDScript (Python-like syntax)
- **Platform:** Android (primary target)
- **Scenes:** `.tscn` files (Godot scene format)
- **Scripts:** `.gd` files attached to scene nodes

### GUT Testing Framework

- **Framework:** GUT (Godot Unit Test) - addon in `addons/gut/`
- **Test location:** `tests/` directory
- **Test files:** `test_*.gd` (GUT convention)
- **Run tests:** Via `gut_cmdln.gd` command-line interface
- **Assertions:** `assert_*` methods (e.g., `assert_eq`, `assert_true`, `assert_null`)

### Headless Godot

For CI/testing without GUI:
```bash
# Import/validate project
HOME=/tmp XDG_CONFIG_HOME=/tmp XDG_DATA_HOME=/tmp \
  godot --headless --path . --import --quit

# Run GUT tests
HOME=/tmp XDG_CONFIG_HOME=/tmp XDG_DATA_HOME=/tmp \
  godot --headless --path . \
  -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests \
  -gexit
```

**Why temp HOME/XDG?** Prevents Godot from polluting user config with editor state during headless runs.

## Common Patterns

### GameplayObject Hierarchy

Core game objects extend `GameplayObject` base class:
- `Creature` - interactive game entities (e.g., Penguin, Dragon)
- `Obstacle` - non-interactive barriers (e.g., Wall)
- Template system: `GameLevelTemplate` materializes objects via `_setup_template_objects()`

### Board State Management

- `_board: Board` - singleton managing cell occupancy, move validation
- `is_cell_free()`, `can_place_object()` - placement validation
- `place_object()`, `remove_object()` - state mutations

### Enums

Defined in `scenes/game/objects/gameplay_enums.gd`:
- `ObjectCategory` - CREATURE, OBSTACLE, etc.
- `CreatureType` - PENGUIN, DRAGON, etc.
- `ObstacleType` - WALL, etc.

## Conventions

### Naming

- **Files:** snake_case (e.g., `game_level_template.gd`)
- **Classes:** PascalCase (e.g., `GameLevelTemplate`)
- **Variables/functions:** snake_case (e.g., `obstacle_placements`, `_setup_all_objects()`)
- **Private methods:** Leading underscore (e.g., `_init()`, `_ready()`)
- **Constants:** SCREAMING_SNAKE_CASE (e.g., `MAX_HEALTH`)

### Branch Naming (CI-enforced)

Format: `type/short-description` — with a **slash**, not a dash.

- `feat/order-panel`, `fix/spawn-crash`, `docs/workflow-update`, `chore/cleanup`
- Valid types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `ci`, `build`, `perf`, `hotfix`
- **Agor note:** `worktreeName` parameter only allows dashes — always set `ref` separately for the correct branch name (e.g., `worktreeName="feat-order-panel"`, `ref="feat/order-panel"`)

### Commit Messages

Follow conventional commit format (from `ai/workflow/CONVENTIONS.md`):
```
type(scope): brief description

Longer explanation if needed.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

**Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`  
**Scopes:** Feature names (e.g., `walls`, `penguin`), area names, or omit

## Things to Know

### GUT Test Execution

- GUT runs ALL tests in `tests/` directory by default (can't easily isolate single file)
- Use `before_each()`/`after_each()` for test setup/teardown
- Test output shows: scripts run, tests run, passing/failing counts
- Exit code 0 = all pass, non-zero = failures

### Godot Resource Management

- `.uid` files track resource identifiers (auto-generated by Godot)
- Commit `.uid` files alongside their corresponding assets
- Don't manually edit `.uid` files

### Translation Files

- `translations/*.translation` - binary files, build artifacts
- Source is `translations/translations.csv`
- Binary files regenerated by Godot editor
- Usually safe to leave unstaged unless adding new translation keys

### AI Task Directory Structure

```
ai/tasks/YYYYMMDD-NN-task-slug/
  ├── YYYYMMDD-NN-task-slug-architecture.md
  ├── YYYYMMDD-NN-task-slug-work-breakdown.md
  ├── YYYYMMDD-NN-task-slug-area-N-tasks.md
  ├── YYYYMMDD-NN-task-slug-area-N-integration-review.md
  ├── YYYYMMDD-subtask-NN-subtask-slug/
  │   ├── implementation-plan.md
  │   ├── implementation-summary.md
  │   └── implementation-review.md
  └── YYYYMMDD-NN-task-slug-complete-integration-review.md
```

### Workflow Best Practices

- **Small commits:** Each task/subtask gets its own commit
- **Clean worktrees:** Avoid carrying unstaged files across area boundaries
- **Test first:** Write/update tests before implementation when possible
- **Review artifacts:** Always create review artifacts (implementation-review, integration-review)
- **Board visibility:** Keep worktrees on Agor board, move through zones as work progresses

---

**Last Updated:** 2026-04-03
