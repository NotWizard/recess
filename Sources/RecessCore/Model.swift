import Foundation

/// 四态状态机（锁定）：空闲 / 工作中 / 短休中 / 长休中。无暂停。
public enum Phase: String, Equatable, Sendable {
    case idle
    case working
    case shortBreak
    case longBreak
}

/// 待开始的休息类型（工作段自然完成后产生，等待用户"开始休息/跳过"）。
public enum RestKind: Equatable, Sendable {
    case short
    case long
}

/// 引擎对外事件——GUI 据此播放结束音效、弹出休息浮窗、发通知。
public enum RecessEvent: Equatable, Sendable {
    /// 一个工作段自然完成（已 +1、已推进循环计数），带出应休息的类型。
    case workCompleted(RestKind)
    /// 一段休息自然结束，回到空闲。
    case breakCompleted
}

/// 四项时长配置（锁定默认值：工作 25 / 短休 5 / 长休 15 / 每 4 个后长休）。
public struct RecessConfig: Equatable, Sendable {
    public var workMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    public var longBreakEvery: Int

    public static let `default` = RecessConfig(
        workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, longBreakEvery: 4
    )

    public init(workMinutes: Int, shortBreakMinutes: Int, longBreakMinutes: Int, longBreakEvery: Int) {
        self.workMinutes = workMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.longBreakEvery = longBreakEvery
    }

    /// 设置项来自用户输入，属信任边界——落盘/生效前钳制到合理范围。
    public var clamped: RecessConfig {
        RecessConfig(
            workMinutes: min(max(workMinutes, 1), 180),
            shortBreakMinutes: min(max(shortBreakMinutes, 1), 120),
            longBreakMinutes: min(max(longBreakMinutes, 1), 120),
            longBreakEvery: min(max(longBreakEvery, 1), 12)
        )
    }
}
