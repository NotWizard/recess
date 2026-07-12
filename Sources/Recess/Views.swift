import SwiftUI
import RecessCore

/// 菜单栏下拉内容：状态、居中圆形主按钮(带进度环)、今日番茄，设置/退出同行平铺。
struct MenuContentView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var engine: RecessEngine

    init(controller: AppController) {
        self.controller = controller
        self.engine = controller.engine
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

    private func perform(_ action: MenuUI.PrimaryAction) {
        switch action {
        case .startWork:  controller.startWork()
        case .endWork:    controller.endWork()
        case .startBreak: controller.presentRestWindow()
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
                .animation(.easeInOut(duration: 0.25), value: progress)
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
            Text(subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("开始休息") { controller.startBreak() }
                    .keyboardShortcut(.defaultAction)
                Button("跳过") { controller.skipBreak() }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// 设置页：四个时长配置项。
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
        Form {
            Stepper("工作时长：\(work) 分钟", value: $work, in: 1...180)
            Stepper("短休时长：\(short) 分钟", value: $short, in: 1...120)
            Stepper("长休时长：\(long) 分钟", value: $long, in: 1...120)
            Stepper("每几个工作段后长休：\(every)", value: $every, in: 1...12)
            HStack {
                Spacer()
                Button("保存") {
                    controller.engine.updateConfig(
                        RecessConfig(workMinutes: work, shortBreakMinutes: short,
                                     longBreakMinutes: long, longBreakEvery: every)
                    )
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}

func timeString(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
