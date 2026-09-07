# Echo Village v1.4.0 Release Checklist

這份 checklist 用於可重現的版本交付。v1.4.0 的驗收已完成；下方保留勾選結果作為 release evidence。GitHub Release 與 deployment 不包含在本機驗收範圍內。

## Source readiness

- [x] `project.godot`、README、CHANGELOG、`RELEASE_README.txt` 版本一致為 `1.4.0`。
- [x] 新資料、scene、script、UID、測試與文件都已納入 v1.4.0 Git commit。
- [x] 沒有 `.env`、真實存檔、`.godot`、release 或 engine binary。
- [x] `git diff --check` 通過。

## Quality gate

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate_project.ps1
.\run_echo_village.bat --test
powershell -NoProfile -ExecutionPolicy Bypass -File quality\run_acceptance.ps1 release
powershell -NoProfile -ExecutionPolicy Bypass -File quality\run_acceptance.ps1 nightly
```

驗收門檻：99 tests、0 failures、security audit 0 findings、無 `SCRIPT ERROR`；release profile 5/5 gates 通過，nightly 的 90 日 soak 全部門檻通過。

## User-facing QA

```bat
set ECHO_VILLAGE_VISUAL_QA=1
tools\godot\Godot_v4.5.2-stable_win64.exe --path .
```

檢查主選單、首次導覽、探索、交易、村落手札、故事線、關係歷程、NPC 決策說明、任務、危險事件與設定；15 張圖片必須為 1280×720，且沒有重疊、截斷或低對比文字。

## Portable QA

```bat
build_release.bat
```

確認 `release/EchoVillage/` 內有 `EchoVillage.exe`、`EchoVillage.pck`、`README.txt` 與 `THIRD_PARTY_NOTICES.txt`，再執行 packaged smoke test。不要把 `release/` 加入 Git。

## Reviewer handoff

審查者應先看：

1. `README.md`：產品定位、操作、截圖與可重現命令。
2. `docs/architecture.md`：NPC、故事線、存檔與服務邊界。
3. `docs/story_system.md`：Living Stories 資料契約與後果模型。
4. `tests/simulation_test_report.json`：最新測試證據。
5. `CONTRIBUTING.md`／`SECURITY.md`：後續維護與漏洞回報流程。
