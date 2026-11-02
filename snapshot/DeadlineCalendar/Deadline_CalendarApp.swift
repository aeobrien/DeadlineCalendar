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
                ContentView(viewModel: (ProcessInfo.processInfo.arguments.contains("--restore-fixture") || UserDefaults.standard.bool(forKey: "restoreFixture"))
                    ? DeadlineViewModel.restoreFixture()
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
    /// Backup-restore test data: made-up deadlines in a local file, and one made-up backup holding a
    /// monthly Admin task in a local folder standing in for iCloud. Reset on every launch; never iCloud.
    @MainActor private static var restoreFixtureModel: DeadlineViewModel?

    @MainActor static func restoreFixture() -> DeadlineViewModel {
        // The window body can be rebuilt; build the fixture once so it is not reset mid-run.
        if let existing = restoreFixtureModel { return existing }
        let calendar = Calendar.current
        let temp = FileManager.default.temporaryDirectory
        let backups = temp.appendingPathComponent("restore-fixture-backups")
        let url = temp.appendingPathComponent("restore-fixture.json")
        try? FileManager.default.removeItem(at: backups)
        try? FileManager.default.removeItem(at: url)
        iCloudBackupManager.fixtureBackupsFolder = backups
        iCloudBackupManager.shared.checkiCloudAvailability()

        let january = calendar.date(from: DateComponents(year: 2027, month: 1, day: 31))!
        let february = calendar.date(from: DateComponents(year: 2027, month: 2, day: 28))!
        let pattern = RepetitionPattern(type: .fixedInterval, intervalValue: 1, intervalUnit: .months, maxOccurrences: 2)
        let current = Project(title: "Admin", finalDeadlineDate: january,
                              subDeadlines: [SubDeadline(title: "Month end", date: january, repetitionPattern: pattern)], repetitionPattern: pattern)
        let next = Project(title: "Admin", finalDeadlineDate: february,
                           subDeadlines: [SubDeadline(title: "Month end", date: february, repetitionPattern: pattern, repetitionDayOfMonth: 31)],
                           repetitionPattern: pattern, repetitionSourceID: current.id, repetitionOccurrenceNumber: 2)
        let backedUp = [current, next]
        let placeholderDate = calendar.date(from: DateComponents(year: 2027, month: 1, day: 15))!
        let placeholder = Project(title: "Placeholder", finalDeadlineDate: placeholderDate,
                                  subDeadlines: [SubDeadline(title: "Placeholder item", date: placeholderDate)])

        let defaults = UserDefaults(suiteName: "deadline-restore-fixture")!
        defaults.removePersistentDomain(forName: "deadline-restore-fixture")
        Task { try? await iCloudBackupManager.shared.createBackup(projects: backedUp, templates: [], triggers: [], appSettings: AppSettings()) }
        let model = DeadlineViewModel(store: SharedDataStore(fileURL: url), defaults: defaults, effectsEnabled: false)
        _ = model.reloadCurrentData()
        _ = model.addProject(placeholder)
        restoreFixtureModel = model
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
