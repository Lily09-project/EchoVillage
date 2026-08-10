# Living Village Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modular world/quest/location foundation and the playable「林間回音」quest while keeping the current Echo Village showcase playable and save-compatible.

**Architecture:** Keep `GameManager` as the compatibility façade but move new state transitions into focused services. Data definitions are validated before simulation starts; services return result dictionaries instead of mutating UI. A v2 save envelope stores new world state and migrates the existing v1 world snapshot losslessly.

**Tech Stack:** Godot 4.5, GDScript, JSON content definitions, PowerShell structural validation, existing headless test runner and GPU visual QA capture.

## Global Constraints

- Preserve the five current NPC profiles, Showcase scenarios, Chinese UI, Utility AI, portable Godot and `run_echo_village.bat`.
- New data definitions are JSON under `data/`; invalid IDs, references, negative quantities and unsupported objective kinds fail validation.
- Save v1 must migrate to v2 without losing player inventory, NPC relationships/memories, time, community progress or active world event.
- Services change state; UI consumes service results and EventBus signals only.
- Every feature uses a red → green headless test cycle, then the full suite, editor load, game load and visual QA before completion.

---

### Task 1: Add data-driven world, quest and recipe definitions with validation

**Files:**
- Create: `data/world/locations.json`
- Create: `data/quests/quests.json`
- Create: `data/items/recipes.json`
- Modify: `tools/validate_project.ps1`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces `LocationDefinition`, `QuestDefinition` and `RecipeDefinition` JSON contracts consumed by `GameManager.load_data()`.
- Validation accepts exactly `talk_to_npc`, `deliver_item`, `visit_location`, and `reach_relationship` objective kinds.

- [ ] **Step 1: Write failing data-contract tests**

```gdscript
func expansion_data_contract_test() -> bool:
	var quests: Dictionary = GameManager.quest_defs
	var locations: Dictionary = GameManager.location_defs
	return quests.has("forest_echo") and locations.has("village_square") and locations.has("forest_edge")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `run_echo_village.bat --test`

Expected: `FAIL  擴充內容資料契約可載入` because `quest_defs` and `location_defs` do not exist.

- [ ] **Step 3: Add canonical content definitions**

Create `locations.json` with `village_square` unlocked by default and `forest_edge` linked from it. Create `forest_echo` with ordered objectives `talk_to_npc:alice`, `visit_location:forest_edge`, `deliver_item:bread`, rewards `{coin:8, herb:2, renown:4}`, and flag `forest_echo_complete`. Create recipe `forest_remedy` that turns `herb:2` into `medicine:1` at `forest_edge`.

- [ ] **Step 4: Add cross-reference validation**

Extend `validate_project.ps1` to load the three new files; reject duplicate IDs, unknown location neighbors, unknown quest giver, unsupported objective kind, unknown item references and quantities below one.

- [ ] **Step 5: Run the data contract test to verify it passes**

Run: `run_echo_village.bat --test`

Expected: `PASS  擴充內容資料契約可載入` and structural validation passes.

### Task 2: Introduce world state and v1 → v2 save migration

**Files:**
- Create: `scripts/core/world_state.gd`
- Create: `scripts/save/save_migration.gd`
- Modify: `scripts/core/game_manager.gd`
- Modify: `scripts/save/save_manager.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `WorldState.new_game_state(player, npcs, economy, active_event, event_log, memory_sequence, community) -> Dictionary` returns v2 runtime state.
- `SaveMigration.migrate(envelope: Dictionary) -> Dictionary` returns `{ok: bool, data: Dictionary, reason: String}`.
- `GameManager.serialize() -> Dictionary` emits `save_version: 2`; `deserialize(data: Dictionary) -> bool` returns false for invalid/future data.

- [ ] **Step 1: Write failing migration and round-trip tests**

```gdscript
func save_v1_migration_test() -> bool:
	GameManager.new_game()
	GameManager.interact("alice", "give_bread")
	var legacy := {"save_version":1, "world":GameManager.legacy_serialize(), "time":GameTime.serialize()}
	var result := SaveMigration.migrate(legacy)
	return bool(result["ok"]) and int(result["data"]["save_version"]) == 2 and result["data"]["world_state"].has("active_quests")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `run_echo_village.bat --test`

Expected: failure because `SaveMigration` and v2 world state do not exist.

- [ ] **Step 3: Implement `WorldState` and deterministic migration**

Initialize v2 keys `current_location`, `discovered_locations`, `active_quests`, `completed_quests`, and `world_flags`. Migrate old `world` fields verbatim into v2 world state. Reject `save_version > 2` and non-dictionary envelopes without modifying live state.

- [ ] **Step 4: Route save/load through v2**

Set the root save envelope to `save_version:2`; retain `time`, add `world_state`, and accept old `world` during load. Preserve the existing `SaveManager.save_game()` boolean API and friendly log messages.

- [ ] **Step 5: Run migration and existing save tests**

Run: `run_echo_village.bat --test`

Expected: migration test and prior save/load, community progress persistence tests all pass.

### Task 3: Implement location travel, quest progression and item crafting services

**Files:**
- Create: `scripts/services/location_service.gd`
- Create: `scripts/services/quest_service.gd`
- Create: `scripts/services/economy_service.gd`
- Modify: `scripts/core/event_bus.gd`
- Modify: `scripts/core/game_manager.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `LocationService.travel(state: Dictionary, location_id: String) -> Dictionary` returns `{ok, reason, location_id}`.
- `QuestService.accept(state: Dictionary, quest_id: String) -> Dictionary`, `notify(state, event_type, payload) -> Array[Dictionary]`, and `snapshot(state) -> Array[Dictionary]`.
- `EconomyService.craft(state: Dictionary, recipe_id: String) -> Dictionary` returns `{ok, reason, output}` without partial inventory mutation.
- New EventBus signals: `quest_changed(snapshot: Dictionary)`, `location_changed(location_id: String)`, `inventory_changed(inventory: Dictionary)`.

- [ ] **Step 1: Write failing progression tests**

```gdscript
func forest_echo_progression_test() -> bool:
	GameManager.new_game()
	if not GameManager.accept_quest("forest_echo")["ok"]: return false
	GameManager.interact("alice", "ask")
	if not GameManager.travel_to("forest_edge")["ok"]: return false
	GameManager.remove_item(GameManager.player["inventory"], "bread", GameManager.count_item(GameManager.player["inventory"], "bread"))
	var blocked := GameManager.complete_delivery("forest_echo", "bread", 1)
	GameManager.add_item(GameManager.player["inventory"], "bread", 1)
	var complete := GameManager.complete_delivery("forest_echo", "bread", 1)
	return not bool(blocked["ok"]) and bool(complete["ok"]) and GameManager.is_quest_completed("forest_echo")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `run_echo_village.bat --test`

Expected: failure because quest/travel APIs do not exist.

- [ ] **Step 3: Implement services and façade methods**

Load definitions into `GameManager.location_defs`, `quest_defs` and `recipe_defs`. Initialize service instances in `_ready()`. Bridge existing interaction and item APIs to objective notifications; only emit signals after a successful state mutation. Add `accept_quest`, `travel_to`, `craft_recipe`, `complete_delivery`, `active_quest_snapshot`, and `is_quest_completed` façade methods.

- [ ] **Step 4: Implement atomicity and consequence behavior**

When delivery lacks items, return `ok:false` and leave inventory/quest untouched. On `forest_echo` completion, remove `bread:1`, add `herb:2` and coin reward, create a positive memory for the giver, add renown, and set `forest_echo_complete`; do not award twice.

- [ ] **Step 5: Run focused and full regression tests**

Run: `run_echo_village.bat --test`

Expected: progression, locking, duplicate completion, craft atomicity and all prior tests pass.

### Task 4: Build quest and map UI components, then connect the first content slice

**Files:**
- Create: `scenes/ui/QuestTracker.tscn`
- Create: `scripts/ui/quest_tracker.gd`
- Create: `scenes/ui/WorldMapPanel.tscn`
- Create: `scripts/ui/world_map_panel.gd`
- Create: `scenes/ui/QuestLogPanel.tscn`
- Create: `scripts/ui/quest_log_panel.gd`
- Modify: `scripts/main.gd`
- Modify: `scripts/ui/village_art.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- UI components expose `refresh(snapshot: Array[Dictionary])`, `set_locations(locations: Dictionary, current_id: String)`, and `set_visible_with_motion(value: bool, motion_enabled: bool)`.
- `main.gd` owns input routing only: `M` opens map, `K` opens quest log, `Esc` closes the top-most visible panel.

- [ ] **Step 1: Write failing UI and input-map tests**

```gdscript
func expansion_ui_structure_test() -> bool:
	var instance := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(instance)
	await get_tree().process_frame
	var result := instance.has_node("CanvasLayer/QuestTracker") and instance.has_node("CanvasLayer/WorldMapPanel") and instance.has_node("CanvasLayer/QuestLogPanel")
	instance.queue_free()
	return result and InputMap.has_action("world_map") and InputMap.has_action("quest_log")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `run_echo_village.bat --test`

Expected: missing UI node and missing input mapping failures.

- [ ] **Step 3: Implement focused UI components**

Create warm-paper cards using `VillageTheme`; use text buttons with visible `關閉` labels and tooltips. `QuestTracker` shows at most three active objectives. `WorldMapPanel` labels unavailable locations, highlights current location, and routes travel through `GameManager.travel_to`. `QuestLogPanel` shows ordered objective status and rewards.

- [ ] **Step 4: Connect input, signals and forest presentation**

Add `world_map:KEY_M` and `quest_log:KEY_K`; subscribe panels to quest/location/inventory signals. Extend `VillageArt` to draw the forest-edge landmark palette when that location is active. `main.gd` updates the world subtitle and location-specific NPC prompt without directly changing quest state.

- [ ] **Step 5: Run UI regression tests**

Run: `run_echo_village.bat --test`

Expected: new UI test, existing contextual action test and all existing UI tests pass.

### Task 5: Extend QA evidence, documentation and release verification

**Files:**
- Modify: `scripts/main.gd`
- Modify: `docs/game_design.md`
- Modify: `docs/architecture.md`
- Modify: `docs/test_plan.md`
- Modify: `docs/portfolio_case_study.md`
- Modify: `README.md`
- Modify: `tests/test_runner.gd`
- Modify: `tests/simulation_test_report.json` (generated)
- Create: `tests/visual_qa/quest_in_progress.png`
- Create: `tests/visual_qa/forest_echo_complete.png`

**Interfaces:**
- `capture_visual_qa()` captures the two new deterministic quest states in addition to the current five images.
- `run_echo_village.bat --test` remains the canonical complete test command.

- [ ] **Step 1: Write failing visual-capture coverage test**

```gdscript
func expansion_visual_capture_test() -> bool:
	return FileAccess.file_exists("res://tests/visual_qa/quest_in_progress.png") and FileAccess.file_exists("res://tests/visual_qa/forest_echo_complete.png")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `run_echo_village.bat --test`

Expected: visual coverage test fails because the two files do not exist.

- [ ] **Step 3: Add deterministic capture states and refresh documentation**

Capture one accepted-but-blocked quest state and one completed forest-edge state. Document architecture boundaries, v2 migration, key bindings, validation coverage, and the new playable loop. Update the portfolio case study with the services and migration story.

- [ ] **Step 4: Run complete verification**

Run: `run_echo_village.bat --test`

Expected: all existing and expansion tests pass and the generated report count matches the runner.

Run: `tools\\godot\\Godot_v4.5.2-stable_win64_console.exe --headless --path . --editor --quit-after 4`

Expected: exit code 0 with no parse errors.

Run: `tools\\godot\\Godot_v4.5.2-stable_win64_console.exe --path . -- --visual-qa`

Expected: seven `VISUAL_CAPTURE` lines at 1280×720.

- [ ] **Step 5: Inspect visual output and launcher**

Inspect all seven captures for text clipping, overlays, location distinction, keyboard affordances and close paths. Launch `run_echo_village.bat` once, verify the bundled engine process targets this project, then close only that smoke-test process and remove generated `.godot` cache.

## Plan self-review

- **Spec coverage:** Tasks 1–5 cover data contracts, services, migration, the first playable quest, UI, visual QA and documentation.
- **No placeholders:** Every task names its files, public interface, test expectation and verification command.
- **Type consistency:** All quest/location mutations pass through `GameManager` façade methods and return `{ok, reason, ...}` result dictionaries; UI only reads snapshots and signals.
