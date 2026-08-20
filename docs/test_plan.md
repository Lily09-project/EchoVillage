# Echo Village 測試計畫

## 自動化入口

`run_echo_village.bat --test` 先執行結構與 JSON 驗證，再執行 Godot 測試場景；任何斷言、Script Error、腳本載入錯誤或非零退出碼都會使流程失敗。

GitHub Actions workflow `.github/workflows/ci.yml` 在乾淨 Windows runner 上固定使用 Godot 4.5.2，呼叫同一個 `.bat` 入口，並上傳 `tests/simulation_test_report.json` 作為 artifact。

## 目前覆蓋：98 項

- 資料與 runtime：五位 NPC、必要欄位、獨立住宅、NPC 對 NPC 關係。
- 長時間模擬：七日加速，需求保持 0–100，狀態與 Action 有效。
- AI 架構：十種 Action Registry、評分反應、State Machine 轉換與逾時。
- 記憶與社會：建立、傳播、關係影響、衰減、容量與重要記憶保護。
- 經濟：關係價格、糧食短缺、原子買賣、無效交易不改狀態。
- 任務與製作：完整林間回音流程、原子交付、配方、獎勵冪等。
- 事件：跨午夜生命週期、受傷後果與可追溯記憶。
- 回音時間軸：事件分類、每日摘要、歷史日期回看、分類篩選、序列化還原與「今日回音」快捷鍵入口。
- 因果歷程：關係 before／after、實際 delta、記憶 metadata、故事 arc／choice、居民／類型篩選、深拷貝、舊事件相容與超長 actor 拒絕。
- 存檔：手動、自動、偏好、舊版遷移、v3 世界狀態、村落進展與 `.bak` recovery 還原。
- Living Stories：三條 JSON arc 的 trigger、snapshot、分支後果、完成冪等性、未知／重複 choice 拒絕與 serialization round-trip。
- 進展：五級聲望邊界、六項成就條件、未知條件、冪等解鎖、遊戲觸發與舊存檔預設。
- UI／輸入：主選單、設定、HUD、交易、背包、任務、地圖、故事線、Debug；模態互斥、Esc 關閉、暫停與 44px 操作尺寸。
- 首次旅程：新遊戲三步驟導覽、下一步／略過／Esc、`onboarding_seen` 偏好與暫停選單 `F1` 重開；同時驗證指南按鈕不與動態開關重疊。
- 可及性：設定選取狀態文字對比、清楚焦點與完整鍵盤路徑。
- Navigation：五個實際 Agent、路徑偵錯與停滯復原。
- 安全邊界：JSON 解析前的 4 MiB 存檔／64 KiB 偏好檔 byte 上限、損壞／竄改／超大集合拒絕、偏好型別白名單、malformed `Vector2`、非法時間欄位、深層巢狀資料與混合型別 Optional AI context fuzz，以及 tracked-file secrets／私鑰／release artifact 稽核；直接 `GameManager.deserialize()` 必須以原子方式拒絕不可信狀態。
- 測試隔離：Debug 測試透過 `ECHO_VILLAGE_TEST_STORAGE_ROOT` 或 `.test-data/` 儲存存檔／偏好暫存，禁止回歸測試覆寫開發者的真實 `user://` 資料。

## 視覺 QA

設定 `ECHO_VILLAGE_VISUAL_QA=1` 並啟動 GUI runtime，使用實際 GPU 產生十四張 1280×720 PNG：主選單、設定、交易、村落手札、active 故事線、關係歷程、首次旅程導覽、開場、黎明、正午、夜晚、危險事件、任務進行與森林完成。人工檢查遮擋、對比、層級、文字截斷與畫面一致性。

## 發行驗證

`build_release.bat` 依序執行：98 項測試 → PCK 匯出 → portable runtime 組裝 → 120 幀成品煙霧測試。最後另檢查成品檔案、大小與殘留程序。

## 安全稽核

`tools/security_audit.ps1` 以 `git ls-files` 為邊界，檢查 secrets／private key pattern、`.env`、使用者 save/preferences、`.godot`／release 目錄與 engine binary。稽核報告寫入被 `.gitignore` 排除的 `tests/security_audit_report.json`，CI 會驗證 `passed=true` 且 `finding_count=0`；不會把匹配到的敏感內容印出。

## 驗收條件

- 自動測試 0 失敗。
- Console 不含 `SCRIPT ERROR` 或腳本載入失敗。
- 十四張視覺證據齊全且尺寸正確，包含首次旅程導覽、故事線 active choice、關係歷程與按鈕層級。
- `EchoVillage.exe` 可從 release 資料夾載入同名 PCK。
- 一鍵啟動可透過 bundled runtime 或 `GODOT_EXECUTABLE` 執行；一鍵建置在明確設定 `GODOT_RUNTIME`（或提供 bundled GUI runtime）後不依賴系統 PATH，且不會把 console bootstrap 誤包成玩家執行檔。
