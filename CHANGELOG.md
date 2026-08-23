# Changelog

## Unreleased

- 將 `UiRefreshScheduler` 正式接入主場景：同一幀的狀態事件會合併，並依 TIME／PLAYER／WORLD／NPC／QUEST／PROGRESSION／LOG／CONTEXT／DEBUG dirty mask 更新介面。
- 移除 `_process()` 每幀重算完整 HUD；暫停閒置時不產生 UI flush，遊戲進行中只保留玩家／NPC 距離提示的逐幀更新。
- 新增主場景整合回歸測試，驗證閒置幀零額外刷新，以及背包與任務事件同幀合併；完整驗收維持 `98 passed / 0 failed`。

## 1.4.0 — 2026-08-20

- 新增 `CausalityHistoryService`，把關係、記憶與故事選擇寫成具演員、類型、前後值與來源 ID 的結構化因果事件。
- 村落編年擴充為三模式：`J` 村落編年、`L` 今日回音、`Y` 關係歷程；可依五位居民與關係／記憶／故事類型篩選。
- 關係變更會保存實際套用後的 delta 與 before／after 快照；故事選擇會保存 arc、choice、顯示名稱與完成狀態。
- 舊版純文字時間軸維持可載入；新增 actors、effect、深度、集合、字串與有限數值安全邊界，runtime 僅保留最近 160 筆。
- 新增關係歷程 GPU 視覺證據；Visual QA 擴充至 14 張 1280×720 實機截圖。
- 完整品質閘門驗收為 `98 passed / 0 failed`，security audit `finding_count=0`，無 `SCRIPT ERROR`。

## 1.3.0 — 2026-08-20

- 新增 `StoryArcService` 與三條資料驅動 Living Stories：失竊的麵包、森林的回聲、秋日祭典。
- 新增 `O` 故事線面板、active／completed／locked 狀態、分支選擇、成功／失敗回饋與模態暫停。
- 故事後果會寫入居民關係、記憶、村落編年、聲望、物品與世界旗標，並隨 v3 世界狀態序列化。
- `SaveManager` 改為 `.tmp` 原子寫入與 `.bak` 最後有效版本復原；primary 損壞時可自動回退並提供 recovery status。
- 新增未知／重複故事選擇拒絕、故事 UI modal、故事序列化與存檔 recovery contract tests。
- GPU Visual QA 擴充至 13 張 1280×720 證據；正式 GUI runtime 實測故事線 active choice 對比與遮擋。
- 完整品質閘門驗收為 `94 passed / 0 failed`，security audit `finding_count=0`，無 `SCRIPT ERROR`。

## 1.2.0 — 2026-08-12

- 新增五級村落聲望與六項資料驅動成就。
- 新增獨立 `ProgressionService`、一次性解鎖與未知條件安全處理。
- 新增繁中「村落手札」模態介面、P 快捷鍵、聲望進度與解鎖通知。
- 世界狀態存檔升級至 v3，舊存檔缺少進展資料時使用安全預設值。
- 自動測試擴充至 76 項，GPU 視覺 QA 擴充至 11 張。

## 1.1.0 — 2026-08-10

- 十種 Utility Action 改為獨立具名腳本，加入最低門檻、冷卻與 Mood 修正。
- 抽離 Inventory、Needs、Relationship 與 WorldEventManager 服務邊界。
- 補上雨天行為效果、危機救援記憶與 NPC 對 NPC 關係後果。
- 新增正式 Talk、NPC 社交模式、森林公共資源採集與完整 F3 診斷。
- 新增平滑 Camera2D、可關閉程式化音效與持久音效設定。
- 新增安全 Optional AIService、Mock Provider 與模板 fallback。
- 自動測試擴充至 66 項，並更新完整需求稽核與作品集文件。

## 1.0.0 — 2026-08-10

- 完成繁體中文消費者主選單、設定、暫停與自動存檔流程。
- 完成五位自主居民、獨立住宅、對話人格與 NPC 對 NPC 關係。
- 導入十種 Action Registry、Utility AI、State Machine 與逾時復原。
- 完成記憶衰減／傳播、動態事件與 NPC 受傷後果。
- 完成雙向交易、完整背包、製作、任務、地圖與森林區域。
- 導入 Godot 2D Navigation、停滯保護與可操作 Debug 面板。
- 完成 48 項自動測試、10 張 GPU 視覺 QA 與 runtime 錯誤閘門。
- 加入免安裝 Windows portable 發行包與一鍵測試建置 BAT。
