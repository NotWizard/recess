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

    var body: some Scene {
        // 菜单栏改用 NSStatusItem（在 AppDelegate 创建），此处无需可见窗口。
        Settings { EmptyView() }
    }
}

/// LSUIElement 已在 Info.plist 设为 true（无 Dock 图标）。持有 AppController 与状态栏项。
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = AppController()
        self.controller = controller
        self.statusItem = StatusItemController(controller: controller)
    }
}
