# Echo Village v1.4 關係與故事歷程實作計畫

> **For Codex:** 依 Superpowers TDD 與 verification-before-completion 執行；每一階段先看到預期失敗，再寫最小但完整的產品程式碼使其通過。

**Goal:** 讓玩家與作品集審查者能從遊戲內直接追溯互動、記憶與故事選擇造成的結果。

**Architecture:** 以 `CausalityHistoryService` 擴充現有時間軸事件，不建立第二份狀態來源；`GameManager` 寫入並持久化，`main.gd` 以第三種 journal mode 呈現。

**Tech Stack:** Godot 4.5.2、GDScript、JSON save envelope、PowerShell／batch 品質閘門、GitHub Actions。

---

## Task 1：先建立失敗測試

**Files:**
- Modify: `tests/test_runner.gd`

新增四項契約測試：結構化關係／記憶、居民與類型篩選、存檔相容與邊界、關係歷程 UI／快捷鍵。以 `has_method` 與節點存在檢查保持 runner 可執行，確認新測試在產品碼缺少時失敗。

## Task 2：實作因果歷程資料層

**Files:**
- Create: `scripts/history/causality_history_service.gd`
- Modify: `scripts/core/game_manager.gd`

服務提供 `normalize_details`、`query`、`validate_event`、`format_event`。GameManager 注入服務，擴充 `record_timeline_event` 與 `add_log` 的可選參數，並在關係、記憶與故事選擇流程寫入結構化資料。

## Task 3：實作可操作介面

**Files:**
- Modify: `scripts/main.gd`
- Modify: `project.godot`

新增 `relationship_history` 輸入動作與 Y 快捷鍵（避開既有 R 降雨事件）；將 journal 擴充成 chronicle、daily、causality 三模式。重用現有控制列於不同模式，提供可讀空狀態、居民與類型篩選、44px 操作尺寸與 tooltip。

## Task 4：視覺 QA 與文件

**Files:**
- Modify: `scripts/main.gd`
- Add: `tests/visual_qa/relationship_history.png`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/architecture.md`
- Modify: `docs/game_design.md`
- Modify: `docs/test_plan.md`
- Modify: `docs/release_checklist.md`
- Modify: `docs/portfolio_case_study.md`

加入可重複的關係歷程情境，更新截圖數量、核心功能、架構資料流與測試證據。

## Task 5：版本與交付品質閘門

**Files:**
- Modify: `project.godot`
- Modify: `build_release.bat`
- Modify: `RELEASE_README.txt`
- Modify: `.github/workflows/ci.yml`

版本升至 `1.4.0`，CI 精確驗證新測試與新增視覺證據。依序執行結構／JSON 檢查、完整測試、視覺擷取、安全掃描、Windows build、可攜包檔案檢查與 headless smoke test。

## Task 6：GitHub 交付

提交乾淨分支，推送並建立 PR；等待 CI 成功後 squash merge。從合併 commit 建立 `v1.4.0` tag、GitHub Release，附上 Windows 可攜 zip 與 SHA-256。
