# Echo Village v1.3 Living Stories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing NPC simulation into three persistent, player-readable branching story arcs while making save writes crash-tolerant and recoverable.

**Architecture:** Keep `GameManager` as the compatibility facade. Add a pure `StoryArcService` that consumes validated JSON definitions, emits structured consequences through `EventBus`, and stores only serializable story progress in the existing world snapshot. Harden `SaveManager` with temporary writes and a last-known-good backup without changing the public save envelope or existing migration contract.

**Tech Stack:** Godot 4.2+ / GDScript, JSON content contracts, existing headless `tests/TestRunner.tscn`, PowerShell/BAT quality gates, Windows portable runtime.

## Global Constraints

- Keep the project offline-first; optional AI may generate text only and cannot mutate authoritative state.
- Preserve world schema v3 and save envelope compatibility for existing saves.
- Do not add public deployment, cloud saves, analytics, telemetry, or third-party runtime dependencies.
- All new behavior must be covered by a failing test before production code.
- Existing 89 tests, security audit, runtime error gate, and visual QA must remain green.
- Keep all player-facing copy in Traditional Chinese and preserve current modal pause/input rules.

---

### Task 1: Save recovery contract

**Files:**
- Modify: `scripts/save/save_manager.gd`
- Modify: `tests/test_runner.gd`
- Modify: `docs/architecture.md`
- Test: `tests/test_runner.gd`

**Interfaces:**
- `SaveManager.save_game(kind: String = "manual") -> bool` keeps its public signature.
- Add `SaveManager.get_save_recovery_status() -> Dictionary` returning `available`, `using_backup`, and `reason`.
- Add private `_write_save_atomically(path: String, payload: String) -> bool` and `_restore_backup(path: String) -> bool`.

- [ ] **Step 1: Write failing tests** for successful atomic save, backup creation on second save, invalid primary fallback to `.bak`, and no partial world mutation after failed load.
- [ ] **Step 2: Run the focused headless test and confirm it fails because recovery helpers do not exist.**
- [ ] **Step 3: Implement temp-file write, flush, replace, backup rotation, bounded read and fallback migration while preserving `echo_village_save.json` as the primary path.
- [ ] **Step 4: Run the focused test and the existing suite; confirm the new behavior and all old tests pass.
- [ ] **Step 5: Refactor only after green; document the recovery contract in `docs/architecture.md`.
- [ ] **Step 6: Commit:** `fix: make saves atomic and recoverable`.

### Task 2: Story content contract and service

**Files:**
- Create: `data/stories/story_arcs.json`
- Create: `scripts/story/story_arc_service.gd`
- Modify: `scripts/core/game_manager.gd`
- Modify: `scripts/core/event_bus.gd`
- Modify: `tests/test_runner.gd`
- Create: `docs/story_system.md`

**Interfaces:**
- `StoryArcService.load_definitions() -> bool` validates IDs, stage order, trigger keys, choices, consequences, and bounded text.
- `StoryArcService.get_snapshot() -> Dictionary` returns active/completed arcs and current stage metadata.
- `StoryArcService.evaluate(world_snapshot: Dictionary) -> Array[Dictionary]` returns deterministic available story actions.
- `StoryArcService.apply_choice(arc_id: String, choice_id: String) -> Dictionary` validates and applies one idempotent choice through domain services.
- `EventBus.story_arc_updated(arc_id: String, stage_id: String, consequence: Dictionary)` is the UI-facing signal.

- [ ] **Step 1: Add failing tests** for valid content loading, malformed definition rejection, deterministic availability, invalid choice rejection, idempotent completion, and serialization round-trip.
- [ ] **Step 2: Run the focused test and verify expected failures for the missing service and content.
- [ ] **Step 3: Add the JSON schema data for three arcs: `bread_rumor`, `forest_echo_branch`, and `harvest_festival`.
- [ ] **Step 4: Implement the service with strict bounds, stage transitions, relationship/memory/coin/reputation consequences, and no direct UI dependency.
- [ ] **Step 5: Integrate the service into `GameManager` initialization, tick updates, serialization, migration defaults, and event logging.
- [ ] **Step 6: Run focused tests, then the full suite; keep all failures visible and fix production code rather than weakening assertions.
- [ ] **Step 7: Commit:** `feat: add data-driven living story arcs`.

### Task 3: Player-facing story interaction

**Files:**
- Create: `scenes/ui/StoryArcPanel.tscn`
- Create: `scripts/ui/story_arc_panel.gd`
- Modify: `scripts/ui/quest_tracker.gd`
- Modify: `scripts/main.gd`
- Modify: `tests/test_runner.gd`
- Modify: `docs/ui_ux_rationale.md`

**Interfaces:**
- `StoryArcPanel.open_arc(arc_id: String) -> void`.
- `StoryArcPanel.refresh(snapshot: Dictionary) -> void`.
- `StoryArcPanel.close_panel() -> void`.
- `QuestTracker` displays the active arc title, stage title, next objective, and available choice count without duplicating story state.

- [ ] **Step 1: Add failing tests** for tracker rendering, story panel modal priority, keyboard navigation, Esc close, disabled invalid choices, and event feedback.
- [ ] **Step 2: Run focused tests and confirm the expected UI contract failures.
- [ ] **Step 3: Implement the panel using existing `ui_theme.gd`, 44px minimum controls, Traditional Chinese copy, focus states, success/error feedback, and modal pause behavior.
- [ ] **Step 4: Wire story updates through `EventBus`; do not poll every frame.
- [ ] **Step 5: Add visual QA scenarios for one active choice, one consequence result, and one completed arc.
- [ ] **Step 6: Run UI tests and visual QA; fix overlap, truncation, contrast, and stale-state issues.
- [ ] **Step 7: Commit:** `feat: expose story choices in the player UI`.

### Task 4: Soak, fuzz, release, and documentation

**Files:**
- Modify: `tests/test_runner.gd`
- Modify: `tools/validate_project.ps1`
- Modify: `.github/workflows/ci.yml`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/test_plan.md`
- Modify: `docs/portfolio_case_study.md`
- Modify: `project.godot`

- [ ] **Step 1: Add failing tests** for 7-day and 30-day story progression, malformed/deep story data, save backup recovery, and story state limits.
- [ ] **Step 2: Run the new tests and verify they fail for missing coverage.
- [ ] **Step 3: Implement only the required test harness and validator changes; keep security reports ignored and isolated.
- [ ] **Step 4: Run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate_project.ps1`.
- [ ] **Step 5: Run `run_echo_village.bat --test` with isolated test storage and verify zero runtime errors, zero failed tests, security audit `finding_count=0`, and updated report count.
- [ ] **Step 6: Run GPU visual QA and packaged smoke test when export runtime is available; verify all expected screenshots and no leftover Godot processes.
- [ ] **Step 7: Update version/changelog/README/case study with exact test and visual counts, then commit:** `release: prepare Echo Village 1.3.0`.
- [ ] **Step 8: Push only the source, tests, docs, and CI changes to the existing GitHub branch; do not publish a deployment.

## Verification Matrix

| Area | Command / evidence | Acceptance |
|---|---|---|
| Structure | `tools/validate_project.ps1` | exit 0 |
| Runtime | `run_echo_village.bat --test` | 0 failures, no `SCRIPT ERROR` |
| Security | generated ignored audit report | `passed=true`, `finding_count=0` |
| Persistence | save recovery tests | primary corruption restores backup without partial mutation |
| Stories | service/UI contract tests | all three arcs progress, branch, serialize, and complete idempotently |
| Soak | 7/30-day simulation | bounded needs, valid states, no story overflow |
| Visual | `--visual-qa` | active, consequence, completed states readable at 1280×720 |
| Release | `build_release.bat` when GUI runtime exists | portable executable/PCK smoke test passes |

