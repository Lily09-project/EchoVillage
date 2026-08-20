# Security Policy

## 支援版本

目前維護版本：`1.4.x`。請使用最新 release 或 `master` 上的 security fixes。

## 回報漏洞

請不要在公開 Issue 貼出 API key、token、真實存檔、個人路徑或可利用漏洞的完整細節。請透過 GitHub repository 的 **Security → Report a vulnerability** 建立 private vulnerability report；若該功能不可用，先建立不含敏感內容的 Issue，要求維護者提供私下聯絡方式。

回報請包含：

- 受影響版本與執行環境。
- 最小可重現步驟或測試案例。
- 預期與實際行為。
- 影響範圍與是否需要本機檔案／網路權限。
- 已移除秘密資料的 log 或截圖。

## 專案安全邊界

- `tools/security_audit.ps1` 會掃描 Git tracked files，拒絕 secrets、private keys、user saves、`.godot` 與 release artifacts。
- SaveManager 對存檔與偏好設定有 byte、型別、集合數量與巢狀深度限制，並以 `.tmp`／`.bak` 保護寫入與復原。
- GameManager deserialize、交易、製作、任務與故事分支都在套用前驗證候選狀態。
- Optional AI provider 不持有權威狀態寫入權限，且使用環境變數設定。

不要把真實使用者資料加入 Issue、PR、測試 fixture 或 repository。
