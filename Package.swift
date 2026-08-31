// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "task-clock-gui",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "TaskClockGUICore"
        ),
        .executableTarget(
            name: "task-clock-gui",
            dependencies: ["TaskClockGUICore"],
            resources: []
        ),
        .testTarget(
            name: "TaskClockGUICoreTests",
            dependencies: ["TaskClockGUICore"]
        ),
    ]
)
