# Echo Village v1.4.0 Release Checklist

這份 checklist 用於可重現的版本交付。v1.4.0 的驗收已完成；下方保留勾選結果作為 release evidence。GitHub Release 與 deployment 不包含在本機驗收範圍內。

## 目前候選修補（尚未發布）

歷史 v1.4.0 的勾選結果不適用於目前 PR。候選自動測試契約為 105 tests、0 failures，並保留 secret scan、安全掃描與四解析度視覺檢查。

- [ ] 最新 SHA 的 CI 全成功，portable candidate 使用已校驗的官方 4.5.2 export templates。
- [ ] 核對 candidate-manifest.json 的 source_sha 與 SHA256SUMS.txt。
- [ ] 在未安裝 Godot 的乾淨 Windows 10/11 開啟候選 EXE，完成首次導覽、探索、交易、任務、設定與鍵盤操作。
- [ ] 使用新資料目錄驗證存檔、重開後讀檔、壞檔與備份復原、無法寫入時的錯誤回饋。
- [ ] 人工確認 1280×720、1366×768、1600×900、1920×1080 無遮擋、截斷或不可操作控制項。
- [ ] 審查新套件檔案、來源、版號、第三方聲明與安全結果後才建立正式 Release；CI artifact 的 headless 啟動成功不等於 GUI 驗收通過。

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

先在 editor 安裝對應 4.5.2 stable 的官方 export templates；腳本使用 `--export-release`，不再接受 `GODOT_RUNTIME` 任意指定執行檔。每個 notice 複製失敗與 packaged smoke test 超時都必須阻止交付。

確認 `release/EchoVillage/` 內有 `EchoVillage.exe`、`EchoVillage.pck`、`README.txt` 與 `THIRD_PARTY_NOTICES.txt`，再執行 packaged smoke test。不要把 `release/` 加入 Git。

## Reviewer handoff

審查者應先看：

1. `README.md`：產品定位、操作、截圖與可重現命令。
2. `docs/architecture.md`：NPC、故事線、存檔與服務邊界。
3. `docs/story_system.md`：Living Stories 資料契約與後果模型。
4. `tests/simulation_test_report.json`：最新測試證據。
5. `CONTRIBUTING.md`／`SECURITY.md`：後續維護與漏洞回報流程。
