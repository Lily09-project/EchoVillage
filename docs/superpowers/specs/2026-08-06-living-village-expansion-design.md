# Echo Village Living Village Expansion — Design

## Purpose

將目前的「可解釋 NPC 展示版」升級為可長期開發的 2D 生活模擬 RPG 底座。擴充後的專案必須仍可用 `run_echo_village.bat` 啟動、保留既有五名 NPC 和 Showcase 情境，並讓新地圖、任務、NPC、物品與劇情後果以資料檔加入，而不是把規則塞進主場景。

## Scope and staged delivery

這是由數個獨立系統組成的計畫，因此拆為下列可單獨驗收的交付階段；每一階段都要保持遊戲可玩、存檔可讀且完整測試通過。

1. **Foundation**：可版本遷移的世界狀態、服務邊界、資料驗證與回歸測試。
2. **Playable systems**：任務、位置／地圖切換、製作／交付、聲望解鎖與任務追蹤 UI。
3. **Content slice**：森林邊緣、第二個可互動區域、三條任務鏈、八名 NPC 與可探索百科。
4. **Polish and evidence**：新 UI 的可見焦點、無障礙關閉路徑、視覺 QA、存檔遷移測試與作品集文件。

本次實作首先完成 Foundation 加上第一條可玩的任務鏈；後續內容使用同一套資料／服務合約疊加，不需要重寫核心。

## Architecture

### Runtime ownership

`GameManager` 不再同時擁有所有資料與規則，而是保留為現有程式相容的 façade 和總協調者。新系統以純 GDScript `RefCounted` 服務提供單一職責 API，並只由 `GameManager` 建立／更新：

| Unit | Responsibility | Does not own |
| --- | --- | --- |
| `GameState` | 玩家、NPC runtime、目前位置、探索記錄、任務狀態、世界旗標與 seeded RNG 狀態 | 規則、繪圖、UI 節點 |
| `QuestService` | 載入任務定義、開始／完成／失敗、目標計數、前置條件與獎勵 | 任務畫面、直接改動 UI |
| `LocationService` | 地點資料、鄰接關係、進入條件、目前地點與旅行結果 | NPC 的 Utility 計算 |
| `EconomyService` | 物品堆疊、製作配方、交易價格修正與原子式交付 | 玩家操作按鈕 |
| `RelationshipService` | 關係變動、記憶建立與玩家行為造成的敘事旗標 | 模擬時鐘 |
| `SaveMigration` | 將舊存檔轉換到新結構、拒絕未知未來版本、驗證必要欄位 | 遊戲邏輯 |

既有 `GameTime`、`EventBus` 與 `SaveManager` 維持 autoload；`EventBus` 新增帶結構化 payload 的 `quest_changed`、`location_changed`、`inventory_changed` 信號。場景只訂閱這些信號和 read-only snapshot，不直接修改 `GameState`。

### Data contracts

新增資料檔並在啟動時嚴格驗證：

| File | Required data |
| --- | --- |
| `data/world/locations.json` | `id`, `display_name`, `bounds`, `neighbors`, `unlock_requirements`, `landmark_ids` |
| `data/quests/quests.json` | `id`, `title`, `giver_id`, `prerequisites`, ordered `objectives`, `rewards`, `on_complete_flags` |
| `data/items/recipes.json` | `id`, `ingredients`, `output_item`, `output_amount`, `required_location` |
| `data/npcs/npc_profiles.json` | 保留既有 schema，增加 optional `home_location`, `quest_ids`, `faction_id` |

任務目標採封閉型別：`talk_to_npc`、`deliver_item`、`visit_location`、`reach_relationship`。未知型別、重複 ID、缺少 NPC／物品／地點參照或負數數量都使啟動驗證失敗。

### State and persistence

存檔升為 `save_version: 2`，其最小結構固定為：

```json
{
  "save_version": 2,
  "game_time": {},
  "world_state": {
    "player": {},
    "npcs": {},
    "current_location": "village_square",
    "discovered_locations": ["village_square"],
    "active_quests": {},
    "completed_quests": [],
    "world_flags": {}
  }
}
```

`SaveMigration` 必須把既有 `save_version: 1` 的玩家、NPC、時間、編年和世界事件轉換為 v2，並補上 `village_square`、空任務、空探索清單和空旗標。遷移不得刪除既有背包、關係、記憶或聲望資料；新版讀取舊檔後再儲存時才會輸出 v2。

### First playable vertical slice

第一條任務鏈名為「林間回音」：

1. 在村莊廣場與艾莉絲交談，接下「替草藥師送去麵包」任務。
2. 玩家持有一個麵包後旅行到「森林邊緣」，找到草藥師並交付。
3. 任務完成後得到藥草、聲望和一條正向記憶；森林邊緣永久標示為已探索。
4. 若玩家尚無麵包，任務追蹤顯示明確缺少物品，不會消耗任何道具。

這條任務同時驗證任務、物品交付、關係／記憶、位置解鎖、存檔、HUD 追蹤與資料驗證的邊界。

### UI and scene composition

`main.gd` 會逐步縮減成輸入協調、場景層與 UI 組裝。新增可獨立載入的 `scenes/ui/` 元件：

- `QuestTracker`：最多三個進行中任務、目前目標和可用快捷鍵。
- `WorldMapPanel`：已探索地點、鎖定地點與旅行按鈕；Esc 和可見關閉按鈕皆可退出。
- `QuestLogPanel`：任務狀態、目標、獎勵、完成記錄。
- `CodexPanel`：已遇見 NPC、地點與事件的唯讀百科。

位置切換初期不使用 3D、串流世界或隨機地圖；以同一主場景的 location layout 及安全 travel result 變更可見地標與可互動 NPC，讓既有原創繪本 renderer 可逐步支援多區域。

### Error handling and observability

- 所有資料讀取在 `tools/validate_project.ps1` 與 headless tests 中檢查 schema、ID 唯一性和 cross-reference。
- 玩家嘗試交付不足物品、前往未解鎖地點、重複完成任務或讀取未來存檔時，只回傳可顯示的失敗結果，不改變 `GameState`。
- `EventBus` 記錄結構化事件，保留現有可讀日誌；F3 加入目前 location、active quest 和最近一次拒絕原因。

## Testing and acceptance criteria

每個服務先寫失敗測試，至少涵蓋：

1. v1 存檔完整遷移到 v2 且保留背包、關係、記憶、編年與時間。
2. 任務資料 cross-reference、前置條件、目標順序、完成獎勵與重複完成保護。
3. 旅行鎖定／解鎖、探索記錄與存讀檔 round trip。
4. 製作／交付的原子性：條件不符時物品與任務均不變。
5. 第一條任務鏈從接受到完成的 deterministic end-to-end scenario。
6. UI 場景結構、關閉路徑、輸入映射與可重複視覺 QA capture。
7. 完整測試、Godot editor load、headless game load、實際 GPU QA、`run_echo_village.bat` 啟動 smoke test。

驗收時必須保留現有五個 Showcase 視覺情境，新增「任務進行中」與「森林邊緣完成」兩張 1280×720 視覺 QA 圖。所有測試通過後，更新 README、架構圖、設計文件、作品集 case study 和測試報告。

## Explicit non-goals

- 不導入線上多人、付費系統、戰鬥、程序生成、3D、外部 LLM runtime 或雲端後端。
- 不移除現有展示情境、portable Godot、中文介面或可解釋 Utility AI。
- 不讓 UI 直接改寫世界狀態，也不讓資料檔在 runtime 靜默修正錯誤。
