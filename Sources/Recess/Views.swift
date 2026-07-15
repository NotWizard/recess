import SwiftUI
import RecessCore

/// 菜单栏下拉内容：状态、居中圆形主按钮(带进度环)、今日番茄，设置/退出同行平铺。
struct MenuContentView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var engine: RecessEngine
    @ObservedObject var updateChecker: UpdateChecker

    init(controller: AppController) {
        self.controller = controller
        self.engine = controller.engine
        self._updateChecker = ObservedObject(wrappedValue: controller.updateChecker)
    }

    private var action: MenuUI.PrimaryAction {
        MenuUI.primaryAction(phase: engine.phase, pendingRest: engine.pendingRest)
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(MenuUI.statusText(phase: engine.phase, pendingRest: engine.pendingRest))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ProgressRing(
                symbol: MenuUI.primarySymbol(action),
                progress: MenuUI.ringProgress(phase: engine.phase,
                                              remaining: engine.remainingSeconds,
                                              total: engine.currentTotalSeconds),
                countdown: MenuUI.showsCountdown(phase: engine.phase)
                    ? MenuUI.barCountdown(engine.remainingSeconds) : nil,
                tint: ringTint
            )

            PrimaryActionButton(
                title: MenuUI.primaryTitle(action),
                kind: MenuUI.buttonKind(action)
            ) {
                perform(action)
            }

            Text("今日番茄 · \(engine.todayCount)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(updateButtonTitle) {
                    if updateChecker.latestVersion != nil {
                        controller.downloadUpdate()
                    } else {
                        controller.checkForUpdates()
                    }
                }
                .disabled(updateChecker.isDownloading)
                .frame(maxWidth: .infinity)
                Button("设置") { controller.openSettings() }
                    .frame(maxWidth: .infinity)
                Button("退出") { controller.quit() }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 240)
    }

    private var ringTint: Color {
        switch MenuUI.phaseTint(phase: engine.phase) {
        case .none: return .secondary
        case .work: return .orange
        case .rest: return .green
        }
    }

    /// 更新按钮文案：有新版→"立即更新 vX.X.X"，下载中→"下载中…"，否则→"检查更新"。
    private var updateButtonTitle: String {
        if updateChecker.isDownloading { return "下载中…" }
        if let v = updateChecker.latestVersion { return "立即更新 v\(v)" }
        return "检查更新"
    }

    private func perform(_ action: MenuUI.PrimaryAction) {
        switch action {
        case .startWork:  controller.startWork()
        case .endWork:    controller.endWork()
        case .startBreak: controller.startBreak()
        case .skipBreak:  controller.skipBreak()
        }
        // 收起面板：图标宽度随状态变化会导致 popover 箭头错位，点完即关最稳且交互自然。
        controller.dismissPopover?()
    }
}

/// 纯展示进度环：外圈进度 + 中心倒计时/图标。不可点，仅显示。
struct ProgressRing: View {
    let symbol: String
    let progress: Double
    let countdown: String?
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let countdown {
                Text(countdown).font(.system(size: 28, weight: .bold)).monospacedDigit()
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 120, height: 120)
    }
}

/// 主按钮：go=开始类(蓝底白字)，stop=结束/跳过类(蓝字白底蓝边框)，二者正反呼应。
struct PrimaryActionButton: View {
    let title: String
    let kind: MenuUI.ButtonKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3).bold()
                .foregroundStyle(kind == .go ? Color.white : Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(fillShape)
                .overlay(borderShape)
        }
        .buttonStyle(.plain)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 12, style: .continuous) }

    @ViewBuilder private var fillShape: some View {
        if kind == .go {
            shape.fill(Color.accentColor)
        } else {
            shape.fill(Color(nsColor: .controlBackgroundColor))
        }
    }

    @ViewBuilder private var borderShape: some View {
        if kind == .stop {
            // strokeBorder 向内描边，四边都完整落在视图内，避免底边被裁细。
            shape.strokeBorder(Color.accentColor, lineWidth: 1.5)
        }
    }
}

/// 休息浮窗内容：按钮"开始休息 / 跳过"。
struct RestContentView: View {
    @ObservedObject var engine: RecessEngine
    let controller: AppController

    init(controller: AppController) {
        self.controller = controller
        self.engine = controller.engine
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title).font(.title2).bold()
            Text(subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("跳过") { controller.skipBreak() }
                    .buttonStyle(RestButtonStyle(prominent: false))
                Button("开始休息") { controller.startBreak() }
                    .buttonStyle(RestButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 360, height: 200)
    }

    private var isLong: Bool {
        engine.pendingRest == .long || engine.phase == .longBreak
    }
    private var title: String {
        engine.phase == .idle ? "该休息了" : (isLong ? "长休息中" : "短休息中")
    }
    private var subtitle: String {
        if engine.phase == .shortBreak || engine.phase == .longBreak {
            return "剩余 \(timeString(engine.remainingSeconds))，起来走走、放松腰部。"
        }
        return isLong ? "完成一轮，来个长休息，离开座位活动一下。" : "起身活动一下，放松腰部。"
    }
}

/// 休息浮窗按钮样式：主=蓝底白字(显式填充，不受非活动窗口影响)，次=低调描边。按下轻微变暗。
struct RestButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return configuration.label
            .font(.body).bold()
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .background {
                if prominent {
                    shape.fill(Color.accentColor)
                } else {
                    shape.fill(Color.secondary.opacity(0.18))
                }
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// 设置页：四项时长配置。分组表单 + 可键入输入框（右侧保留微调步进器）。
struct SettingsContentView: View {
    @ObservedObject var engine: RecessEngine
    let controller: AppController

    @State private var work: Int
    @State private var short: Int
    @State private var long: Int
    @State private var every: Int

    init(controller: AppController) {
        self.controller = controller
        self.engine = controller.engine
        let c = controller.engine.config
        _work = State(initialValue: c.workMinutes)
        _short = State(initialValue: c.shortBreakMinutes)
        _long = State(initialValue: c.longBreakMinutes)
        _every = State(initialValue: c.longBreakEvery)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("番茄时长") {
                    field("工作时长", value: $work, range: 1...180, unit: "分钟")
                    field("短休时长", value: $short, range: 1...120, unit: "分钟")
                    field("长休时长", value: $long, range: 1...120, unit: "分钟")
                }
                Section("长休节奏") {
                    field("每几个工作段后长休", value: $every, range: 1...12, unit: "个")
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 360, height: 400)
    }

    /// 一行：左标签 + 右对齐可键入输入框 + 单位 + 微调步进器。
    private func field(_ label: String, value: Binding<Int>,
                       range: ClosedRange<Int>, unit: String) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                TextField("", value: value, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 52)
                    .textFieldStyle(.roundedBorder)
                Text(unit).foregroundStyle(.secondary)
                Stepper("", value: value, in: range).labelsHidden()
            }
        }
    }

    private func save() {
        controller.engine.updateConfig(
            RecessConfig(workMinutes: work, shortBreakMinutes: short,
                         longBreakMinutes: long, longBreakEvery: every)
        )
        // 键入值可能越界；引擎已钳制，回读令输入框与实际生效值一致。
        let c = engine.config
        work = c.workMinutes; short = c.shortBreakMinutes
        long = c.longBreakMinutes; every = c.longBreakEvery
    }
}

func timeString(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
