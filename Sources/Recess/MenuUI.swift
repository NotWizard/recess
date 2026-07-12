import SwiftUI
import RecessCore

/// 菜单栏与主按钮的纯展示逻辑（单一真相，供视图与 --selftest 共用）。
enum MenuUI {

    // MARK: 菜单栏

    /// 菜单栏是否显示倒计时（进行中=是；空闲=否，只显示图标）。
    static func showsCountdown(phase: Phase) -> Bool {
        phase != .idle
    }

    /// 菜单栏图标（空闲及待休息态用；进行中不显示图标只显示倒计时）。
    static func barSymbol(phase: Phase, pendingRest: RestKind?) -> String {
        pendingRest != nil ? "cup.and.saucer.fill" : "timer"
    }

    /// 菜单栏倒计时文本 "MM:SS"。
    static func barCountdown(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: 主按钮

    /// 圆形主按钮的动作语义，由当前阶段 + 是否有待开始休息决定。
    enum PrimaryAction: Equatable {
        case startWork    // 空闲且无待休息
        case endWork      // 工作中
        case startBreak   // 待休息(工作刚完成)
        case skipBreak    // 短休/长休进行中(圆按钮=跳过)
    }

    static func primaryAction(phase: Phase, pendingRest: RestKind?) -> PrimaryAction {
        switch phase {
        case .idle:               return pendingRest != nil ? .startBreak : .startWork
        case .working:            return .endWork
        case .shortBreak, .longBreak: return .skipBreak
        }
    }

    /// 主按钮视觉类型：go=开始类(绿色实心)，stop=结束/跳过类(红色实心)。
    enum ButtonKind: Equatable { case go, stop }

    static func buttonKind(_ action: PrimaryAction) -> ButtonKind {
        switch action {
        case .startWork, .startBreak: return .go
        case .endWork, .skipBreak:    return .stop
        }
    }

    /// 阶段配色语义（用于菜单栏底色）：work=工作(暖色)，rest=休息(绿色)，none=空闲(无底色)。
    enum PhaseTint: Equatable { case none, work, rest }

    static func phaseTint(phase: Phase) -> PhaseTint {
        switch phase {
        case .idle:                   return .none
        case .working:                return .work
        case .shortBreak, .longBreak: return .rest
        }
    }

    /// 主按钮下方的动作说明文字。
    static func primaryTitle(_ action: PrimaryAction) -> String {
        switch action {
        case .startWork:  return "开始工作"
        case .endWork:    return "结束"
        case .startBreak: return "开始休息"
        case .skipBreak:  return "跳过"
        }
    }

    /// 主按钮中心的 SF Symbol。
    static func primarySymbol(_ action: PrimaryAction) -> String {
        switch action {
        case .startWork:  return "play.fill"
        case .endWork:    return "stop.fill"
        case .startBreak: return "cup.and.saucer.fill"
        case .skipBreak:  return "forward.fill"
        }
    }

    // MARK: 进度环

    /// 进度环进度 0...1：进行中按已过比例填充；空闲/待休息为 0（不显示环）。
    static func ringProgress(phase: Phase, remaining: Int, total: Int) -> Double {
        guard phase != .idle, total > 0 else { return 0 }
        let elapsed = Double(total - remaining)
        return min(max(elapsed / Double(total), 0), 1)
    }

    /// 顶部状态文字。
    static func statusText(phase: Phase, pendingRest: RestKind?) -> String {
        switch phase {
        case .idle:       return pendingRest != nil ? "待休息" : "空闲"
        case .working:    return "工作中"
        case .shortBreak: return "短休中"
        case .longBreak:  return "长休中"
        }
    }
}
