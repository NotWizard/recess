import AppKit
import RecessCore

/// 无界面 GUI 层自检：驱动真实 AppController + NSPanel，断言此前只能人工验证的属性。
/// 运行：Recess --selftest（退出码非 0 表示失败）。
enum SelfTest {
    final class Clock {
        var current: Date
        init(_ s: Date) { current = s }
        func now() -> Date { current }
        func advance(_ s: TimeInterval) { current = current.addingTimeInterval(s) }
    }

    static func run() {
        NSApplication.shared.setActivationPolicy(.accessory)

        var failures = 0, passed = 0
        func check(_ cond: Bool, _ msg: String) {
            if cond { passed += 1 } else { failures += 1; print("FAIL: \(msg)") }
        }

        let suite = "recess.selftest"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let clock = Clock(Date(timeIntervalSince1970: 1_700_000_000))
        let engine = RecessEngine(defaults: defaults, calendar: .current, now: clock.now)
        engine.updateConfig(RecessConfig(workMinutes: 25, shortBreakMinutes: 5,
                                         longBreakMinutes: 15, longBreakEvery: 4))
        let controller = AppController(engine: engine)

        // 1) 结束音效：不仅资源可解析，还实际触发播放并确认已启动。
        check(controller.endSoundForTesting != nil, "结束音效 NSSound 应可解析")
        let started = controller.playEndSoundForTesting()
        check(started, "结束音效 play() 应成功启动播放")
        controller.endSoundForTesting?.stop()

        // 2) 休息浮窗真实属性：居中 / 置顶 / 不抢焦点。
        let wc = controller.restWindowControllerForTesting
        guard let panel = wc.inspectablePanel else {
            print("FAIL: 无法构建休息浮窗"); print("passed: \(passed), failed: \(failures+1)"); exit(1)
        }
        check(panel.styleMask.contains(.nonactivatingPanel), "浮窗应为 nonactivatingPanel（不抢焦点）")
        check(panel.isFloatingPanel, "浮窗应 isFloatingPanel")
        check(panel.level == .floating, "浮窗层级应为 .floating（置顶）")
        check(panel.becomesKeyOnlyIfNeeded, "浮窗 becomesKeyOnlyIfNeeded 应为真")
        check(!panel.canBecomeMain, "浮窗不应成为 main window")
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            let dx = abs(panel.frame.midX - vf.midX), dy = abs(panel.frame.midY - vf.midY)
            check(dx < 1.0 && dy < 1.0, "浮窗应居中（dx=\(dx), dy=\(dy)）")
        }

        // 3) 事件接线：工作段自然完成 -> +1 且弹出休息浮窗（走真实 onEvent 回调）。
        controller.startWork()
        check(engine.phase == .working, "开始工作后应为工作中")
        clock.advance(Double(engine.currentTotalSeconds) + 1)
        engine.tick()  // 完成 -> onEvent(.workCompleted) -> controller.presentRestWindow()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        check(engine.todayCount == 1, "自然完成后今日数应为 1（实际 \(engine.todayCount)）")
        check(engine.pendingRest == .short, "应待短休")
        check(wc.isVisible, "工作完成后休息浮窗应可见")

        // 4) 开始休息 -> 短休；跳过 -> 浮窗隐藏；可再激活。
        controller.startBreak()
        check(engine.phase == .shortBreak, "开始休息后应为短休中")
        controller.skipBreak()
        check(!wc.isVisible, "跳过后浮窗应隐藏")
        controller.presentRestWindow()
        check(wc.isVisible, "关闭后应能再次激活浮窗")

        // 5) 菜单栏标签内容逻辑（图标 + "进度·今日数"），逐态断言。
        check(MenuBarLabel.symbol(phase: .idle, pendingRest: nil) == "timer", "空闲图标应为 timer")
        check(MenuBarLabel.symbol(phase: .idle, pendingRest: .short) == "cup.and.saucer", "待休息图标应为 cup")
        check(MenuBarLabel.symbol(phase: .working, pendingRest: nil) == "timer.circle.fill", "工作图标")
        check(MenuBarLabel.symbol(phase: .shortBreak, pendingRest: nil) == "cup.and.saucer", "短休图标")
        check(MenuBarLabel.symbol(phase: .longBreak, pendingRest: nil) == "figure.walk", "长休图标")
        check(MenuBarLabel.text(completed: 3, every: 4, today: 5) == "3/4·5", "标签文本应为 3/4·5")

        // 6) 通知文案（各事件），单一真相函数逐项断言。
        let nShort = AppController.notificationContent(for: .workCompleted(.short))
        check(nShort.title == "工作段完成" && nShort.body.contains("短休息"), "短休完成通知文案")
        let nLong = AppController.notificationContent(for: .workCompleted(.long))
        check(nLong.title == "工作段完成" && nLong.body.contains("长休息"), "长休完成通知文案")
        let nBreak = AppController.notificationContent(for: .breakCompleted)
        check(nBreak.title == "休息结束" && !nBreak.body.isEmpty, "休息结束通知文案")

        print("---")
        print("passed: \(passed), failed: \(failures)")
        if failures > 0 { exit(1) }
        print("GUI SELFTEST PASSED")
        exit(0)
    }
}
