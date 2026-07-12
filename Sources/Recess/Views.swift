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
