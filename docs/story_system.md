# Living Stories 系統

## 目的

Living Stories 把居民互動、任務與世界事件整理成玩家看得懂、可以選擇、也能持久保存的故事線。它不是另一套任務 UI，而是把既有的記憶、關係、村落編年與聲望系統串成一個可擴充的內容層：條件成立時故事浮現，玩家選擇後留下可追蹤的後果。

目前版本提供三條資料驅動故事線：

| ID | 觸發條件 | 玩家可觀察的後果 |
| --- | --- | --- |
| `bread_rumor` | 玩家偷取鮑伯的麵包，村落 `rumor` 旗標成立 | 道歉或否認會改變鮑伯的信任／好感、記憶與村落聲望 |
| `forest_echo_branch` | 任務「林間回音」進入進行中 | 玩家可先照顧黛安娜，或先完成自己的森林準備 |
| `harvest_festival` | 世界事件 `festival` 啟動 | 玩家可投入祭典準備，或保留自己的生活節奏 |

## 資料契約

故事定義放在 `data/stories/story_arcs.json`，每條 arc 包含：

- `id`、`title`、`summary`：穩定識別與玩家文案。
- `trigger`：`community_flag`、`quest_active`、`active_event` 或 `world_flag`。
- `stages`：有界的階段集合，每階段至少提供一個選擇。
- `choices`：`id`、`label`、`description`、可選的 `next_stage` 與 consequences。
- `consequences`：`relationship`、`memory`、`community`、`world_flag`、`coin` 或 `inventory`。

`StoryArcService` 在載入時驗證 ID 唯一性、文字長度、階段與選擇數量、後果種類與 cross-reference。未通過驗證的資料不會進入 runtime；集合上限與文字上限避免惡意或誤植資料造成無界記憶體成長。

## Runtime 生命週期

1. `GameManager` 建立新世界時重置 `story_progression`。
2. 互動、任務、村落編年與世界事件更新後呼叫 `story_service.refresh()`。
3. 服務只在觸發條件成立時建立 `active` record，並透過 `EventBus.story_arc_updated` 通知 UI。
4. 玩家從 `O` 故事線面板選擇分支；`GameManager.choose_story_arc()` 只接受目前 active stage 的合法 choice。
5. 後果透過既有 domain service 套用，包含關係、記憶、村落聲望／編年、物品與硬幣；最後把 arc 記為 `completed` 或轉移到下一階段。
6. 重複或未知選擇回傳結構化失敗，不會修改任何世界狀態。

UI 只讀 `GameManager.story_snapshot()`，不直接持有權威故事狀態。這讓 headless contract tests 可以在沒有畫面的情況下驗證內容，也避免 UI 事件繞過 domain validation。

## 存檔與相容性

故事進度序列化為世界狀態的 `story_progression` 欄位，維持現有 save envelope 與世界 schema v3。載入舊存檔時若缺少欄位會使用空故事狀態；若內容不符合定義、超過 arc／choice 上限或含未知 ID，整份候選狀態會被拒絕，不會部分覆蓋目前世界。

`SaveManager` 以 `.tmp` 寫入後替換 primary save，並在下一次寫入前保留 `.bak`。若 primary JSON 損壞或 schema 無法載入，會嘗試最後一份有效 backup，成功後回寫 primary 並提供 `get_save_recovery_status()` 供診斷與 UI 使用。

## UI 與操作

- `O` 開啟故事線面板，`Esc` 或「關閉故事線 O」離開。
- 面板列出 active、completed 與 locked 故事；locked 項目 disabled，避免玩家誤以為可互動。
- active stage 顯示選擇標題、描述與兩個以上的 44px 操作按鈕；選擇後會顯示成功／失敗回饋並刷新快照。
- 面板是模態層，開啟期間遊戲時間暫停，且和交易、任務、地圖、背包、手札互斥。
- Visual QA `story_arc_active.png` 固定擷取一條已觸發、尚未選擇的故事線，驗證文字層級、按鈕對比、遮擋與 1280×720 可讀性。

## 測試策略

`tests/test_runner.gd` 覆蓋：

- JSON 資料存在、服務設定與 snapshot shape。
- 觸發、分支選擇、後果套用、完成狀態與序列化 round-trip。
- 未知 choice、重複 choice 的拒絕與原子性。
- 故事面板節點、關閉路徑、模態暫停與快捷鍵。
- 完整 7／30 日模擬、存檔 backup recovery、安全 audit 與 runtime error gate。

新增故事時，先在 JSON 加入資料契約，再補 service／GameManager contract test，最後才加入 UI 與 visual QA。不要在面板中硬編碼故事 ID 或直接修改 NPC dictionary。
