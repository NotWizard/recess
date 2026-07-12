import Foundation
import Combine

/// Recess 计时引擎（锁定语义）。
///
/// 纯逻辑，不依赖 SwiftUI，便于单元测试。时间用"截止时刻(endDate)+注入时钟"驱动，
/// 因此计时按墙上时钟推进（可跨系统休眠正确结算），且测试可通过推进注入时钟确定性验证。
/// 进行中计时不持久化：endDate/phase 仅存内存，重启即空闲。
public final class RecessEngine: ObservableObject {

    // MARK: 对外可观察状态
    @Published public private(set) var phase: Phase = .idle
    @Published public private(set) var remainingSeconds: Int = 0
    @Published public private(set) var todayCount: Int = 0
    /// 内部循环计数：本轮已自然完成的工作段数（0 ..< longBreakEvery），用于菜单栏"3/4"进度与长休触发。
    @Published public private(set) var completedWorkSegments: Int = 0
    /// 工作段自然完成后待开始的休息；等待"开始休息/跳过"。运行时状态，不持久化。
    @Published public private(set) var pendingRest: RestKind? = nil
    @Published public private(set) var config: RecessConfig

    /// 供 GUI 播放结束音效 / 弹休息浮窗 / 发通知。
    public var onEvent: ((RecessEvent) -> Void)?

    // MARK: 依赖注入
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date
    private var endDate: Date?

    private enum Key {
        static let todayCount = "recess.todayCount"
        static let countDate = "recess.countDate"
        static let work = "recess.workMinutes"
        static let short = "recess.shortBreakMinutes"
        static let long = "recess.longBreakMinutes"
        static let every = "recess.longBreakEvery"
    }

    public init(defaults: UserDefaults = .standard,
                calendar: Calendar = .current,
                now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        self.config = RecessEngine.loadConfig(from: defaults)
        loadTodayCount()
        rolloverIfNeeded()
    }

    // MARK: 命令

    /// 工作浮窗"开始"：进入工作中。忽略任何待开始的休息。
    public func startWork() {
        rolloverIfNeeded()
        pendingRest = nil
        phase = .working
        endDate = now().addingTimeInterval(Double(config.workMinutes * 60))
        syncRemaining()
    }

    /// 工作浮窗"结束"：本轮作废——不 +1，内部循环计数不清零，回到空闲。
    public func endCurrentWork() {
        endDate = nil
        phase = .idle
        remainingSeconds = 0
    }

    /// 休息浮窗"开始休息"：按 pendingRest 进入短休/长休并起计时。
    public func startPendingBreak() {
        guard let kind = pendingRest else { return }
        phase = (kind == .long) ? .longBreak : .shortBreak
        let minutes = (kind == .long) ? config.longBreakMinutes : config.shortBreakMinutes
        endDate = now().addingTimeInterval(Double(minutes * 60))
        pendingRest = nil
        syncRemaining()
    }

    /// 休息浮窗"跳过"：放弃这次休息，回到空闲。
    public func skipPendingBreak() {
        pendingRest = nil
        endDate = nil
        phase = .idle
        remainingSeconds = 0
    }

    /// GUI 每秒调用（也可在唤醒时补调）。按墙上时钟结算是否到点。
    public func tick() {
        guard endDate != nil else { return }
        if now() >= endDate! {
            switch phase {
            case .working: completeWork()
            case .shortBreak, .longBreak: completeBreak()
            case .idle: break
            }
        } else {
            syncRemaining()
        }
    }

    /// 设置页保存：钳制到合理范围后生效并持久化。
    public func updateConfig(_ new: RecessConfig) {
        config = new.clamped
        defaults.set(config.workMinutes, forKey: Key.work)
        defaults.set(config.shortBreakMinutes, forKey: Key.short)
        defaults.set(config.longBreakMinutes, forKey: Key.long)
        defaults.set(config.longBreakEvery, forKey: Key.every)
    }

    /// 当前阶段配置总秒数（用于进度显示）。
    public var currentTotalSeconds: Int {
        switch phase {
        case .idle: return 0
        case .working: return config.workMinutes * 60
        case .shortBreak: return config.shortBreakMinutes * 60
        case .longBreak: return config.longBreakMinutes * 60
        }
    }

    // MARK: 内部

    private func completeWork() {
        rolloverIfNeeded()
        todayCount += 1
        persistTodayCount()
        completedWorkSegments += 1
        let kind: RestKind = completedWorkSegments >= config.longBreakEvery ? .long : .short
        if kind == .long { completedWorkSegments = 0 }
        pendingRest = kind
        endDate = nil
        phase = .idle
        remainingSeconds = 0
        onEvent?(.workCompleted(kind))
    }

    private func completeBreak() {
        endDate = nil
        phase = .idle
        remainingSeconds = 0
        pendingRest = nil
        onEvent?(.breakCompleted)
    }

    private func syncRemaining() {
        guard let end = endDate else { remainingSeconds = 0; return }
        remainingSeconds = max(0, Int(ceil(end.timeIntervalSince(now()))))
    }

    // MARK: 持久化（仅：今日计数 + 对应日期 + 四项配置）

    private func loadTodayCount() {
        todayCount = defaults.integer(forKey: Key.todayCount)
    }

    private func persistTodayCount() {
        defaults.set(todayCount, forKey: Key.todayCount)
        defaults.set(now(), forKey: Key.countDate)
    }

    /// 跨天自动归零：存储日期与今天不同日 → 今日计数清零并写入今天。
    private func rolloverIfNeeded() {
        let today = now()
        if let stored = defaults.object(forKey: Key.countDate) as? Date {
            if !calendar.isDate(stored, inSameDayAs: today) {
                todayCount = 0
                defaults.set(0, forKey: Key.todayCount)
                defaults.set(today, forKey: Key.countDate)
            }
        } else {
            // 首次运行：建立日期基线，不动计数。
            defaults.set(today, forKey: Key.countDate)
        }
    }

    private static func loadConfig(from defaults: UserDefaults) -> RecessConfig {
        func value(_ key: String, _ fallback: Int) -> Int {
            let v = defaults.integer(forKey: key)
            return v == 0 ? fallback : v
        }
        let d = RecessConfig.default
        return RecessConfig(
            workMinutes: value(Key.work, d.workMinutes),
            shortBreakMinutes: value(Key.short, d.shortBreakMinutes),
            longBreakMinutes: value(Key.long, d.longBreakMinutes),
            longBreakEvery: value(Key.every, d.longBreakEvery)
        ).clamped
    }
}
