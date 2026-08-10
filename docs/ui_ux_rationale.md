# Echo Village UI／UX 設計取向

本專案參考成熟遊戲的互動原則，而不複製任何角色、美術資產或具體介面配置。

## 採用原則

- **讓世界狀態可一眼讀懂**：以繪本地圖、角色職業道具、行動標籤與中央事件環，將 NPC 模擬從數值轉成可被玩家掃讀的畫面。這呼應 [Spiritfarer 官方素材頁](https://thunderlotusgames.com/press-kits/spiritfarer-press-kit/) 所呈現的手繪角色與場景敘事方向，但所有 Echo Village 視覺皆為原創程式繪製。
- **可辨識的互動與資訊層級**：常駐操作列只在選取居民後啟用，並保留 G／X／T／Q 快捷鍵；每次行動以短暫卡片回饋結果。這採納 [Hades 官方更新紀錄](https://www.supergiantgames.com/blog/hades-updates/) 關於文字可讀性、控制器／鍵盤導覽與互動點明確視覺提示的方向。
- **每個面板都有退出方式**：背包與編年都有可見「關閉」按鈕，並統一由 Esc 的取消行為處理。這回應 [Cozy Grove 1.8 官方更新](https://support.spryfox.com/hc/en-us/articles/1500012236261-Cozy-Grove-Version-1-8-0) 對可見關閉按鈕與 Esc 關閉行為的改善。
- **溫和、可關閉的動態**：面板僅使用 180ms 透明度／縮放進場；使用者可在暫停選單關閉環境動態。此做法也符合 [Web Interface Guidelines](https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md) 對可見焦點、清楚控制與尊重減少動態偏好的要求。

## 可驗證落點

`tests/test_runner.gd` 會驗證 `ActionDock`、`InteractionPrompt`、`ImpactFeedback` 與 `cancel` 輸入映射皆存在；真實 Godot 視覺 QA 的危險情境會保留一張顯示結果回饋的截圖。
