# Changelog

本文件记录 Recess 项目的全部变更。

## [Unreleased]

### 新增
- 实现 Recess 完整功能：菜单栏 App（`MenuBarExtra` 显示状态+循环进度+今日数）、四态计时引擎（空闲/工作中/短休中/长休中，无暂停）、居中置顶不抢焦点休息浮窗（`NSPanel`，开始休息/跳过，可关闭并再激活）、结束音效（`NSSound`）、系统通知（`UserNotifications`）、四项时长设置页。
- 新增 `RecessCore` 纯逻辑库与 39 项引擎断言测试（`swift run RecessTests` 全过）；新增 GUI 层无界面自检 `Recess --selftest`（24 项，断言休息浮窗居中/置顶/不抢焦点、结束音效 `play()` 实际启动、工作完成→弹窗事件接线、菜单栏标签逐态图标与文本、各事件通知文案）。两套测试均为 `build_app.sh` 打包门禁。
- 新增打包脚本 `scripts/build_app.sh`（装配 `Recess.app` + `LSUIElement` + ad-hoc 签名）与 `scripts/build_dmg.sh`（`hdiutil` 生成含 `/Applications` 软链的 DMG），产出 `Recess-0.1.0.dmg`。
- 新增 `.gitignore`（忽略 `.build/`、`build/`）。
- `AGENTS.md` 增加 PROJECT.md guidelines 段落：约束任何产品功能或技术框架改动都必须同步更新 `PROJECT.md`。
- 新增 App 图标：`Resources/AppIcon.icns`（含 16–1024 全尺寸）与自包含矢量源 `Resources/AppIcon.svg`。设计为「静憩」主题——青绿→靛蓝渐变方角图 + 居中留白成环的抽象伸展人形，呼应"到点起身、护腰放松"的定位。`build_app.sh` 已自动装配该图标并写入 `CFBundleIconFile`。
- 新增本 `CHANGELOG.md`，作为全部代码变更的唯一记录入口。

### 变更
- 重做设置页交互（`SettingsContentView`）：由清一色 `Stepper` 改为分组表单（`Form` + `.formStyle(.grouped)`），分「番茄时长 / 长休节奏」两组；每项时长改为可直接键入的输入框 + 单位后缀 + 右侧微调步进器；保存时回读引擎钳制后的值，令输入框与实际生效值一致。四项配置与保存语义不变。
- `PROJECT.md` 记录构建工程实况：采用 Swift Package Manager（非 Xcode 工程），因目标机仅装 Command Line Tools；测试改用无框架断言（XCTest 未随 CLT 分发）；DMG 改用 `hdiutil`（不依赖 `create-dmg`）。实测常驻 `phys_footprint` ≈ 15MB（低于 ~30MB 目标）。
