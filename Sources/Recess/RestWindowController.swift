import AppKit
import SwiftUI

/// 居中、置顶、不抢焦点的休息浮窗。用 NSPanel + .nonactivatingPanel 实现"浮在最前但不夺走当前应用焦点"。
/// 可直接关闭；关闭后菜单栏仍保留入口，可再次激活。
final class RestWindowController {
    private weak var controller: AppController?
    private var panel: NSPanel?

    init(controller: AppController) {
        self.controller = controller
    }

    func show() {
        if panel == nil { build() }
        reposition()
        // orderFrontRegardless：即使 App 是 accessory 且未激活，也能浮到最前而不抢焦点。
        panel?.orderFrontRegardless()
    }

    func close() {
        panel?.orderOut(nil)
    }

    /// 供无界面自检读取真实面板属性（居中/置顶/不抢焦点）。
    var inspectablePanel: NSPanel? {
        if panel == nil { build() }
        reposition()
        return panel
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    private func build() {
        guard let controller else { return }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Recess"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true       // 仅在确需输入时成为 key，平时不抢焦点。
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        let host = NSHostingController(rootView: RestContentView(controller: controller))
        panel.contentViewController = host
        // 固定内容尺寸，避免 NSHostingController 按 fitting size 把窗口压成竖条。
        panel.setContentSize(NSSize(width: 360, height: 200))
        panel.contentMinSize = NSSize(width: 360, height: 200)
        self.panel = panel
    }

    private func reposition() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}
