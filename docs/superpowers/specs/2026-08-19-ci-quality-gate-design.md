# Echo Village CI 品質閘門設計

## 背景與目標

Echo Village 已有可重複的 Windows Godot 測試入口，但目前每次驗證仍依賴本機安裝與人工執行。這次升級的目標是讓 GitHub push／Pull Request 自動在乾淨的 Windows runner 上重現同一套結構驗證與 Godot 測試，並保留可下載的測試報告，讓專案具備正式 side project 應有的工程可信度。

## 方案

- 使用 GitHub Actions `windows-latest`，因為專案的啟動與發行入口是 Windows `.bat`。
- 固定下載 Godot `4.5.2-stable` 官方 Windows runtime，避免「本機能跑、CI 不能跑」的版本漂移。
- CI 透過 `GODOT_EXECUTABLE` 呼叫既有 `run_echo_village.bat --test`，不複製另一套測試邏輯。
- workflow 必須檢查結構驗證、Godot 測試退出碼、`TEST_RESULT passed=`、`failed=0` 與 Script／load error；任一項失敗即 fail closed。
- 無論成功或失敗都上傳 `tests/simulation_test_report.json`（若檔案已產生），方便審查與回歸追蹤。

## 觸發與安全

- `push`：`master` 與 `codex/**` 分支。
- `pull_request`：目標為 `master`。
- `workflow_dispatch`：允許手動重跑。
- workflow 僅授予 `contents: read`，不使用 secrets、不上傳遊戲存檔、不提交 CI 產物。
- 依賴下載 URL 固定在官方 `godotengine/godot-builds` 的 `4.5.2-stable` tag，不使用浮動最新版。

## 驗收

1. YAML 具備觸發、權限、Windows runner、Godot 安裝、測試與 artifact upload 步驟。
2. 本機 `tools/validate_project.ps1` 與 `run_echo_village.bat --test` 仍維持通過。
3. README 明確說明 CI 觸發條件、固定引擎版本與 artifact 位置。
4. workflow 不包含 token、password、API key、`TODO` 或未定義 placeholder。
