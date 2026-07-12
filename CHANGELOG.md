# Changelog

本文件记录 Recess 项目的全部变更。

## [Unreleased]

### 新增
- 实现 Recess 完整功能：菜单栏 App（`MenuBarExtra` 显示状态+循环进度+今日数）、四态计时引擎（空闲/工作中/短休中/长休中，无暂停）、居中置顶不抢焦点休息浮窗（`NSPanel`，开始休息/跳过，可关闭并再激活）、结束音效（`NSSound`）、系统通知（`UserNotifications`）、四项时长设置页。
- 新增 `RecessCore` 纯逻辑库与 39 项引擎断言测试（`swift run RecessTests` 全过）；新增 GUI 层无界面自检 `Recess --selftest`（24 项，断言休息浮窗居中/置顶/不抢焦点、结束音效 `play()` 实际启动、工作完成→弹窗事件接线、菜单栏标签逐态图标与文本、各事件通知文案）。两套测试均为 `build_app.sh` 打包门禁。
- 新增打包脚本 `scripts/build_app.sh`（装配 `Recess.app` + `LSUIElement` + ad-hoc 签名）与 `scripts/build_dmg.sh`（`hdiutil` 生成含 `/Applications` 软链的 DMG），产出 `Recess-0.1.0.dmg`。
- 新增 `.gitignore`（忽略 `.build/`、`build/`）。
- `AGENTS.md` 增加 PROJECT.md guidelines 段落：约束任何产品功能或技术框架改动都必须同步更新 `PROJECT.md`。
- 新增本 `CHANGELOG.md`，作为全部代码变更的唯一记录入口。

### 变更
- `PROJECT.md` 记录构建工程实况：采用 Swift Package Manager（非 Xcode 工程），因目标机仅装 Command Line Tools；测试改用无框架断言（XCTest 未随 CLT 分发）；DMG 改用 `hdiutil`（不依赖 `create-dmg`）。实测常驻 `phys_footprint` ≈ 15MB（低于 ~30MB 目标）。
