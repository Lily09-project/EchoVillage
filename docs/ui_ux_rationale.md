# Echo Village UI／UX 設計取向

本專案參考成熟遊戲的互動原則，而不複製任何角色、美術資產或具體介面配置。

## 採用原則

- **讓世界狀態可一眼讀懂**：以繪本地圖、角色職業道具、行動標籤與中央事件環，將 NPC 模擬從數值轉成可被玩家掃讀的畫面。這呼應 [Spiritfarer 官方素材頁](https://thunderlotusgames.com/press-kits/spiritfarer-press-kit/) 所呈現的手繪角色與場景敘事方向，但所有 Echo Village 視覺皆為原創程式繪製。
- **可辨識的互動與資訊層級**：常駐操作列只在選取居民後啟用，並保留 G／X／T／Q 快捷鍵；每次行動以短暫卡片回饋結果。這採納 [Hades 官方更新紀錄](https://www.supergiantgames.com/blog/hades-updates/) 關於文字可讀性、控制器／鍵盤導覽與互動點明確視覺提示的方向。
- **每個面板都有退出方式**：背包與編年都有可見「關閉」按鈕，並統一由 Esc 的取消行為處理。這回應 [Cozy Grove 1.8 官方更新](https://support.spryfox.com/hc/en-us/articles/1500012236261-Cozy-Grove-Version-1-8-0) 對可見關閉按鈕與 Esc 關閉行為的改善。
- **溫和、可關閉的動態**：面板僅使用 180ms 透明度／縮放進場；使用者可在暫停選單關閉環境動態。此做法也符合 [Web Interface Guidelines](https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md) 對可見焦點、清楚控制與尊重減少動態偏好的要求。
- **把分支選擇放在後果之前**：Living Stories 面板先呈現故事摘要與目前階段，再以兩個以上的 44px 選擇按鈕提供清楚的 label／description；選擇完成後保留回饋文字與 completed 狀態，避免玩家不知道按鈕是否成功。琥珀色選擇按鈕明確代表「需要思考的決策」，並強制使用深色字體覆寫 Godot 預設淺色字，確保對比度。
- **資訊密度與模態優先級**：故事線是低頻但高影響的操作，因此使用 `O` 開啟獨立模態面板，不把長文塞入 HUD。開啟後暫停時間，且與交易、任務、地圖、背包互斥；`Esc` 與可見關閉按鈕都能離開，維持鍵盤與滑鼠兩種路徑一致。

## 可驗證落點

`tests/test_runner.gd` 會驗證 `ActionDock`、`InteractionPrompt`、`ImpactFeedback` 與 `cancel` 輸入映射皆存在；真實 Godot 視覺 QA 的危險情境會保留一張顯示結果回饋的截圖。

故事線則額外驗證 active／completed／locked 文案、非法或重複 choice 的失敗回饋、模態暫停與關閉路徑；`tests/visual_qa/story_arc_active.png` 提供 1280×720 實機證據，檢查面板層級、文字截斷與按鈕對比。
