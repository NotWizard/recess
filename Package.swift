// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Recess",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "RecessCore"),
        .executableTarget(
            name: "Recess",
            dependencies: ["RecessCore"]
        ),
        // XCTest 未随 Command Line Tools 分发；用不依赖框架的可执行断言测试代替，`swift run RecessTests` 运行。
        .executableTarget(
            name: "RecessTests",
            dependencies: ["RecessCore"]
        ),
    ]
)
