## 1. 更新检测策略：检测 + 下载 DMG，不做 in-place 替换

- 状态：已接受
- 日期：2026-07-15

### 上下文

Recess 是 ad-hoc 签名、不公证、纯 SwiftPM 工程的 macOS 菜单栏 App，分发改 GitHub Releases（DMG）。需要"检测更新"能力，让用户感知新版并完成升级。

候选方案：
1. Sparkle 自动更新：EdDSA 签名验证 + in-place 替换 + 重启，成熟。但要管 EdDSA 密钥对、分发侧从纯 DMG 变 DMG+zip、Sparkle.xcframework 与"纯 SwiftPM 非 Xcode"工程形态可能有集成成本。
2. 自研 in-place 替换：自己写下载→去 quarantine→helper 替换 bundle→重启状态机 + 完整性验证。工程量大、安全风险高（完整性验证做不好即 RCE）。
3. 检测 + 下载 DMG + open：App 只检测版本、下载 DMG、挂载弹出 Finder 拖拽窗口，安装动作留给用户手动。不碰 bundle/quarantine/重启。

### 决策

采用方案 3（检测 + 下载 DMG + open），不做 in-place 替换。

- 数据源：GitHub Releases API（`releases/latest`），取 `tag_name` 与 `assets[].browser_download_url`。
- 检查时机：启动时静默检查一次 + 设置面板"检查更新"按钮手动兜底。
- 版本比较：`tag_name` 去 v 前缀后与 `CFBundleShortVersionString` 语义比较（当前版本号均为 `0.x.y` 简单形式）。
- 下载：`URLSession` 下载 DMG 至临时目录，完成后 `open` 触发挂载 + Finder 并排拖拽窗口。
- UI：下拉面板"设置/退出"行加"检查更新"按钮，检测到新版时按钮文案变"立即更新"；三按钮水平平铺，顺序 检查更新 → 设置 → 退出。
- 失败：启动检查失败/无网络静默忽略，不打扰。

### 后果

+ 正面：避开 Sparkle 全套复杂度（EdDSA 密钥、签名验证、helper 替换状态机、quarantine 处理）；不引入二进制依赖；分发格式不变（仍纯 DMG）；符合项目极简调性。
- 负面：安装仍全手动——用户需自己拖拽 .app 到 /Applications、退出旧版、启动新版。自动化程度有限（仅省"找下载链接"一步）。
- 后续：若用户反馈手动安装繁琐，可再评估引入 Sparkle（届时需解决纯 SwiftPM 集成路径）。

### 与既有锁定关系

本决策与 PROJECT.md 第二节"不公证、¥0"及"纯 SwiftPM 非 Xcode"锁定一致——方案 3 不要求公证、不引入需 Xcode 集成的依赖。
