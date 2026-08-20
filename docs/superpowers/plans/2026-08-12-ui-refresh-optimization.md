# UI Refresh Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace per-frame full UI rebuilding with coalesced, event-driven section refreshes while preserving every public method and scene node path.

**Architecture:** A pure `UiRefreshScheduler` owns dirty masks and metrics. `Main` maps domain signals to masks, flushes at most once per frame, and keeps `refresh_ui()` as a compatibility wrapper. A pure presenter extracts repeated text formatting without owning game state or Controls.

**Tech Stack:** Godot 4.2+、GDScript、EventBus、既有 headless TestRunner、PowerShell validator。

## Global Constraints

- 保留目前存檔、操作方式、遊戲內容、中文 UI 與畫面表現。
- 保留 `Main.tscn` 現有節點名稱和測試使用的公開方法。
- 不新增第三方 dependency。
- 每個行為變更先寫失敗測試，再做最小實作。

---

### Task 1: Dirty-region scheduler

**Files:**
- Create: `scripts/ui/ui_refresh_scheduler.gd`
- Create: `tests/suites/ui_refresh_scheduler_test.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `request(mask: int, reason: String = "") -> void`
- Produces: `consume() -> Dictionary` with `mask` and `reasons`
- Produces: `metrics() -> Dictionary`

- [ ] **Step 1: Write the failing scheduler contract**

```gdscript
extends RefCounted

static func run() -> bool:
	var script = load("res://scripts/ui/ui_refresh_scheduler.gd")
	if script == null: return false
	var scheduler = script.new()
	scheduler.request(script.TIME,"minute")
	scheduler.request(script.TIME,"duplicate minute")
	scheduler.request(script.PLAYER,"inventory")
	var batch: Dictionary = scheduler.consume()
	var empty_batch: Dictionary = scheduler.consume()
	var stats: Dictionary = scheduler.metrics()
	return int(batch["mask"]) == (script.TIME | script.PLAYER) and batch["reasons"].size() == 3 and int(empty_batch["mask"]) == 0 and int(stats["flushes"]) == 1 and int(stats["coalesced_requests"]) == 2
```

Preload the suite and add `check("UI 刷新排程器會合併同幀重複區域", UiRefreshSchedulerTest.run())` to `run()`.

- [ ] **Step 2: Run test to verify it fails**

Run: `run_echo_village.bat --test`

Expected: non-zero because the scheduler script does not exist.

- [ ] **Step 3: Implement the scheduler**

```gdscript
class_name UiRefreshScheduler
extends RefCounted

const TIME := 1 << 0
const PLAYER := 1 << 1
const WORLD := 1 << 2
const NPC := 1 << 3
const QUEST := 1 << 4
const PROGRESSION := 1 << 5
const LOG := 1 << 6
const CONTEXT := 1 << 7
const DEBUG := 1 << 8
const ALL := TIME | PLAYER | WORLD | NPC | QUEST | PROGRESSION | LOG | CONTEXT | DEBUG

var _pending_mask := 0
var _reasons: Array[String] = []
var _flushes := 0
var _requests := 0
var _section_counts: Dictionary = {}

func request(mask: int, reason: String = "") -> void:
	_requests += 1
	_pending_mask |= mask
	if reason != "": _reasons.append(reason)

func consume() -> Dictionary:
	if _pending_mask == 0: return {"mask":0,"reasons":[]}
	var mask := _pending_mask
	var reasons := _reasons.duplicate()
	_pending_mask = 0
	_reasons.clear()
	_flushes += 1
	for section in [TIME,PLAYER,WORLD,NPC,QUEST,PROGRESSION,LOG,CONTEXT,DEBUG]:
		if mask & section: _section_counts[section] = int(_section_counts.get(section,0)) + 1
	return {"mask":mask,"reasons":reasons}

func metrics() -> Dictionary:
	return {"flushes":_flushes,"section_counts":_section_counts.duplicate(true),"coalesced_requests":maxi(0,_requests - _flushes)}
```

- [ ] **Step 4: Run all tests and commit**

Run: `run_echo_village.bat --test`

Expected: exit `0`.

```powershell
git add scripts/ui/ui_refresh_scheduler.gd tests/suites/ui_refresh_scheduler_test.gd tests/test_runner.gd
git commit -m "perf: add coalesced UI refresh scheduler"
```

### Task 2: Event-driven Main integration

**Files:**
- Modify: `scripts/main.gd`
- Modify: `tests/suites/ui_refresh_scheduler_test.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- Produces: `request_ui_refresh(mask: int, reason: String = "") -> void`
- Produces: `flush_ui_refresh() -> void`
- Preserves: `refresh_ui() -> void`
- Produces: `ui_refresh_metrics() -> Dictionary`

- [ ] **Step 1: Add a failing idle-frame contract**

```gdscript
static func main_integration(host: Node) -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	var instance = scene.instantiate()
	host.add_child(instance)
	await host.get_tree().process_frame
	var before: Dictionary = instance.ui_refresh_metrics()
	for _index in 5: await host.get_tree().process_frame
	var after: Dictionary = instance.ui_refresh_metrics()
	var result := int(after["flushes"]) == int(before["flushes"])
	instance.queue_free()
	return result
```

Register it as `check("靜止主場景不會每幀重建 UI", await UiRefreshSchedulerTest.main_integration(self))`.

- [ ] **Step 2: Run and verify failure**

Run: `run_echo_village.bat --test`

Expected: FAIL because Main has no metrics API and refreshes every frame.

- [ ] **Step 3: Wire signals and split refresh sections**

Preload the scheduler, request ALL after Controls exist, and map signals as follows: minute → TIME/NPC/CONTEXT/DEBUG; inventory → PLAYER/NPC; world event → WORLD/DEBUG; quest → QUEST; location → WORLD/QUEST/PLAYER/NPC/CONTEXT; memory/relationship → NPC/DEBUG; NPC action → NPC/CONTEXT/DEBUG; log → LOG; community → PROGRESSION/LOG; progression unlock → PROGRESSION plus existing feedback.

Move every statement from `refresh_ui()` without changing formatting into `refresh_time_ui`, `refresh_player_ui`, `refresh_world_ui`, `refresh_npc_ui`, `refresh_quest_ui`, `refresh_progression_ui`, `refresh_log_ui`, `refresh_context_ui`, and existing `refresh_debug`.

```gdscript
func flush_ui_refresh() -> void:
	var batch: Dictionary = ui_refresh_scheduler.consume()
	var mask := int(batch["mask"])
	if mask == 0: return
	if mask & UiRefreshSchedulerScript.TIME: refresh_time_ui()
	if mask & UiRefreshSchedulerScript.PLAYER: refresh_player_ui()
	if mask & UiRefreshSchedulerScript.WORLD: refresh_world_ui()
	if mask & UiRefreshSchedulerScript.NPC: refresh_npc_ui()
	if mask & UiRefreshSchedulerScript.QUEST: refresh_quest_ui()
	if mask & UiRefreshSchedulerScript.PROGRESSION: refresh_progression_ui()
	if mask & UiRefreshSchedulerScript.LOG: refresh_log_ui()
	if mask & UiRefreshSchedulerScript.CONTEXT: refresh_context_ui()
	if mask & UiRefreshSchedulerScript.DEBUG and debug_visible: refresh_debug()

func refresh_ui() -> void:
	request_ui_refresh(UiRefreshSchedulerScript.ALL,"compatibility full refresh")
	flush_ui_refresh()
```

Replace `_process()`'s unconditional `refresh_ui()` with `flush_ui_refresh()`. Movement requests CONTEXT only.

- [ ] **Step 4: Run regression tests and commit**

Run: `run_echo_village.bat --test`

Expected: exit `0`; idle-frame contract passes.

```powershell
git add scripts/main.gd tests/suites/ui_refresh_scheduler_test.gd tests/test_runner.gd
git commit -m "perf: make main UI refresh event driven"
```

### Task 3: Pure HUD presenter

**Files:**
- Create: `scripts/ui/hud_presenter.gd`
- Create: `tests/suites/hud_presenter_test.gd`
- Modify: `scripts/main.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:** Pure `resource_text`, `needs_text`, `clock_text`, `renown_text`, and `pulse_text` functions; no Autoload or Control access.

- [ ] **Step 1: Write failing formatting tests**

```gdscript
extends RefCounted
static func run() -> bool:
	var script = load("res://scripts/ui/hud_presenter.gd")
	if script == null: return false
	var presenter = script.new()
	return presenter.resource_text(24,3,1) == "硬幣 24   麵包 3   藥品 1" and presenter.needs_text({"hunger":26,"energy":82,"social":45,"safety":8}) == "需求  飢餓 26  ·  體力 82  ·  社交 45  ·  安全 8"
```

- [ ] **Step 2: Implement pure formatting**

```gdscript
class_name HudPresenter
extends RefCounted
func resource_text(coin: int, bread: int, medicine: int) -> String: return "硬幣 %d   麵包 %d   藥品 %d" % [coin,bread,medicine]
func needs_text(needs: Dictionary) -> String: return "需求  飢餓 %d  ·  體力 %d  ·  社交 %d  ·  安全 %d" % [int(needs["hunger"]),int(needs["energy"]),int(needs["social"]),int(needs["safety"])]
func clock_text(value: String, phase: String, scale: float) -> String: return value + "  ·  " + phase + "  ×%.0f" % scale
func renown_text(renown: int, title: String, unlocked: int, total: int) -> String: return "聲望 %d  ·  %s  ·  成就 %d / %d" % [renown,title,unlocked,total]
func pulse_text(npcs: int, event_name: String, scale: float, unlocked: int) -> String: return "居民運作中：%d / 5\n當前事件：%s\n模擬速度：×%.0f\n編年進度：%d / 3\n\nE 選取村民，查看關係與記憶。" % [npcs,event_name,scale,unlocked]
```

- [ ] **Step 3: Delegate equivalent strings, test, and commit**

Run: `run_echo_village.bat --test`

Expected: exit `0`.

```powershell
git add scripts/ui/hud_presenter.gd scripts/main.gd tests/suites/hud_presenter_test.gd tests/test_runner.gd
git commit -m "refactor: extract pure HUD presentation"
```

### Task 4: Main controller boundaries

**Files:**
- Create: `scripts/ui/modal_coordinator.gd`
- Create: `scripts/input/input_controller.gd`
- Create: `scripts/interaction/world_interaction_controller.gd`
- Create: `tests/suites/main_controller_test.gd`
- Modify: `scripts/main.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `ModalCoordinator.is_blocking(panels: Array[Control]) -> bool` and `sync_pause(game_time: Node, panels: Array[Control])`
- `InputController.just_pressed(action: String) -> bool` and `movement_vector() -> Vector2`
- `WorldInteractionController.nearest_npc_id(player_position: Vector2, npcs: Dictionary, visible_ids: Array[String], radius: float) -> String`

- [ ] **Step 1: Add failing pure controller contracts**

Test modal blocking with visible/hidden Controls, verify movement vector returns Vector2, and verify nearest selection excludes residents not in `visible_ids` and respects radius.

- [ ] **Step 2: Implement focused controllers**

Controllers receive all inputs explicitly. They do not read Main fields through reflection and do not own Controls. Preserve `Main.is_blocking_modal_open()`, `sync_simulation_pause()`, `nearest_npc_id()`, and `npc_is_present()` as thin delegates so existing tests remain valid.

- [ ] **Step 3: Delegate input, modal, and nearest-resident mechanics**

Replace only equivalent mechanics in `main.gd`; keep action routing, UI mutations, dialogue, sounds, and visual QA orchestration in Main. Do not alter shortcuts or node paths.

- [ ] **Step 4: Test and commit**

Run: `run_echo_village.bat --test`

Expected: exit `0`, including modal pause, location-aware interaction, input map, and camera tests.

```powershell
git add scripts/ui/modal_coordinator.gd scripts/input/input_controller.gd scripts/interaction/world_interaction_controller.gd scripts/main.gd tests/suites/main_controller_test.gd tests/test_runner.gd
git commit -m "refactor: extract main scene controllers"
```

### Task 5: UI performance evidence

**Files:**
- Create: `tools/measure_ui_refresh.gd`
- Create: `tests/performance/ui_refresh_report.json`
- Modify: `docs/completion_audit.md`

- [ ] **Step 1: Measure 300 idle frames and repeated signal bursts**

The script instantiates Main, waits five warm-up frames, records metrics across 300 idle frames, requests one section ten times, flushes once, and writes both results. Assert `idle_flush_delta == 0` and `burst_flush_delta == 1`.

- [ ] **Step 2: Run measurement and full QA**

Run: `tools\godot\Godot_v4.5.2-stable_win64_console.exe --headless --path . --script res://tools/measure_ui_refresh.gd`

Run: `run_echo_village.bat --test`

Run: `tools\godot\Godot_v4.5.2-stable_win64_console.exe --headless --path . --editor --quit-after 4`

Run: `tools\godot\Godot_v4.5.2-stable_win64_console.exe --path . -- --visual-qa`

Expected: all exit `0`, no SCRIPT ERROR, idle delta zero, all eleven captures 1280×720.

- [ ] **Step 3: Document and commit evidence**

```powershell
git add tools/measure_ui_refresh.gd tests/performance/ui_refresh_report.json docs/completion_audit.md tests/visual_qa
git commit -m "test: record UI refresh optimization evidence"
```
