# Recess 领域文档

## 词汇表

- **番茄段（Pomodoro Segment）**：一个工作计时单元，默认 25 分钟。自然完成后 `今日番茄数` +1。
- **今日番茄数（Today's Count）**：当天自然完成的工作段数，跨天自动归零，不持久化进行中计时。
- **休息浮窗（Rest Popup）**：工作段自然完成时弹出的居中、置顶、不抢焦点的 `NSPanel`，含"开始休息 / 跳过"。
- **检查更新（Check for Updates）**：下拉面板中的一个按钮。无新版时点击触发一次手动版本检查；有新版时按钮文案变为"立即更新"，点击触发下载 DMG。
- **立即更新（Update Now）**："检查更新"按钮在有新版时的文案态，点击后下载最新 Release 的 DMG 并 `open` 挂载，弹出 Finder 并排拖拽窗口，安装动作仍由用户手动完成。
- **启动检查（Startup Check）**：App 启动时静默向 GitHub Releases API 查询最新版本，失败/无网络时静默忽略。

## 架构边界

更新检测不触碰应用自身的 bundle 替换、quarantine 或重启逻辑（见 [ADR-0001](docs/adr/0001-update-detection-strategy.md)）。App 仅负责"检测版本 + 下载 DMG + 挂载"，安装由用户手动拖拽完成。
