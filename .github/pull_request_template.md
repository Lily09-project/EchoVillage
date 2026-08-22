## 變更目的

請用一到三句話說明這個 Pull Request 解決的使用者問題，以及為什麼採用目前的實作方式。

## 變更範圍

- [ ] Gameplay／NPC simulation
- [ ] Data contract／content
- [ ] UI／UX
- [ ] Save／migration／persistence
- [ ] Tests／CI／security
- [ ] Documentation

## 驗證證據

- [ ] `powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate_project.ps1`
- [ ] `run_echo_village.bat --test`
- [ ] Visual QA（若有 UI 變更）
- [ ] Portable smoke test（若有 release／runtime 變更）
- [ ] Security audit 無 findings

測試結果：`passed=___ failed=___`，security findings：`___`

## 產品與風險檢查

- [ ] 所有主要按鈕都有實際行為與成功／失敗 feedback。
- [ ] 正常、空資料、非法輸入與失敗狀態都有處理。
- [ ] 沒有將秘密、真實存檔、`.godot` cache 或 release artifacts 加入版本控制。
- [ ] 沒有破壞既有 save envelope、資料 ID 或公共 API。
- [ ] 若增加測試數量，已同步更新 CI 的 release contract、README 與測試文件。

## 截圖／補充

若有 UI 或視覺變更，請附上實際遊戲畫面與說明檢查的 viewport 尺寸。
