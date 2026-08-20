# Echo Village 視覺方向

## 定位

「溫暖手繪繪本 × 可解釋 AI 村落」。視覺不只是裝飾：地圖、角色、事件與 HUD 必須讓觀眾在不開除錯面板時，也能理解村民正在做什麼、世界發生了什麼。

## 視覺系統

- **背景**：天空、雲層、星光、太陽／月亮、草地筆觸、花圃、石路與溪流構成四層景深。
- **森林生態區**：深墨遠景樹冠、蜿蜒土徑、草藥群落與三角帳篷形成第二套場景輪廓；仍沿用暖紙、苔綠與金色焦點，維持品牌一致。
- **地標**：酒館、商店、農場、醫館都有屋頂、窗戶、招牌、門與夜間窗光；中央噴泉是視線錨點。
- **角色**：五位 NPC 使用獨立膚色、髮色、服裝、強調色與職業道具；選取狀態使用金色環，而非只依靠文字。
- **事件**：主 HUD、村落脈動與中央事件環同時回饋狀態；危險時可看見居民不同的行動標籤。
- **HUD**：暖紙表面、深墨描邊、苔綠互動、磚紅警示、金色選取；面板資訊維持中文優先與明確鍵盤提示。
- **情境互動**：未選取時只呈現靠近居民的 `E` 提示；選取後才啟用固定位置的四個操作，並立即顯示短暫結果回饋。這避免把可操作性藏在快捷鍵裡，也不讓按鈕隨場景跳動。

## 動態與無障礙

- 雲、星、草、花、噴泉與 NPC 有低幅度環境動態；僅使用位置與透明度型動畫，不造成介面重排。
- 暫停選單提供「動態效果：開／關」，關閉後保留角色與事件的靜態狀態提示。
- 背包、編年與暫停視窗均有文字化的關閉路徑；`Esc` 使用離散取消動作，而非每幀輪詢，避免誤觸造成畫面閃爍。
- 日夜資料由 `GameTime.visual_profile()` 提供，繪圖由 `VillageArt` 消費，確保視覺不直接改動模擬狀態。

## 視覺 QA

設定 `ECHO_VILLAGE_VISUAL_QA=1` 並以正式 Godot GUI runtime 啟動時，主場景會自動輸出下列 1280×720 圖片至 `tests/visual_qa/`：

- `storybook_intro.png`：開場展示面板
- `storybook_explore_dawn.png`：黎明探索畫面
- `storybook_explore_noon.png`：正午探索畫面
- `storybook_explore_night.png`：夜間探索與窗光
- `storybook_event_danger.png`：危險事件、警示環與 NPC 決策
- `quest_in_progress.png`：林間回音進行中、目前目標與 M／K 操作提示
- `forest_echo_complete.png`：森林邊緣、草藥營地、黛安娜與任務完成回饋
- `consumer_main_menu.png`：消費者主選單與繼續／設定入口
- `consumer_settings.png`：設定、動態、音效與全螢幕控制
- `consumer_trade.png`：交易選品、買入／出售與錯誤回饋
- `village_progression.png`：村落聲望、稱號與成就進度
- `story_arc_active.png`：Living Stories active stage、分支選擇與模態層級
- `consumer_onboarding.png`：首次旅程三步驟導覽、略過與操作提示
