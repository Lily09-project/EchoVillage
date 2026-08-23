# Echo Village 技術架構

## 設計目標

架構以「內容可擴充、模擬可測試、失敗可復原」為核心。NPC、事件、任務、配方、地點與 Living Stories 由 JSON 驅動；決策、狀態、導航、經濟、任務、故事與存檔各自有清楚責任。

## 執行流程

1. `GameTime` 推進分鐘並發出時間訊號。
2. `GameManager` 更新需求、情緒、事件時限與記憶衰減。
3. 每十個遊戲分鐘，`ActionRegistry` 讓十種 Action 計算可解釋分數。
4. 最高分 Action 啟動，`NPCStateMachine` 設定移動或執行狀態。
5. `NavigationCoordinator` 使用 `NavigationRegion2D` 與每位居民的 `NavigationAgent2D` 移動；停滯四秒會安全復原。
6. 狀態、記憶、關係與世界變更透過 `EventBus` 提交 dirty-region 請求；`UiRefreshScheduler` 將同一幀的重複請求合併後，只更新受影響的 HUD 區域。閒置且暫停時不會重算完整 UI，遊戲進行中則保留逐幀距離提示。
7. 觸發條件成立時，`StoryArcService` 建立 active arc；玩家選擇後以既有 domain service 套用後果，再將結果寫入時間軸與存檔。
8. `CausalityHistoryService` 將關係、記憶與故事結果正規化為 bounded metadata，供 UI 依居民與類型查詢。

## 核心模組

| 模組 | 責任 |
| --- | --- |
| `GameManager` | 世界 runtime、NPC、事件、互動、序列化協調 |
| `ActionRegistry` | Action 註冊、順序與批次評分 |
| `NPCAction` / `UtilityAction` | `can_execute / calculate_score / start / update / finish / cancel` 生命週期 |
| `NPCStateMachine` | Moving、Working、Sleeping 等狀態與逾時復原 |
| `NavigationCoordinator` | Godot 2D 路徑、代理同步與卡住保護 |
| `NeedsService` | Personality-aware 需求成長與 0–100 邊界 |
| `InventoryService` | 玩家／NPC 共用的安全物品增減與查詢 |
| `RelationshipService` | affinity、trust、fear、respect 的一致限制與變更 |
| `WorldEventManager` | 事件資料驗證、啟動、跨日生命週期與效果契約 |
| `QuestService` | 目標進度、獎勵與冪等完成 |
| `EconomyService` | 配方驗證與原子製作 |
| `LocationService` | 地點切換、發現與區域內容 |
| `ProgressionService` | 五級聲望、資料驅動成就、一次性解鎖與安全條件評估 |
| `StoryArcService` | 驗證故事定義、評估觸發、分支選擇、後果套用與序列化狀態 |
| `CausalityHistoryService` | 因果事件 metadata 正規化、存檔驗證、居民／類型查詢、中文摘要與深拷貝邊界 |
| `UiRefreshScheduler` | 合併 TIME／PLAYER／WORLD／NPC／QUEST／PROGRESSION／LOG／CONTEXT／DEBUG dirty mask，提供刷新與合併次數供測試驗證 |
| `SaveManager` | v3 世界狀態、自動存檔、偏好、舊版遷移與 `.bak` recovery |
| `SaveMigration` | 在載入前驗證 envelope／world state 型別、陣列數量上限與版本相容性，拒絕損壞或竄改資料 |
| `Main` onboarding UI | 首次旅程三步驟、模態暫停、Esc／略過、F1 重開；只保存 `onboarding_seen` 偏好，不寫入世界狀態 |
| `SoundManager` | 可關閉的程式化 UI／互動提示音 |
| `AIService`（Optional） | 結構化文本、記憶摘要、建議目標與模板 fallback；不改權威狀態 |

`GameManager.timeline_events` 會將重要 log 轉成結構化「回音事件」，保存遊戲日、分鐘、日夜階段、地點、分類與玩家可讀訊息。`timeline_snapshot()` 提供依日期、分類與數量上限的唯讀查詢，`daily_summary()` 聚合居民、世界、任務、經濟、地點與進展分類。v1.4 的可選 `effect_kind`、`actors` 與 `effect` 由 `CausalityHistoryService` 驗證；`causality_snapshot()` 可依居民與效果類型取得最近 1–50 筆深拷貝。runtime 最多保留 160 筆，actors 最多 4 位、effect 最多 16 鍵且限制遞迴深度。舊版純文字事件仍可載入，但不會被誤認成可追溯因果資料。
`StoryArcService` 同樣只保存可序列化的 `story_progression`，UI 透過 `story_snapshot()` 取得唯讀投影；`EventBus.story_arc_updated` 讓故事面板以事件更新，不需要逐幀輪詢。

### Living Stories 邊界

故事內容位於 `data/stories/story_arcs.json`，每條 arc 具備 trigger、stages、choices 與有限的 consequences。服務層在載入時檢查 ID 唯一性、文字／集合上限、trigger kind、stage cross-reference 與 consequence shape；`apply_choice()` 會先完成全部驗證，才依序呼叫 `change_relationship()`、`create_memory()`、`record_community()` 等既有 domain API。未知 arc、未知 choice、重複 choice 或不合法後果都只回傳失敗結果，不會污染世界。

### 存檔 recovery

`SaveManager.save_game()` 將 payload 先寫入 `echo_village_save.json.tmp` 並 flush／close，然後把目前 primary 複製為 `.bak`，最後替換 primary。`load_game()` 先驗證 primary；若 JSON、envelope 或 world state 不合法，會嘗試 `.bak`，成功後把最後有效資料重新提升為 primary，並以 `get_save_recovery_status()` 暴露 `available`、`using_backup` 與 `reason`。載入候選資料前不會呼叫 `GameManager.deserialize()`，因此損壞檔案不會造成部分 runtime 套用。

### 首次旅程導覽狀態

新遊戲建立後，`Main.start_new_game()` 依 `SaveManager.preferences.onboarding_seen` 顯示三步驟導覽。導覽是純 presentation state：`OnboardingBackdrop` 攔截輸入、`OnboardingPanel` 提供步驟內容，`GameTime.simulation_paused` 透過既有模態規則暫停。完成、略過或按 `Esc` 都會將偏好設為 `true`；暫停選單的 `GuideButton` 以 `force=true` 重開並重置步驟，不改變世界、NPC、任務或存檔版本。

## 資料契約

每位 NPC runtime 至少包含位置、目標、需求、背包、關係、記憶、情緒、Action、State、所在地、目前目標與暫時修正。記憶包含主體、客體、地點、時間、重要度、情緒值與 metadata；低重要度記憶每日衰減，高重要度生命事件受到保護。

## 擴充方式

- 新居民：加入 `npc_profiles.json`，提供住宅、工作、個性、對話與作息。
- 新事件：加入 `world_events.json`，在事件處理器定義需要的可追溯後果。
- 新行動：建立 Action 策略並註冊到 `ActionRegistry`；狀態映射加入 State Machine。
- 新任務／地點／配方：只需擴充對應 JSON，服務層會驗證資料。
- 新成就：加入 `achievements.json` 的條件定義；ProgressionService 只讀權威快照並回傳解鎖結果。
- 新故事：在 `data/stories/story_arcs.json` 加入 trigger、stage、choice 與 consequences，補上 service contract test 與必要的 visual QA；不要在 UI 硬編碼故事規則。

## 防故障策略

- 交易、製作與任務獎勵先驗證再一次提交，失敗不消耗資源。
- 世界事件以剩餘分鐘管理，能正確跨越午夜。
- Action 有 90 分鐘狀態逾時；導航另有四秒停滯復原。
- 測試 BAT 同時檢查退出碼與 Godot runtime 錯誤字串。
- 故事選擇、存檔復原與 UI modal 都有獨立 contract test；GPU visual QA 驗證 active story panel 的層級與對比。
