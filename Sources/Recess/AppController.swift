import AppKit
import SwiftUI
import UserNotifications
import RecessCore

/// 应用控制器：桥接纯引擎与 AppKit/SwiftUI。持有计时器、结束音效、通知、居中休息浮窗与设置窗。
/// 计时器仅在非空闲阶段运行——空闲即停，减少无谓唤醒以压低占用。
final class AppController: ObservableObject {
    let engine: RecessEngine
    private var timer: Timer?
    private var restWC: RestWindowController?
    private var settingsWindow: NSWindow?
    private let endSound = NSSound(named: NSSound.Name("Glass"))

    /// 无界面自检用：暴露真实休息浮窗控制器与结束音效实例，便于断言其属性。
    var restWindowControllerForTesting: RestWindowController {
        if restWC == nil { restWC = RestWindowController(controller: self) }
        return restWC!
    }
    var endSoundForTesting: NSSound? { endSound }

    /// 由 StatusItemController 注入：请求收起菜单栏 popover（打开设置窗前调用）。
    var dismissPopover: (() -> Void)?

    init(engine: RecessEngine = RecessEngine()) {
        self.engine = engine
        engine.onEvent = { [weak self] event in self?.handle(event) }
        requestNotificationAuthorization()
    }

    // MARK: 工作控制（菜单栏下拉）

    func startWork() {
        engine.startWork()
        syncTimer()
    }

    func endWork() {
        engine.endCurrentWork()
        syncTimer()
    }

    // MARK: 休息控制（休息浮窗 / 下拉入口）

    /// 展示居中休息浮窗（首次由工作完成事件触发；关闭后可经下拉入口再次调用）。
    func presentRestWindow() {
        if restWC == nil {
            restWC = RestWindowController(controller: self)
        }
        restWC?.show()
    }

    func startBreak() {
        engine.startPendingBreak()
        syncTimer()
    }

    func skipBreak() {
        engine.skipPendingBreak()
        syncTimer()
        restWC?.close()
    }

    // MARK: 设置

    func openSettings() {
        dismissPopover?()
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsContentView(controller: self))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Recess 设置"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func quit() {
        NSApp.terminate(nil)
    }

    // MARK: 计时器

    private func syncTimer() {
        let active = engine.phase != .idle
        if active && timer == nil {
            let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.onTick()
            }
            // .common 模式：菜单交互/窗口拖动时计时不暂停。
            RunLoop.main.add(t, forMode: .common)
            timer = t
        } else if !active {
            timer?.invalidate()
            timer = nil
        }
    }

    private func onTick() {
        engine.tick()
        syncTimer() // 阶段自然结束后回到空闲会在此停表。
    }

    // MARK: 事件

    private func handle(_ event: RecessEvent) {
        let n = AppController.notificationContent(for: event)
        switch event {
        case .workCompleted:
            playEndSound()
            notify(title: n.title, body: n.body)
            presentRestWindow()
        case .breakCompleted:
            playEndSound()
            notify(title: n.title, body: n.body)
            restWC?.close()
        }
    }

    /// 纯逻辑（供事件处理与自检共用，单一真相）：各事件对应的通知文案。
    static func notificationContent(for event: RecessEvent) -> (title: String, body: String) {
        switch event {
        case .workCompleted(let kind):
            return ("工作段完成",
                    kind == .long ? "该长休息了，起来走走、放松腰部。" : "该短休息了，起身活动一下。")
        case .breakCompleted:
            return ("休息结束", "回来继续吧。")
        }
    }

    private func playEndSound() {
        endSound?.stop()
        endSound?.play()
    }

    /// 无界面自检用：实际触发一次结束音效播放，返回是否成功启动（NSSound.play() 的返回值）。
    @discardableResult
    func playEndSoundForTesting() -> Bool {
        endSound?.stop()
        return endSound?.play() ?? false
    }

    // MARK: 通知

    private func requestNotificationAuthorization() {
        guard Bundle.main.bundleIdentifier != nil else { return } // 未打包运行时跳过。
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
