# Core Service Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `GameManager` into a thinner compatibility facade by extracting trading, state serialization, NPC memory mechanics, and stable snapshot caching.

**Architecture:** Pure RefCounted services receive explicit state and dependencies, mutate only documented arguments, and return structured results. `GameManager` retains Autoload ownership, public signatures, signals, and logs.

**Tech Stack:** Godot 4.2+、GDScript、RefCounted services、EventBus、headless TestRunner。

## Global Constraints

- `GameManager` 公開方法、回傳結構與副作用保持相容。
- v1、v2、v3 存檔都可載入；v3 round trip 不丟失資料。
- 交易、任務與存檔更新維持原子性。
- 移除深拷貝前必須先有資料隔離測試。

---

### Task 1: Atomic TradeService

**Files:**
- Create: `scripts/services/trade_service.gd`
- Create: `tests/suites/trade_service_test.gd`
- Modify: `scripts/core/game_manager.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `price(npc, item_id, item_defs, economy, active_event) -> int`
- `sell_price(npc, item_id, item_defs, economy, active_event) -> int`
- `buy(player, npc, item_id, amount, unit_price, item_defs, inventory_service) -> Dictionary`
- `sell(player, npc, item_id, amount, unit_price, item_defs, inventory_service) -> Dictionary`

- [ ] **Step 1: Write failing atomicity tests**

```gdscript
extends RefCounted
static func run() -> bool:
	var script = load("res://scripts/services/trade_service.gd")
	var inventory_script = load("res://scripts/inventory/inventory_service.gd")
	if script == null or inventory_script == null: return false
	var items := {"bread":{"display_name":"麵包"}}
	var inventory = inventory_script.new()
	inventory.configure(items)
	var service = script.new()
	var player := {"coin":10,"inventory":{}}
	var npc := {"coin":2,"inventory":{"bread":2},"relationships":{"player":{"affinity":0}}}
	var before := [player.duplicate(true),npc.duplicate(true)]
	var rejected: Dictionary = service.buy(player,npc,"bread",0,4,items,inventory)
	if bool(rejected["ok"]) or player != before[0] or npc != before[1]: return false
	var bought: Dictionary = service.buy(player,npc,"bread",2,4,items,inventory)
	return bool(bought["ok"]) and player["coin"] == 2 and player["inventory"]["bread"] == 2 and npc["coin"] == 10 and npc["inventory"].get("bread",0) == 0
```

- [ ] **Step 2: Run and verify failure**

Run: `run_echo_village.bat --test`

Expected: new suite fails because TradeService is absent.

- [ ] **Step 3: Implement preflight-before-mutation transactions**

Validate amount, item, inventory, and coins before any assignment. Then transfer exact totals through InventoryService and return existing result keys. Implement price using affinity clamp and food-shortage multiplier exactly as current facade code.

- [ ] **Step 4: Delegate facade methods**

Preload one service instance. `GameManager` delegates price and transfer mechanics, then only on success creates the existing trade memory, emits an isolated inventory snapshot, and logs the existing Chinese message.

- [ ] **Step 5: Test and commit**

Run: `run_echo_village.bat --test`

Expected: exit `0`, including existing trade atomicity checks.

```powershell
git add scripts/services/trade_service.gd scripts/core/game_manager.gd tests/suites/trade_service_test.gd tests/test_runner.gd
git commit -m "refactor: extract atomic trade service"
```

### Task 2: GameStateSerializer

**Files:**
- Create: `scripts/save/game_state_serializer.gd`
- Create: `tests/suites/game_state_serializer_test.gd`
- Modify: `scripts/core/game_manager.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `serialize(state: Dictionary) -> Dictionary`
- `deserialize(data: Dictionary, defaults: Dictionary) -> Dictionary`
- `encode_value(value)` / `decode_value(value)` preserve Vector2 recursion

- [ ] **Step 1: Write failing round-trip and isolation tests**

```gdscript
extends RefCounted
static func run() -> bool:
	var script = load("res://scripts/save/game_state_serializer.gd")
	if script == null: return false
	var service = script.new()
	var state := {"player":{"position":Vector2(2,3)},"npcs":{},"economy":{},"active_event":{},"event_log":[],"memory_sequence":0,"community":{},"current_location":"village_square","discovered_locations":["village_square"],"active_quests":{},"completed_quests":[],"world_flags":{},"progression":{}}
	var encoded: Dictionary = service.serialize(state)
	var decoded: Dictionary = service.deserialize(encoded,state)
	encoded["current_location"] = "mutated"
	return encoded["save_version"] == 3 and bool(decoded["ok"]) and decoded["state"]["player"]["position"] == Vector2(2,3) and decoded["state"]["current_location"] == "village_square"
```

- [ ] **Step 2: Run and verify failure**

Run: `run_echo_village.bat --test`

- [ ] **Step 3: Implement and integrate atomically**

Move current encoding mechanics into the service. Deep-copy mutable boundary fields. `deserialize` builds and validates a candidate without mutating inputs. `GameManager.deserialize()` assigns all fields only after `ok == true`; failure returns false with current runtime unchanged.

- [ ] **Step 4: Test compatibility and commit**

Run: `run_echo_village.bat --test`

Expected: v1/v2 migration, v3 progression save, and round-trip tests all pass.

```powershell
git add scripts/save/game_state_serializer.gd scripts/core/game_manager.gd tests/suites/game_state_serializer_test.gd tests/test_runner.gd
git commit -m "refactor: extract atomic game state serializer"
```

### Task 3: NpcMemoryService

**Files:**
- Create: `scripts/npc/npc_memory_service.gd`
- Create: `tests/suites/npc_memory_service_test.gd`
- Modify: `scripts/core/game_manager.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `make_memory(sequence: int, context: Dictionary) -> Dictionary`
- `append_and_trim(npc: Dictionary, memory: Dictionary, maximum: int) -> void`
- `decay(npc: Dictionary, elapsed_days: int, maximum: int) -> void`
- `share_candidate(source: Dictionary, receiver: Dictionary, maximum: int) -> Dictionary`

- [ ] **Step 1: Write deterministic memory tests**

```gdscript
extends RefCounted
static func run() -> bool:
	var script = load("res://scripts/npc/npc_memory_service.gd")
	if script == null: return false
	var service = script.new()
	var npc := {"memories":[]}
	for index in 35: service.append_and_trim(npc,{"id":str(index),"importance":index + 1,"shared":false},32)
	if npc["memories"].size() != 32: return false
	npc["memories"].append({"id":"protected","importance":60,"shared":false})
	service.decay(npc,1,32)
	for memory in npc["memories"]:
		if memory["id"] == "protected" and memory["importance"] != 60: return false
	return true
```

- [ ] **Step 2: Run and verify failure**

Run: `run_echo_village.bat --test`

- [ ] **Step 3: Implement pure mechanics and facade delegation**

The service does not access EventBus, GameTime, relationships, or logs. Context supplies timestamp/location. Sharing returns `{"shared": bool, "memory": Dictionary}`. Keep GameManager public signatures and apply EventBus, relationships, and messages after service success.

- [ ] **Step 4: Test and commit**

Run: `run_echo_village.bat --test`

Expected: all memory decay, social interaction, danger consequence, and simulation tests pass.

```powershell
git add scripts/npc/npc_memory_service.gd scripts/core/game_manager.gd tests/suites/npc_memory_service_test.gd tests/test_runner.gd
git commit -m "refactor: extract NPC memory service"
```

### Task 4: Stable snapshot cache

**Files:**
- Create: `scripts/core/snapshot_cache.gd`
- Create: `tests/suites/snapshot_cache_test.gd`
- Modify: `scripts/core/game_manager.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:** `invalidate(domain)`, `get_or_build(domain, builder)`, and `metrics()`; returned values are isolated copies.

- [ ] **Step 1: Write failing cache tests**

```gdscript
extends RefCounted
static func run() -> bool:
	var script = load("res://scripts/core/snapshot_cache.gd")
	if script == null: return false
	var cache = script.new()
	var builds := [0]
	var builder := func(): builds[0] += 1; return {"value":builds[0]}
	var first: Dictionary = cache.get_or_build("progression",builder)
	first["value"] = 99
	var second: Dictionary = cache.get_or_build("progression",builder)
	cache.invalidate("progression")
	var third: Dictionary = cache.get_or_build("progression",builder)
	return second["value"] == 1 and third["value"] == 2 and builds[0] == 2
```

- [ ] **Step 2: Implement and integrate**

Cache `progression_snapshot()` and `active_quest_snapshot()`. Invalidate progression after new game, community/progression mutation, and deserialize; invalidate quest after new game, accept, notify, and deserialize. Do not cache per-minute NPC details.

- [ ] **Step 3: Test and commit**

Run: `run_echo_village.bat --test`

Expected: exit `0` and isolation/build-count tests pass.

```powershell
git add scripts/core/snapshot_cache.gd scripts/core/game_manager.gd tests/suites/snapshot_cache_test.gd tests/test_runner.gd
git commit -m "perf: cache stable game state snapshots"
```

### Task 5: NpcSimulationCoordinator

**Files:**
- Create: `scripts/npc/npc_simulation_coordinator.gd`
- Create: `tests/suites/npc_simulation_coordinator_test.gd`
- Modify: `scripts/core/game_manager.gd`
- Modify: `tests/test_runner.gd`

**Interfaces:**
- `choose_action(npc: Dictionary, scores: Dictionary, minimum_score: float) -> Dictionary`
- `advance_position(npc: Dictionary, state_machine, minute: int, location_label: String) -> void`
- `due_for_decision(npc: Dictionary, minute: int, interval: int) -> bool`

- [ ] **Step 1: Add failing deterministic coordinator tests**

Provide fixed score dictionaries and assert highest-score selection, Idle fallback below threshold, exact decision interval behavior, bounded movement toward target, and state-machine update invocation through a test double.

- [ ] **Step 2: Implement pure scheduling and movement decisions**

The coordinator does not access GameTime, EventBus, ActionRegistry, or global NPC collections. It returns `{"action": String, "score": float}` and mutates only the supplied NPC during movement.

- [ ] **Step 3: Delegate GameManager decision selection and movement mechanics**

Keep action start/cancel, cooldowns, event emission, logs, eating, and social consequences in the facade. Delegate only due checks, score selection, and movement calculation so behavior stays characterized.

- [ ] **Step 4: Test and commit**

Run: `run_echo_village.bat --test`

Expected: exit `0`, including Utility AI, state machine, weather, seven-day simulation, and decision-log tests.

```powershell
git add scripts/npc/npc_simulation_coordinator.gd scripts/core/game_manager.gd tests/suites/npc_simulation_coordinator_test.gd tests/test_runner.gd
git commit -m "refactor: extract NPC simulation coordination"
```

### Task 6: Core boundary audit

**Files:**
- Modify: `docs/architecture.md`
- Modify: `docs/completion_audit.md`

- [ ] **Step 1: Run complete parser and regression checks**

Run: `tools\godot\Godot_v4.5.2-stable_win64_console.exe --headless --path . --editor --quit-after 4`

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate_project.ps1`

Run: `run_echo_village.bat --test`

Expected: all exit `0`, no parser/runtime errors.

- [ ] **Step 2: Document ownership and commit**

Document TradeService, GameStateSerializer, NpcMemoryService, SnapshotCache, and retained GameManager facade compatibility.

```powershell
git add docs/architecture.md docs/completion_audit.md
git commit -m "docs: record optimized core service boundaries"
```
