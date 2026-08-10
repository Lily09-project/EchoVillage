# NPC Simulation System

每位居民由不會被 runtime 修改的 JSON Profile 與獨立 Runtime State 組成。Profile 定義年齡、職業、住家、工作地點、Personality、Schedule、初始物品、關係與 Dialogue Profile；Runtime 保存位置、需求、Action、State、Goal、Target、Mood、Inventory、Relationship、Memory 與暫時修正。

## 決策管線

`GameTimeManager` 每分鐘更新 Needs；每十個遊戲分鐘，Action Registry 讓十個具名 Action 計算分數。Schedule 只是 modifier，極度飢餓仍可覆蓋工作安排。最低分數、15 分鐘切換冷卻與微小隨機值避免頻繁抖動。

Action 選定後，State Machine 負責 Idle、Moving、PerformingAction、Talking、Sleeping、Working；NavigationCoordinator 使用每位居民獨立的 NavigationAgent2D。行動 90 分鐘或路徑停滯 4 秒會安全回復。

## 可觀察性

F3 顯示居民的 State、Action、Goal、Location、Target、四項 Needs、Mood、最高 Utility Scores、重要記憶數與路徑節點。每次決策也寫入 Event Log。
