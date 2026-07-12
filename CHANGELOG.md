# Changelog

本文件记录 Recess 项目的全部变更。

## [Unreleased]

### 新增
- 实现 Recess 完整功能：菜单栏 App（`NSStatusItem` 自绘：空闲显图标、进行中显倒计时并按工作/休息上橙/绿胶囊底色；`NSPopover` 承载下拉面板）、四态计时引擎（空闲/工作中/短休中/长休中，无暂停）、居中置顶不抢焦点休息浮窗（`NSPanel`，开始休息/跳过，可关闭并再激活）、结束音效（`NSSound`）、系统通知（`UserNotifications`）、四项时长设置页。
- 下拉面板：顶部状态 → 居中进度环（纯展示，工作橙/休息绿）→ 主按钮（开始类蓝底白字、结束/跳过类白底蓝字蓝边框，正反呼应）→ 今日番茄数 → 「设置/退出」同行平铺；点主按钮后面板即收起。
- 新增 `RecessCore` 纯逻辑库与 39 项引擎断言测试（`swift run RecessTests` 全过）；新增 GUI 层无界面自检 `Recess --selftest`（42 项，断言休息浮窗居中/置顶/不抢焦点、结束音效 `play()` 实际启动、工作完成→弹窗事件接线、菜单栏图标/倒计时逻辑、主按钮动作与视觉类型、阶段配色、进度环、各事件通知文案）。两套测试均为 `build_app.sh` 打包门禁。
- 新增打包脚本 `scripts/build_app.sh`（装配 `Recess.app` + `LSUIElement` + ad-hoc 签名）与 `scripts/build_dmg.sh`（`hdiutil` 生成含 `/Applications` 软链的 DMG），产出 `Recess-0.1.0.dmg`。
- 新增 `.gitignore`（忽略 `.build/`、`build/`）。
- `AGENTS.md` 增加 PROJECT.md guidelines 段落：约束任何产品功能或技术框架改动都必须同步更新 `PROJECT.md`。
- 新增本 `CHANGELOG.md`，作为全部代码变更的唯一记录入口。

### 变更
- `PROJECT.md` 记录构建工程实况：采用 Swift Package Manager（非 Xcode 工程），因目标机仅装 Command Line Tools；测试改用无框架断言（XCTest 未随 CLT 分发）；DMG 改用 `hdiutil`（不依赖 `create-dmg`）。实测常驻 `phys_footprint` ≈ 15MB（低于 ~30MB 目标）。
- 菜单栏由 `MenuBarExtra` 改为 `NSStatusItem` + `NSPopover`：因 `MenuBarExtra` 的 label 背景被系统忽略，无法给进行中的倒计时上橙/绿底色；改自绘 `NSImage` 后可正确渲染底色，一眼区分工作/休息。同步更新 `PROJECT.md` 第二节技术方案与第五节交互。
