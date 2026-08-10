# Memory and Relationship System

## 記憶格式

每筆記憶包含 `id`、`event_type`、`subject_id`、`object_id`、`location`、`timestamp`、`description`、`importance`、`emotional_value` 與 `metadata`。每位居民最多保存 32 筆；低重要度記憶每日衰減，高重要度生命事件受到保護。

## 記憶傳播

居民社交時可以 Greet、ShareInformation 或 Argue。重要且尚未分享的記憶會在接收者建立 `heard_*` 記憶，並依情緒值間接改變接收者對事件主體的印象。原始記憶保留來源，接收者不會直接修改權威世界狀態。

## 關係

玩家與 NPC、NPC 與 NPC 都使用 affinity、trust、fear、respect，範圍固定為 -100～100。RelationshipService 是唯一純邏輯更新入口；GameManager 只負責發出 signal 與記錄事件。

## 可重現案例

- 玩家贈禮：正向記憶與信任提升。
- 玩家偷竊：負向記憶、信任下降、流言傳給第三人、價格變差。
- 危機救援：被幫助者記住協助者，增加 affinity、trust 與 respect。
