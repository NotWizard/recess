import SwiftUI
import RecessCore

/// 菜单栏下拉内容：状态、今日数、循环进度，以及工作/休息控制入口。
struct MenuContentView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var engine: RecessEngine

    init(controller: AppController) {
        self.controller = controller
        self.engine = controller.engine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(statusLine).font(.headline)
            Text("今日番茄：\(engine.todayCount)")
            Text("本轮进度：\(engine.completedWorkSegments)/\(engine.config.longBreakEvery)")

            Divider()

            switch engine.phase {
            case .idle:
                if engine.pendingRest != nil {
                    Button("开始休息") { controller.presentRestWindow() }
                    Button("跳过休息") { controller.skipBreak() }
                } else {
                    Button("开始工作") { controller.startWork() }
                }
            case .working:
                Text("剩余 \(timeString(engine.remainingSeconds))")
                Button("结束") { controller.endWork() }
            case .shortBreak, .longBreak:
                Text("休息中 \(timeString(engine.remainingSeconds))")
                Button("回到休息浮窗") { controller.presentRestWindow() }
            }

            Divider()
            Button("设置…") { controller.openSettings() }
            Button("退出 Recess") { controller.quit() }
        }
        .padding(10)
        .frame(width: 220)
    }

    private var statusLine: String {
        switch engine.phase {
        case .idle: return engine.pendingRest != nil ? "待休息" : "空闲"
        case .working: return "工作中"
        case .shortBreak: return "短休中"
        case .longBreak: return "长休中"
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
