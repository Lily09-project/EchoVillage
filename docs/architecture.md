# Echo Village 技術架構

## 設計目標

架構以「內容可擴充、模擬可測試、失敗可復原」為核心。NPC、事件、任務、配方與地點由 JSON 驅動；決策、狀態、導航、經濟、任務與存檔各自有清楚責任。

## 執行流程

1. `GameTime` 推進分鐘並發出時間訊號。
2. `GameManager` 更新需求、情緒、事件時限與記憶衰減。
3. 每十個遊戲分鐘，`ActionRegistry` 讓十種 Action 計算可解釋分數。
4. 最高分 Action 啟動，`NPCStateMachine` 設定移動或執行狀態。
5. `NavigationCoordinator` 使用 `NavigationRegion2D` 與每位居民的 `NavigationAgent2D` 移動；停滯四秒會安全復原。
6. 狀態、記憶、關係與世界變更透過 `EventBus` 讓 UI 更新。

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
| `SaveManager` | v3 世界狀態、自動存檔、偏好與舊版遷移 |
| `SoundManager` | 可關閉的程式化 UI／互動提示音 |
| `AIService`（Optional） | 結構化文本、記憶摘要、建議目標與模板 fallback；不改權威狀態 |

`GameManager.timeline_events` 會將重要 log 轉成結構化「回音事件」，保存遊戲日、分鐘、日夜階段、地點、分類與玩家可讀訊息。`timeline_snapshot()` 提供依日期、分類與數量上限的唯讀查詢，`daily_summary()` 則聚合居民、世界、任務、經濟、地點與進展分類，供村落編年面板的「今日回音」模式使用。主介面只保存歷史日期／分類篩選等暫時 UI 狀態，不污染存檔資料。時間軸隨世界狀態一起序列化，舊版存檔缺少此欄位時安全使用空集合。

## 資料契約

每位 NPC runtime 至少包含位置、目標、需求、背包、關係、記憶、情緒、Action、State、所在地、目前目標與暫時修正。記憶包含主體、客體、地點、時間、重要度、情緒值與 metadata；低重要度記憶每日衰減，高重要度生命事件受到保護。

## 擴充方式

- 新居民：加入 `npc_profiles.json`，提供住宅、工作、個性、對話與作息。
- 新事件：加入 `world_events.json`，在事件處理器定義需要的可追溯後果。
- 新行動：建立 Action 策略並註冊到 `ActionRegistry`；狀態映射加入 State Machine。
- 新任務／地點／配方：只需擴充對應 JSON，服務層會驗證資料。
- 新成就：加入 `achievements.json` 的條件定義；ProgressionService 只讀權威快照並回傳解鎖結果。

## 防故障策略

- 交易、製作與任務獎勵先驗證再一次提交，失敗不消耗資源。
- 世界事件以剩餘分鐘管理，能正確跨越午夜。
- Action 有 90 分鐘狀態逾時；導航另有四秒停滯復原。
- 測試 BAT 同時檢查退出碼與 Godot runtime 錯誤字串。
