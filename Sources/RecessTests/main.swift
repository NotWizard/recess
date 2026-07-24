import Foundation
import RecessCore

// 轻量断言测试运行器（无 XCTest 依赖，Command Line Tools 环境可跑）。
// 运行：swift run RecessTests   退出码非 0 表示有用例失败。

var failures = 0
var passed = 0

func check(_ cond: Bool, _ msg: String, file: StaticString = #file, line: UInt = #line) {
    if cond { passed += 1 }
    else { failures += 1; print("FAIL: \(msg) (\(file):\(line))") }
}

func eq<T: Equatable>(_ a: T, _ b: T, _ msg: String, file: StaticString = #file, line: UInt = #line) {
    check(a == b, "\(msg) — expected \(b), got \(a)", file: file, line: line)
}

// 可推进的注入时钟。
final class Clock {
    var current: Date
    init(_ start: Date) { current = start }
    func now() -> Date { current }
    func advance(_ seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

func makeEngine(config: RecessConfig = .default,
                start: Date = Date(timeIntervalSince1970: 1_700_000_000),
                clock: Clock? = nil) -> (RecessEngine, Clock, UserDefaults) {
    let suiteName = "recess.test.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let c = clock ?? Clock(start)
    let engine = RecessEngine(defaults: defaults, calendar: .current, now: c.now)
    engine.updateConfig(config)
    return (engine, c, defaults)
}

/// 让引擎自然完成当前阶段（推进时钟越过截止并 tick）。
func fastForward(_ engine: RecessEngine, _ clock: Clock) {
    clock.advance(TimeInterval(engine.currentTotalSeconds) + 1)
    engine.tick()
}

func test(_ name: String, _ body: () -> Void) {
    body()
}

// MARK: 状态迁移
test("startWork enters working") {
    let (e, _, _) = makeEngine()
    eq(e.phase, .idle, "initial idle")
    e.startWork()
    eq(e.phase, .working, "after startWork -> working")
    eq(e.remainingSeconds, 25 * 60, "remaining = 25min")
}

test("work natural completion counts, goes idle, pending short") {
    let (e, clk, _) = makeEngine()
    e.startWork()
    var events: [RecessEvent] = []
    e.onEvent = { events.append($0) }
    fastForward(e, clk)
    eq(e.todayCount, 1, "count +1")
    eq(e.phase, .idle, "idle after completion")
    eq(e.pendingRest, .short, "pending short")
    eq(events, [.workCompleted(.short)], "workCompleted(short) emitted")
}

test("startPendingBreak enters short break, break does not count") {
    let (e, clk, _) = makeEngine()
    e.startWork(); fastForward(e, clk)
    e.startPendingBreak()
    eq(e.phase, .shortBreak, "short break")
    eq(e.remainingSeconds, 5 * 60, "5min")
    let before = e.todayCount
    fastForward(e, clk)
    eq(e.phase, .idle, "idle after break")
    eq(e.todayCount, before, "break not counted")
}

// MARK: 长休触发（每 4 个工作段）
test("long break after four work segments") {
    let (e, clk, _) = makeEngine()
    var rests: [RestKind] = []
    e.onEvent = { if case let .workCompleted(k) = $0 { rests.append(k) } }
    for _ in 0..<3 {
        e.startWork(); fastForward(e, clk)
        e.startPendingBreak(); fastForward(e, clk)
    }
    e.startWork(); fastForward(e, clk)
    eq(rests, [.short, .short, .short, .long], "4th triggers long")
    eq(e.pendingRest, .long, "pending long")
    eq(e.todayCount, 4, "count 4")
    eq(e.completedWorkSegments, 0, "cycle reset after long")
}

test("cycle progress counts up before long break") {
    let (e, clk, _) = makeEngine()
    e.startWork(); fastForward(e, clk)
    eq(e.completedWorkSegments, 1, "1")
    e.startPendingBreak(); fastForward(e, clk)
    e.startWork(); fastForward(e, clk)
    eq(e.completedWorkSegments, 2, "2")
}

// MARK: 手动结束语义
test("manual end: no +1, cycle counter kept") {
    let (e, clk, _) = makeEngine()
    for _ in 0..<2 {
        e.startWork(); fastForward(e, clk)
        e.startPendingBreak(); fastForward(e, clk)
    }
    eq(e.completedWorkSegments, 2, "cycle 2")
    eq(e.todayCount, 2, "count 2")
    e.startWork()
    e.endCurrentWork()
    eq(e.phase, .idle, "idle after manual end")
    eq(e.todayCount, 2, "no +1")
    eq(e.completedWorkSegments, 2, "cycle counter not reset")
    check(e.pendingRest == nil, "no pending rest")
    e.startWork(); fastForward(e, clk)
    eq(e.completedWorkSegments, 3, "continues to 3")
    eq(e.todayCount, 3, "count 3")
}

test("skip break goes idle") {
    let (e, clk, _) = makeEngine()
    e.startWork(); fastForward(e, clk)
    eq(e.pendingRest, .short, "pending short")
    e.skipPendingBreak()
    eq(e.phase, .idle, "idle")
    check(e.pendingRest == nil, "cleared pending")
}

// MARK: 跨天归零 / 同日保留
test("cross-day reset zeroes today count") {
    let clk = Clock(Date(timeIntervalSince1970: 1_700_000_000))
    let (e, _, defaults) = makeEngine(clock: clk)
    e.startWork(); fastForward(e, clk)
    eq(e.todayCount, 1, "count 1")
    clk.advance(24 * 3600)
    let e2 = RecessEngine(defaults: defaults, calendar: .current, now: clk.now)
    eq(e2.todayCount, 0, "cross-day reset to 0")
}

test("same-day restart keeps count") {
    let clk = Clock(Date(timeIntervalSince1970: 1_700_000_000))
    let (e, _, defaults) = makeEngine(clock: clk)
    e.startWork(); fastForward(e, clk)
    clk.advance(60)
    let e2 = RecessEngine(defaults: defaults, calendar: .current, now: clk.now)
    eq(e2.todayCount, 1, "same-day keeps 1")
}

test("resident engine resets count on day rollover via tick") {
    let clk = Clock(Date(timeIntervalSince1970: 1_700_000_000))
    let (e, _, _) = makeEngine(clock: clk)
    e.startWork(); fastForward(e, clk)
    eq(e.todayCount, 1, "count 1 before rollover")
    clk.advance(24 * 3600)
    e.tick()  // 常驻引擎不重启，靠 tick 触发跨天归零
    eq(e.todayCount, 0, "resident rollover via tick zeroes count")
}

test("resident engine resets long-break cycle on day rollover") {
    let clk = Clock(Date(timeIntervalSince1970: 1_700_000_000))
    let (e, _, _) = makeEngine(clock: clk)
    for _ in 0..<2 {
        e.startWork(); fastForward(e, clk)
        e.skipPendingBreak()
    }
    eq(e.completedWorkSegments, 2, "cycle 2 before rollover")
    clk.advance(24 * 3600)
    e.tick()  // 常驻跨天：长休轮次也应归零，昨日进度不得带入今天
    eq(e.completedWorkSegments, 0, "cycle reset on new day")
    var rests: [RestKind] = []
    e.onEvent = { if case let .workCompleted(k) = $0 { rests.append(k) } }
    for _ in 0..<2 {
        e.startWork(); fastForward(e, clk)
        e.skipPendingBreak()
    }
    eq(rests, [.short, .short], "today's 2nd is short, not long")
    eq(e.completedWorkSegments, 2, "today counts from scratch")
}

// MARK: 进行中计时不持久化
test("in-progress timer not persisted") {
    let clk = Clock(Date(timeIntervalSince1970: 1_700_000_000))
    let (e, _, defaults) = makeEngine(clock: clk)
    e.startWork()
    eq(e.phase, .working, "working")
    let e2 = RecessEngine(defaults: defaults, calendar: .current, now: clk.now)
    eq(e2.phase, .idle, "restart -> idle")
    eq(e2.remainingSeconds, 0, "remaining 0")
}

// MARK: 配置钳制与持久化
test("config clamp and persist") {
    let clk = Clock(Date(timeIntervalSince1970: 1_700_000_000))
    let (e, _, defaults) = makeEngine(clock: clk)
    e.updateConfig(RecessConfig(workMinutes: 0, shortBreakMinutes: 999,
                                longBreakMinutes: -3, longBreakEvery: 0))
    eq(e.config.workMinutes, 1, "clamp work low")
    eq(e.config.shortBreakMinutes, 120, "clamp short high")
    eq(e.config.longBreakMinutes, 1, "clamp long low")
    eq(e.config.longBreakEvery, 1, "clamp every low")
    let e2 = RecessEngine(defaults: defaults, calendar: .current, now: clk.now)
    eq(e2.config.workMinutes, 1, "persisted")
}

print("---")
print("passed: \(passed), failed: \(failures)")
if failures > 0 { exit(1) }
print("ALL TESTS PASSED")
