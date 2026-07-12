import AppKit
import SwiftUI
import RecessCore
import Combine

/// 菜单栏状态项：用 NSStatusItem 自绘（空闲=模板图标；进行中=带橙/绿胶囊底色的倒计时图片，
/// 因为 SwiftUI MenuBarExtra 的 label 背景会被系统忽略，只有自绘 NSImage 才能真正上底色）。
/// 点击弹出承载 MenuContentView 的 NSPopover。
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let controller: AppController
    private var cancellables = Set<AnyCancellable>()

    init(controller: AppController) {
        self.controller = controller
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuContentView(controller: controller)
        )

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
        }

        controller.dismissPopover = { [weak self] in self?.popover.performClose(nil) }

        // 引擎任何 @Published 变化 -> 重绘菜单栏。秒级 tick 也只是重画一张小图，开销可忽略。
        controller.engine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.render() }
            .store(in: &cancellables)

        render()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func render() {
        guard let button = statusItem.button else { return }
        let e = controller.engine
        if MenuUI.showsCountdown(phase: e.phase) {
            let text = MenuUI.barCountdown(e.remainingSeconds)
            let tint = StatusItemController.color(for: MenuUI.phaseTint(phase: e.phase))
            button.image = StatusItemController.capsuleImage(text: text, fill: tint)
            button.title = ""
        } else {
            button.image = StatusItemController.symbolImage(
                MenuUI.barSymbol(phase: e.phase, pendingRest: e.pendingRest))
            button.title = ""
        }
    }

    // MARK: 自绘

    private static func color(for tint: MenuUI.PhaseTint) -> NSColor {
        switch tint {
        case .none: return .clear
        case .work: return NSColor.systemOrange
        case .rest: return NSColor.systemGreen
        }
    }

    /// 空闲图标：模板化 SF Symbol，随系统深浅色自适应。
    private static func symbolImage(_ name: String) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Recess")?
            .withSymbolConfiguration(cfg)
        img?.isTemplate = true
        return img
    }

    /// 倒计时胶囊：白字 + 指定底色，画成非模板彩色图贴到菜单栏。
    static func capsuleImage(text: String, fill: NSColor) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let hPad: CGFloat = 7, vPad: CGFloat = 2
        let w = ceil(textSize.width) + hPad * 2
        let h = ceil(textSize.height) + vPad * 2
        let image = NSImage(size: NSSize(width: w, height: h))
        image.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: w, height: h)
        let path = NSBezierPath(roundedRect: rect, xRadius: h / 2, yRadius: h / 2)
        fill.setFill()
        path.fill()
        (text as NSString).draw(
            at: NSPoint(x: hPad, y: vPad),
            withAttributes: attrs)
        image.unlockFocus()
        image.isTemplate = false   // 彩色底色，不能模板化
        return image
    }
}
