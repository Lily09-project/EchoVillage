# Contributing to Echo Village

感謝你想改善 Echo Village。這個專案是 Godot 4.2+、GDScript、JSON data contracts 的 offline-first side project；核心目標是讓 NPC simulation 可解釋、內容可擴充、失敗可復原。

## 開發環境

- Windows 10/11 64-bit
- Godot 4.5.2 stable（最低支援 4.2+）
- Git
- 將 console runtime 放在 `tools/godot/`，或設定 `GODOT_EXECUTABLE`。

一般啟動：

```bat
run_echo_village.bat
```

## 修改流程

1. 先閱讀 `README.md`、`docs/architecture.md` 與相關資料契約。
2. 將變更放在正確邊界：`data/` 管內容、service 管 domain rule、`scripts/main.gd`／`scripts/ui/` 管 presentation。
3. 不要從 UI 直接修改權威世界狀態；使用 `GameManager` facade、domain service 與 `EventBus`。
4. 新行為先補會失敗的 contract test，再實作最小完整流程。
5. 若影響畫面，補 Visual QA 情境並人工檢查 1280×720 的遮擋、對比、文字截斷與鍵盤路徑。
6. 若影響存檔，保留 save envelope／schema 相容性，並補 migration、損壞輸入與 atomicity 測試。

## 必跑驗證

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate_project.ps1
$env:ECHO_VILLAGE_TEST_STORAGE_ROOT = "C:\temp\EchoVillage_tests"
.\run_echo_village.bat --test
```

目前 release contract 要求：

- `98 passed / 0 failed`
- security audit `finding_count=0`
- console 不含 `SCRIPT ERROR` 或 script load failure
- 14 張 Visual QA 圖片皆為 `1280×720`

若更新測試數量，請同步更新 `.github/workflows/ci.yml`、README、`docs/test_plan.md`、CHANGELOG 與 PR 說明。

## Commit 與 Pull Request

- Commit 使用清楚、可搜尋的動詞開頭，例如 `feat:`, `fix:`, `test:`, `docs:`。
- 一個 PR 聚焦一個使用者問題，避免將無關格式化混入功能變更。
- PR 必須填寫 template，附上測試結果與必要的實機畫面。
- 不提交 `.env`、API key、token、password、真實 `user://` 存檔、`.godot/`、`release/` 或 engine binary。

## 架構與產品原則

- Optional AI provider 只能產生結構化文字，不能直接修改權威狀態。
- 交易、製作、任務、故事選擇與存檔都必須在 domain/service 層重新驗證。
- 失敗流程要提供玩家可理解的 feedback，並保持狀態原子性。
- UI controls 維持清楚 focus、44px 左右觸控尺寸與 Esc／可見關閉路徑。
