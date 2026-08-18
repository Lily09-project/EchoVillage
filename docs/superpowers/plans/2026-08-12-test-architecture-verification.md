# Test Architecture and Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve one-command testing while isolating optimization contracts and producing final runtime, visual, launcher, and security evidence.

**Architecture:** `test_runner.gd` remains the entry and legacy characterization home; focused suites expose sync or async functions. A PowerShell verifier runs validation, parser, tests, performance assertions, tracked-file safety, and secret-pattern checks into a machine-readable report.

**Tech Stack:** Godot 4.2+、GDScript、PowerShell、Git、existing visual QA pipeline。

## Global Constraints

- `run_echo_village.bat --test` remains the single test entry.
- Generated transient logs and `.godot` cache are not committed.
- Security checks never print matched secret values。
- Any failed final check is reproduced, fixed with a regression test, and followed by two clean full verification runs.

---

### Task 1: Focused suite registry

**Files:**
- Create: `tests/test_suite_registry.gd`
- Modify: `tests/test_runner.gd`
- Modify: `tools/validate_project.ps1`

**Interfaces:**
- `sync_suites() -> Array[Dictionary]`
- `async_suites() -> Array[Dictionary]`
- Registry entries contain exact `name`, `path`, and `method` fields.

- [ ] **Step 1: Write a failing registry contract**

```gdscript
func optimization_suite_registry_test() -> bool:
	var script = load("res://tests/test_suite_registry.gd")
	if script == null: return false
	var registry = script.new()
	var names: Array[String] = []
	for entry in registry.sync_suites() + registry.async_suites():
		if not entry.has_all(["name","path","method"]): return false
		if str(entry["name"]) in names or load(str(entry["path"])) == null: return false
		names.append(str(entry["name"]))
	return names.size() >= 6
```

- [ ] **Step 2: Run and verify failure**

Run: `run_echo_village.bat --test`

Expected: registry check fails because the script is absent.

- [ ] **Step 3: Implement explicit deterministic registry**

```gdscript
class_name TestSuiteRegistry
extends RefCounted

func sync_suites() -> Array[Dictionary]:
	return [
		{"name":"UI 刷新排程器","path":"res://tests/suites/ui_refresh_scheduler_test.gd","method":"run"},
		{"name":"HUD 呈現器","path":"res://tests/suites/hud_presenter_test.gd","method":"run"},
		{"name":"交易服務","path":"res://tests/suites/trade_service_test.gd","method":"run"},
		{"name":"狀態序列化服務","path":"res://tests/suites/game_state_serializer_test.gd","method":"run"},
		{"name":"NPC 記憶服務","path":"res://tests/suites/npc_memory_service_test.gd","method":"run"},
		{"name":"快照快取","path":"res://tests/suites/snapshot_cache_test.gd","method":"run"}
	]

func async_suites() -> Array[Dictionary]:
	return [{"name":"主場景閒置刷新","path":"res://tests/suites/ui_refresh_scheduler_test.gd","method":"main_integration"}]
```

Update TestRunner to iterate these entries and call `check`; await async entries with `self` as host. Replace direct optimization-suite calls to prevent duplicates.

- [ ] **Step 4: Extend structural validation**

Add the registry plus every new service, presenter, scheduler, and suite path to `$required` in `tools/validate_project.ps1`.

- [ ] **Step 5: Test and commit**

Run: `run_echo_village.bat --test`

Expected: exit `0`, every suite result appears once.

```powershell
git add tests/test_suite_registry.gd tests/test_runner.gd tools/validate_project.ps1
git commit -m "test: add focused optimization suite registry"
```

### Task 2: Split legacy test domains

**Files:**
- Create: `tests/suites/core_gameplay_suite.gd`
- Create: `tests/suites/ui_contract_suite.gd`
- Create: `tests/suites/progression_save_suite.gd`
- Modify: `tests/test_runner.gd`
- Modify: `tests/test_suite_registry.gd`

**Interfaces:** Each suite provides `run(host: Node) -> Array[Dictionary]`; result entries contain `name` and `passed`.

- [ ] **Step 1: Add a test-count parity guard**

Before moving functions, record the current legacy check count. Add a runner assertion that the combined legacy and suite result count is not lower, and reject duplicate names.

- [ ] **Step 2: Move tests by ownership without changing assertions**

Move pure core/gameplay checks to `core_gameplay_suite.gd`, scene/UI async checks to `ui_contract_suite.gd`, and progression/save/migration checks to `progression_save_suite.gd`. Pass `host` for `add_child`, `get_tree`, and awaited frames. Keep runner reporting and JSON output unchanged.

- [ ] **Step 3: Run parity and regression checks**

Run: `run_echo_village.bat --test`

Expected: exit `0`; total result count is at least the pre-split baseline plus new optimization contracts, with zero duplicate names.

- [ ] **Step 4: Commit**

```powershell
git add tests/test_runner.gd tests/test_suite_registry.gd tests/suites/core_gameplay_suite.gd tests/suites/ui_contract_suite.gd tests/suites/progression_save_suite.gd
git commit -m "test: split monolithic regression suites"
```

### Task 3: Reproducible verifier

**Files:**
- Create: `tools/verify_optimization.ps1`
- Create: `tests/performance/optimization_verification.json`
- Modify: `.gitignore`

**Interfaces:** Command `powershell -NoProfile -ExecutionPolicy Bypass -File tools\verify_optimization.ps1`; exit `0` only on a complete pass.

- [ ] **Step 1: Implement fail-fast command execution**

Resolve root from `$PSScriptRoot` and bundled console Godot explicitly. Run validator, editor parse, `.bat --test`, and UI measurement with `Start-Process -Wait -PassThru -NoNewWindow`; capture command name, exit code, and elapsed milliseconds.

```powershell
function Invoke-CheckedProcess {
  param([string]$Name,[string]$FilePath,[string[]]$ArgumentList)
  $watch = [Diagnostics.Stopwatch]::StartNew()
  $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow
  $watch.Stop()
  [pscustomobject]@{ name=$Name; exit_code=$process.ExitCode; elapsed_ms=$watch.ElapsedMilliseconds; passed=($process.ExitCode -eq 0) }
}
```

- [ ] **Step 2: Add safe tracked-file checks**

Use `git ls-files`; reject tracked `.env`, private-key extensions, save files, `.godot`, engine executables, ZIP/PCK release artifacts, common token assignment patterns, private-key headers, and personal email addresses. Store only rule IDs and paths, never match content.

- [ ] **Step 3: Write verification JSON**

Include timestamp, `godot --version`, commit hash, command results, UI measurement summary, security findings, and `passed`. Write UTF-8 JSON to `tests/performance/optimization_verification.json`.

- [ ] **Step 4: Run and commit**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tools\verify_optimization.ps1`

Expected: exit `0` and report `passed: true`.

```powershell
git add tools/verify_optimization.ps1 tests/performance/optimization_verification.json .gitignore
git commit -m "test: automate optimization verification"
```

### Task 4: Visual and launcher smoke test

**Files:**
- Modify: `docs/completion_audit.md`
- Modify: `docs/test_plan.md`
- Verify: `tests/visual_qa/*.png`

- [ ] **Step 1: Regenerate all visual captures**

Run: `tools\godot\Godot_v4.5.2-stable_win64_console.exe --path . -- --visual-qa`

Expected: exit `0`, eleven `VISUAL_CAPTURE` lines, every image 1280×720.

- [ ] **Step 2: Inspect all eleven images**

Check menu, settings, trade, progression, intro, dawn, noon, night, danger, quest, and forest completion for clipping, contrast, layering, stale values, and layout changes.

- [ ] **Step 3: Smoke-test the launcher safely**

Start `run_echo_village.bat`, record the new Godot process ID, verify its command line contains this repository path and its main window appears, then close only that recorded process. Never terminate pre-existing Godot processes.

- [ ] **Step 4: Document and commit evidence**

Record exact commands, dates, exit codes, dimensions, launcher result, and fixes.

```powershell
git add docs/completion_audit.md docs/test_plan.md tests/visual_qa
git commit -m "docs: complete optimization QA evidence"
```

### Task 5: Final clean verification

**Files:** Modify only when a reproduced defect requires a scoped fix.

- [ ] **Step 1: Confirm clean worktree**

Run: `git status --short`

Expected: empty output.

- [ ] **Step 2: Run complete verifier twice**

Run twice: `powershell -NoProfile -ExecutionPolicy Bypass -File tools\verify_optimization.ps1`

Expected: both runs exit `0`; no intermittent failure.

- [ ] **Step 3: Review final changes**

Run: `git diff HEAD~12..HEAD --check`

Run: `git log --oneline -12`

Expected: no whitespace errors; every commit is an independently verified task.

- [ ] **Step 4: Repair any failure before completion**

Reproduce with the narrowest command, add or strengthen the regression test, apply the smallest correction, rerun the narrow test, then rerun both complete verification passes. Completion requires both passes green.
