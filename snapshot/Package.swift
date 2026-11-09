// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "DeadlineCalendar",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "DeadlineCalendar", targets: ["DeadlineCalendar"]),
        .library(name: "DeadlineCalendarWidget", targets: ["DeadlineCalendarWidget"])
    ],
    targets: [
        .target(
            name: "DeadlineCalendar",
            path: ".",
            exclude: [
                "DeadlineCalendarTests",
                "DeadlineCalendarUITests",
                "DeadlineCalendar.xcodeproj",
                "build",
                "DeadlineCalendarWidget",
                "DeadlineCalendarWidget/Info.plist",
                "DeadlineCalendarWidgetExtension.entitlements",
                "DeadlineCalendar/Preview Content",
                "DeadlineCalendar/DeadlineCalendar.entitlements",
                "DeadlineCalendar/Assets.xcassets",
            ],
            sources: [
                "BackupManager.swift",
                "DeadlineRow.swift",
                "Models.swift",
                "DeadlineCalendar"
            ],
            resources: [
                .process("DeadlineCalendar/Assets.xcassets")
            ]
        ),
        .target(
            name: "DeadlineCalendarWidget",
            dependencies: ["DeadlineCalendar"],
            path: "DeadlineCalendarWidget",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "DeadlineCalendarTests",
            dependencies: ["DeadlineCalendar"],
            path: "DeadlineCalendarTests"
        )
    ]
)
