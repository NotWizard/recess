# Changelog

本文件记录 Recess 项目的全部变更。

## [Unreleased]

## [0.1.4] - 2026-07-15

### 新增
- 更新检测：App 启动时静默查询 GitHub Releases API 比较版本；下拉面板「设置/退出」行新增「检查更新」按钮，检测到新版后按钮文案变为「立即更新 vX.X.X」，点击下载最新 Release 的 DMG 并挂载，弹出 Finder 并排拖拽窗口，安装仍由用户手动完成。不做 in-place 替换，不引入 Sparkle，不触碰 bundle/quarantine/重启。详见 ADR-0001。
- 领域文档：新增 `CONTEXT.md` 词汇表与 `docs/adr/0001-update-detection-strategy.md` 决策记录。
- GUI 自检新增版本比较断言 6 项（53 项全过）。

## [0.1.3] - 2026-07-14

### 修复
- App 常驻运行跨天后今日番茄数未归零：根因是 `rolloverIfNeeded()` 仅在 init/startWork/completeWork 调用，空闲跨天无触发路径；`tick()` 在空闲时直接返回、AppController 空闲时停表。现 `tick()` 开头先做 `rolloverIfNeeded()`，AppController 空闲时改为 60 秒低频心跳驱动跨天检查，init 启动即建 timer。新增常驻引擎跨天归零回归用例。
- 空闲态 CPU 持续 4-10%：根因是 `ProgressRing` 的隐式 `.animation(.easeInOut(duration:), value: progress)` 让 SwiftUI 在 popover 关闭、进度环不可见时仍按 60fps 空转渲染循环。去掉该隐式动画修饰符，空闲态 CPU 降至接近 0；进度环每秒跳变而非平滑过渡，但仅在 popover 打开时可见且为细描边，肉眼无感。

### 改进
- DMG 打开后无「左 App 右 Applications 并排引导拖拽」布局：`build_dmg.sh` 改用「可读写 DMG → 挂载后 AppleScript 设图标视图/窗口大小/并排图标位置 → 转只读压缩 DMG」三步流程，打开即为传统引导式安装界面。

## [0.1.2] - 2026-07-13

### 变更
- 关闭休息浮窗后从下拉面板点「开始休息」不再重新弹出浮窗：`MenuContentView.perform(.startBreak)` 由 `presentRestWindow()` 改为 `startBreak()`，直接进入休息计时。工作段自然完成时自动弹浮窗的行为不变。

## [0.1.1] - 2026-07-12

### 修复
- 点「开始休息」后休息浮窗未自动关闭：`AppController.startBreak()` 补 `restWC?.close()`，使开始休息与跳过一致地关窗；GUI 自检增补对应断言。

## [0.1.0] - 2026-07-12

### 新增
- 新增面向用户的 `README.md`：项目定位、安装方式（DMG / Homebrew / 源码构建）、使用指南、设计取舍与「明确不做」清单、开发说明，配套 App 图标。
- 实现 Recess 完整功能：菜单栏 App（`NSStatusItem` 自绘：空闲显图标、进行中显倒计时并按工作/休息上橙/绿胶囊底色；`NSPopover` 承载下拉面板）、四态计时引擎（空闲/工作中/短休中/长休中，无暂停）、居中置顶不抢焦点休息浮窗（`NSPanel`，开始休息/跳过，可关闭并再激活）、结束音效（`NSSound`）、系统通知（`UserNotifications`）、四项时长设置页。
- 下拉面板：顶部状态 → 居中进度环（纯展示，工作橙/休息绿）→ 主按钮（开始类蓝底白字、结束/跳过类白底蓝字蓝边框，正反呼应）→ 今日番茄数 → 「设置/退出」同行平铺；点主按钮后面板即收起。
- 新增 `RecessCore` 纯逻辑库与 39 项引擎断言测试（`swift run RecessTests` 全过）；新增 GUI 层无界面自检 `Recess --selftest`（42 项，断言休息浮窗居中/置顶/不抢焦点、结束音效 `play()` 实际启动、工作完成→弹窗事件接线、菜单栏图标/倒计时逻辑、主按钮动作与视觉类型、阶段配色、进度环、各事件通知文案）。两套测试均为 `build_app.sh` 打包门禁。
- 新增打包脚本 `scripts/build_app.sh`（装配 `Recess.app` + `LSUIElement` + ad-hoc 签名）与 `scripts/build_dmg.sh`（`hdiutil` 生成含 `/Applications` 软链的 DMG），产出 `Recess-0.1.0.dmg`。
- 新增 `.gitignore`（忽略 `.build/`、`build/`）。
- `AGENTS.md` 增加 PROJECT.md guidelines 段落：约束任何产品功能或技术框架改动都必须同步更新 `PROJECT.md`。
- 新增 App 图标：`Resources/AppIcon.icns`（含 16–1024 全尺寸）与自包含矢量源 `Resources/AppIcon.svg`。设计为「静憩」主题——青绿→靛蓝渐变方角图 + 居中留白成环的抽象伸展人形，呼应"到点起身、护腰放松"的定位。`build_app.sh` 已自动装配该图标并写入 `CFBundleIconFile`。
- 新增本 `CHANGELOG.md`，作为全部代码变更的唯一记录入口。

### 变更
- 重做设置页交互（`SettingsContentView`）：由清一色 `Stepper` 改为分组表单（`Form` + `.formStyle(.grouped)`），分「番茄时长 / 长休节奏」两组；每项时长改为可直接键入的输入框 + 单位后缀 + 右侧微调步进器；保存时回读引擎钳制后的值，令输入框与实际生效值一致。四项配置与保存语义不变。
- `PROJECT.md` 记录构建工程实况：采用 Swift Package Manager（非 Xcode 工程），因目标机仅装 Command Line Tools；测试改用无框架断言（XCTest 未随 CLT 分发）；DMG 改用 `hdiutil`（不依赖 `create-dmg`）。实测常驻 `phys_footprint` ≈ 15MB（低于 ~30MB 目标）。
- 菜单栏由 `MenuBarExtra` 改为 `NSStatusItem` + `NSPopover`：因 `MenuBarExtra` 的 label 背景被系统忽略，无法给进行中的倒计时上橙/绿底色；改自绘 `NSImage` 后可正确渲染底色，一眼区分工作/休息。同步更新 `PROJECT.md` 第二节技术方案与第五节交互。

### 修复
- 休息浮窗尺寸被压成竖条、文字截断：为内容设固定 360×200 尺寸并 `setContentSize`，避免 `NSHostingController` 按 fitting size 反向压缩窗口。
- 休息浮窗按钮主次不分、`开始休息` 在非活动窗口下被渲染成灰色：改用显式填充的自定义按钮样式（主=蓝底白字、次=浅灰），不再依赖系统 `borderedProminent` 的活动态；窗口标题改为 `Recess`、正文大标题保留 `该休息了`。同步更新 `PROJECT.md` 第五节。
- `Info.plist` 补充 `NSUserNotificationsUsageDescription`（通知用途说明），使打包后首次请求通知权限时展示清晰用途文案，更规范。
- 点「开始休息」后休息浮窗未自动关闭：`AppController.startBreak()` 补 `restWC?.close()`，使开始休息与跳过一致地关窗；GUI 自检增补对应断言。
