import SwiftUI
import AppKit
import RecessCore

@main
enum Entry {
    static func main() {
        if CommandLine.arguments.contains("--selftest") {
            SelfTest.run()   // 无界面驱动真实控制器/浮窗做断言，跑完即退出。
        } else {
            RecessApp.main()
        }
    }
}

struct RecessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(controller: controller)
        } label: {
            MenuBarLabel(engine: controller.engine)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 菜单栏标签：状态图标 + 循环进度(如 3/4) + 今日数。
struct MenuBarLabel: View {
    @ObservedObject var engine: RecessEngine

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: MenuBarLabel.symbol(phase: engine.phase, pendingRest: engine.pendingRest))
            Text(MenuBarLabel.text(completed: engine.completedWorkSegments,
                                   every: engine.config.longBreakEvery,
                                   today: engine.todayCount))
        }
    }

    /// 纯逻辑（供视图与自检共用，单一真相）：菜单栏状态图标。
    static func symbol(phase: Phase, pendingRest: RestKind?) -> String {
        switch phase {
        case .idle: return pendingRest != nil ? "cup.and.saucer" : "timer"
        case .working: return "timer.circle.fill"
        case .shortBreak: return "cup.and.saucer"
        case .longBreak: return "figure.walk"
        }
    }

    /// 纯逻辑：菜单栏文本 "循环进度·今日数"，如 "3/4·5"。
    static func text(completed: Int, every: Int, today: Int) -> String {
        "\(completed)/\(every)·\(today)"
    }
}

/// LSUIElement 已在 Info.plist 设为 true（无 Dock 图标）；此 delegate 仅用于 accessory 策略兜底。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
