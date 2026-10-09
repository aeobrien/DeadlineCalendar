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
                "Deadline CalendarTests",
                "Deadline CalendarUITests",
                "Deadline Calendar.xcodeproj",
                "build",
                "DeadlineCalendarWidget",
                "DeadlineCalendarWidget/Info.plist",
                "DeadlineCalendarWidgetExtension.entitlements",
                "Deadline Calendar/Preview Content",
                "Deadline Calendar/Deadline Calendar.entitlements",
                "Deadline Calendar/Assets.xcassets",
            ],
            sources: [
                "BackupManager.swift",
                "DeadlineRow.swift",
                "Models.swift",
                "Deadline Calendar"
            ],
            resources: [
                .process("Deadline Calendar/Assets.xcassets")
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
            path: "Deadline CalendarTests"
        )
    ]
)
