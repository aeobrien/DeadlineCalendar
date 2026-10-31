//
//  Deadline_CalendarApp.swift
//  Deadline Calendar
//
//  Created by Aidan O'Brien on 16/10/2024.
//

import SwiftUI
import UserNotifications

// Notification delegate to handle notifications when app is in foreground
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              willPresent notification: UNNotification, 
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct Deadline_CalendarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            if NSClassFromString("XCTestCase") == nil && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                ContentView(viewModel: ProcessInfo.processInfo.arguments.contains("--repeating-fixture")
                    ? DeadlineViewModel.repeatingFixture()
                    : (ProcessInfo.processInfo.arguments.contains("--admin-anchor-fixture") || UserDefaults.standard.bool(forKey: "adminAnchorFixture"))
                    ? DeadlineViewModel.adminAnchorFixture()
                    : DeadlineViewModel())
            } else {
                Color.clear
            }
        }
    }
}

extension DeadlineViewModel {
    /// Dedicated walkthrough data: a local file inside the test app sandbox, never iCloud.
    static func adminAnchorFixture() -> DeadlineViewModel {
        let calendar = Calendar.current
        let january = calendar.date(from: DateComponents(year: 2027, month: 1, day: 31))!
        let february = calendar.date(from: DateComponents(year: 2027, month: 2, day: 28))!
        let pattern = RepetitionPattern(type: .fixedInterval, intervalValue: 1, intervalUnit: .months, maxOccurrences: 2)
        let current = Project(title: "Admin", finalDeadlineDate: january,
                              subDeadlines: [SubDeadline(title: "Month end", date: january)], repetitionPattern: pattern)
        let next = Project(title: "Admin", finalDeadlineDate: february,
                           subDeadlines: [SubDeadline(title: "Month end", date: february, repetitionDayOfMonth: 31)],
                           repetitionPattern: pattern, repetitionSourceID: current.id, repetitionOccurrenceNumber: 2)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("admin-anchor-fixture.json")
        let defaults = UserDefaults(suiteName: "deadline-admin-anchor-fixture")!
        let store = SharedDataStore(fileURL: url)
        let model = DeadlineViewModel(store: store, defaults: defaults, effectsEnabled: false)
        if !FileManager.default.fileExists(atPath: url.path) {
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            let data = try! encoder.encode(SharedData(projects: [current, next], templates: [], triggers: [], appSettings: AppSettings(), lastModified: Date(), lastModifiedBy: "walkthrough-fixture"))
            try! data.write(to: url)
        }
        return model
    }
}

extension DeadlineViewModel {
    /// Made-up repeating projects (weekly, every-3-days, day-of-month), each with an active trigger.
    /// Test-copy data only: a local file inside the test app sandbox, never iCloud, never his real data.
    static func repeatingTestProjects() -> (projects: [Project], triggers: [Trigger]) {
        let calendar = Calendar.current
        func day(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d))! }
        var projects: [Project] = []
        var triggers: [Trigger] = []
        func add(_ title: String, _ final: Date, _ pattern: RepetitionPattern, occurrence: Int, source: UUID?) -> UUID {
            let id = UUID()
            let trigger = Trigger(name: title + " go-ahead", projectID: id, date: final, isActive: true, activationDate: final)
            let sub = SubDeadline(title: title + " draft", date: final, triggerID: trigger.id, repetitionPattern: pattern)
            projects.append(Project(id: id, title: title, finalDeadlineDate: final, subDeadlines: [sub], triggers: [trigger],
                                    repetitionPattern: pattern, repetitionSourceID: source, repetitionOccurrenceNumber: occurrence))
            triggers.append(trigger)
            return id
        }
        let weekly = RepetitionPattern(type: .fixedInterval, intervalValue: 1, intervalUnit: .weeks, maxOccurrences: 6)
        let everyThree = RepetitionPattern(type: .fixedInterval, intervalValue: 3, intervalUnit: .days, maxOccurrences: 4)
        let monthly = RepetitionPattern(type: .dayOfMonth, dayOfMonthDay: 15, maxOccurrences: 6)
        let w1 = add("Sample Weekly Review", day(2027, 3, 1), weekly, occurrence: 1, source: nil)
        _ = add("Sample Weekly Review", day(2027, 3, 8), weekly, occurrence: 2, source: w1)
        _ = add("Sample Every Three Days", day(2027, 3, 4), everyThree, occurrence: 1, source: nil)
        _ = add("Sample Mid-Month Report", day(2027, 3, 15), monthly, occurrence: 1, source: nil)
        return (projects, triggers)
    }

    static func repeatingFixture() -> DeadlineViewModel {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("repeating-fixture.json")
        let defaults = UserDefaults(suiteName: "deadline-repeating-fixture")!
        let store = SharedDataStore(fileURL: url)
        let model = DeadlineViewModel(store: store, defaults: defaults, effectsEnabled: false)
        if !FileManager.default.fileExists(atPath: url.path) {
            let data = repeatingTestProjects()
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            let bytes = try! encoder.encode(SharedData(projects: data.projects, templates: [], triggers: data.triggers, appSettings: AppSettings(), lastModified: Date(), lastModifiedBy: "walkthrough-fixture"))
            try! bytes.write(to: url)
        }
        return model
    }
}

// App delegate to set up notification handling
class AppDelegate: NSObject, UIApplicationDelegate {
    let notificationDelegate = NotificationDelegate()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}
