# Village Progression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a persistent, data-driven village reputation and achievement journal for Echo Village 1.2.0.

**Architecture:** A pure `ProgressionService` evaluates JSON-defined achievements against a read-only game snapshot. `GameManager` owns the saved progression state and emits unlock snapshots; a reusable modal panel renders progress without containing game rules.

**Tech Stack:** Godot 4.2+, GDScript, JSON, existing headless TestRunner, GPU visual QA, Windows BAT release pipeline.

## Global Constraints

- Preserve offline play and deterministic fallback behavior.
- Preserve existing J chronicle, K quest log, and all 66 regression tests.
- New interactive targets are at least 44px high and never communicate state by color alone.
- Production behavior must be preceded by a failing automated test.

---

### Task 1: Progression rules and data

**Files:**
- Create: `data/progression/achievements.json`
- Create: `scripts/progression/progression_service.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `default_state() -> Dictionary`
- `reputation_tier(renown: int) -> Dictionary`
- `evaluate(state: Dictionary, snapshot: Dictionary) -> Dictionary`

- [ ] Add failing tests for reputation boundaries, unknown conditions, six unlock conditions, and idempotency.
- [ ] Run `run_echo_village.bat --test`; expect the new tests to fail because the service and data do not exist.
- [ ] Implement the JSON definitions and pure service.
- [ ] Re-run the full suite; expect all tests to pass.

### Task 2: Game state, events, and save compatibility

**Files:**
- Modify: `scripts/core/game_manager.gd`
- Modify: `scripts/core/event_bus.gd`
- Modify: `scripts/core/world_state.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `progression_snapshot() -> Dictionary`
- `evaluate_progression() -> Array`
- `progression_unlocked(achievement: Dictionary)` signal

- [ ] Add failing integration tests for defaults, interaction unlock, quest/gather unlock, serialization, and v2 fallback.
- [ ] Run the suite and confirm failures identify missing integration.
- [ ] Add authoritative progression state, evaluation calls, signal emission, and save version 3 compatibility.
- [ ] Re-run the suite; expect all tests to pass.

### Task 3: Accessible Village Journal UI

**Files:**
- Create: `scenes/ui/ProgressionPanel.tscn`
- Create: `scripts/ui/progression_panel.gd`
- Modify: `scripts/main.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `refresh(snapshot: Dictionary) -> void`
- `set_visible_with_motion(open: bool, motion_enabled: bool) -> void`

- [ ] Add failing scene tests for required labels, 44px close button, status text, P binding, modal pause, and unlock feedback.
- [ ] Run the suite and confirm the UI contract fails for missing nodes.
- [ ] Implement the reusable panel, shortcut, modal handling, HUD tier, and EventBus feedback.
- [ ] Re-run the full suite and fix regressions without weakening assertions.

### Task 4: Release documentation and complete verification

**Files:**
- Modify: `project.godot`, `README.md`, `CHANGELOG.md`, `RELEASE_README.txt`, `build_release.bat`
- Modify: `docs/architecture.md`, `docs/test_plan.md`, `docs/portfolio_case_study.md`
- Add: updated visual QA PNG and test report

- [ ] Update all current-version and test-count references to 1.2.0 and the measured final count.
- [ ] Run the complete headless suite and require zero failures or script errors.
- [ ] Run GPU visual QA and inspect the new journal capture at 1280×720.
- [ ] Run `build_release.bat`, rebuild `EchoVillage_1.2.0_Windows.zip`, smoke-test the EXE, and verify files, dimensions, process cleanup, sizes, and SHA-256.
- [ ] Review the staged diff and commit the verified 1.2.0 update.
