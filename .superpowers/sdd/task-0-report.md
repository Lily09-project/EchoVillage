# Task 0: Clean-worktree baseline repair

## Result

Completed on `codex/code-optimization`. Concrete Action scripts now extend their base scripts by explicit resource path, so they no longer rely on a previously generated Godot global-class cache. `UtilityAction` retains `class_name` for compatibility.

`run_echo_village.bat --test` now:

- runs structural validation;
- starts a cache/bootstrap parser preflight (`--headless --editor --import --quit`) and exits before the simulation if it fails;
- uses PowerShell-owned spawned processes with finite limits: 60 seconds for preflight and 120 seconds for tests; and
- treats `SCRIPT ERROR` and `ERROR: Failed to load script` as failures.

The suite now includes a regression contract that verifies each of the ten concrete Action files declares the explicit `utility_action.gd` dependency, loads, instantiates, and supplies its expected action ID.

## RED evidence

Command (after deleting only the generated project-local `.godot` directory):

```powershell
$process = Start-Process -FilePath $godot -ArgumentList @('--headless','--path',$root,'--quit-after','8','--scene','res://tests/TestRunner.tscn') ...
if(-not $process.WaitForExit(25000)){ Stop-Process -Id $process.Id -Force }
```

Output (concise):

```text
SCRIPT ERROR: Parse Error: Could not resolve script "res://scripts/actions/eat_action.gd".
SCRIPT ERROR: Parse Error: Could not resolve script "res://scripts/actions/sleep_action.gd".
... eight more concrete Action scripts ...
SCRIPT ERROR: Compile Error: Failed to compile depended scripts.
ERROR: Failed to load script "res://scripts/core/game_manager.gd" with error "Compilation failed".
ERROR: FAIL  Concrete Action scripts use explicit dependencies and instantiate
TIMEOUT_TERMINATED
```

The explicit 25-second outer bound safely stopped the faulty seven-day simulation rather than allowing an unbounded error log.

## GREEN evidence

Cache-clean focused regression command (after deleting only generated `.godot`):

```powershell
$process = Start-Process -FilePath $godot -ArgumentList @('--headless','--path',$root,'--scene','res://tests/TestRunner.tscn') ...
$process.WaitForExit(120000)
```

Output:

```text
PASS  Concrete Action scripts use explicit dependencies and instantiate
Echo Village 測試：77 通過，0 失敗
```

Structural validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate_project.ps1
```

Output:

```text
PASS: structural and JSON validation completed for C:\Users\user\Documents\Codex\EchoVillage\.worktrees\code-optimization
validate_exit=0
```

Complete cache-clean batch suite (with `GODOT_EXECUTABLE` set to the required bundled console executable):

```powershell
cmd.exe /d /c call .\run_echo_village.bat --test
```

Output:

```text
PASS: structural and JSON validation completed for C:\Users\user\Documents\Codex\EchoVillage\.worktrees\code-optimization
PASS  Concrete Action scripts use explicit dependencies and instantiate
Echo Village 測試：77 通過，0 失敗
Test process exit code: 0.
batch_exit=0
```

The full batch output contained neither `SCRIPT ERROR` nor `ERROR: Failed to load script`.

## Self-review

- Preserved the ten-action registry ordering and the public `UtilityAction` global class API.
- Made no gameplay, save, input, UI, or visual changes.
- Confirmed `git diff --check` passes.
- Excluded generated `.godot`, temporary logs, and regenerated simulation report from the commit.
