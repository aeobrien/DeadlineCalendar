// Deadline Calendar/Deadline Calendar/BackupRestoreView.swift

import SwiftUI
import UserNotifications

struct BackupRestoreView: View {
    // Access the shared ViewModel
    @ObservedObject var viewModel: DeadlineViewModel
    
    // State for showing alerts
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // Notification settings
    @AppStorage("notificationFrequency") private var notificationFrequency = 1 // Days between notifications
    @AppStorage("notificationDeadlineCount") private var notificationDeadlineCount = 3 // Number of deadlines to show
    @State private var notificationTime = Date() // Time of day for notifications
    
    // Computed bindings for color settings to avoid complex expressions
    private var greenThresholdBinding: Binding<Int> {
        Binding(
            get: { viewModel.appSettings.colorSettings.greenThreshold },
            set: { newValue in
                var settings = viewModel.appSettings.colorSettings
                settings.greenThreshold = newValue
                viewModel.updateColorSettings(settings)
            }
        )
    }
    
    private var orangeThresholdBinding: Binding<Int> {
        Binding(
            get: { viewModel.appSettings.colorSettings.orangeThreshold },
            set: { newValue in
                var settings = viewModel.appSettings.colorSettings
                settings.orangeThreshold = newValue
                viewModel.updateColorSettings(settings)
            }
        )
    }
    
    // Computed bindings for notification format settings
    private var titleFormatBinding: Binding<String> {
        Binding(
            get: { viewModel.appSettings.notificationFormatSettings.titleFormat },
            set: { newValue in
                var settings = viewModel.appSettings.notificationFormatSettings
                settings.titleFormat = newValue
                viewModel.updateNotificationFormatSettings(settings)
            }
        )
    }
    
    private var itemFormatBinding: Binding<String> {
        Binding(
            get: { viewModel.appSettings.notificationFormatSettings.itemFormat },
            set: { newValue in
                var settings = viewModel.appSettings.notificationFormatSettings
                settings.itemFormat = newValue
                viewModel.updateNotificationFormatSettings(settings)
            }
        )
    }
    
    private var showProjectNameBinding: Binding<Bool> {
        Binding(
            get: { viewModel.appSettings.notificationFormatSettings.showProjectName },
            set: { newValue in
                var settings = viewModel.appSettings.notificationFormatSettings
                settings.showProjectName = newValue
                viewModel.updateNotificationFormatSettings(settings)
            }
        )
    }
    
    private var showDateBinding: Binding<Bool> {
        Binding(
            get: { viewModel.appSettings.notificationFormatSettings.showDate },
            set: { newValue in
                var settings = viewModel.appSettings.notificationFormatSettings
                settings.showDate = newValue
                viewModel.updateNotificationFormatSettings(settings)
            }
        )
    }
    
    private var dateFormatBinding: Binding<String> {
        Binding(
            get: { viewModel.appSettings.notificationFormatSettings.dateFormat },
            set: { newValue in
                var settings = viewModel.appSettings.notificationFormatSettings
                settings.dateFormat = newValue
                viewModel.updateNotificationFormatSettings(settings)
            }
        )
    }

    // MARK: – Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    ColorSettingsSection(viewModel: viewModel)
                    NotificationFormatSection(viewModel: viewModel)
                    NotificationSettingsSection(
                        notificationFrequency: $notificationFrequency,
                        notificationDeadlineCount: $notificationDeadlineCount,
                        notificationTime: $notificationTime,
                        testAction: testNotification
                    )
                    ExportSection(exportAction: exportAction)
                    ImportSection(importAction: importAction)
                }
                .padding()
            }
            .navigationTitle("Settings")
            .preferredColorScheme(.dark)
            // Global alert handler
            .alert(isPresented: $showingAlert) {
                Alert(title: Text(alertTitle),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
            // Keep notifications up-to-date
            .onChange(of: notificationFrequency)      { _ in viewModel.updateNotifications() }
            .onChange(of: notificationDeadlineCount) { _ in viewModel.updateNotifications() }
            .onChange(of: notificationTime) { new in
                UserDefaults.standard.set(new, forKey: "notificationTime")
                viewModel.updateNotifications()
            }
            .onAppear(perform: loadSavedTime)
        }
        .navigationViewStyle(.stack)
    }

    // Loads persisted notification time or falls back to 09:30
    private func loadSavedTime() {
        if let saved = UserDefaults.standard.object(forKey: "notificationTime") as? Date {
            notificationTime = saved
        } else {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour   = 9
            comps.minute = 30
            notificationTime = Calendar.current.date(from: comps) ?? Date()
        }
    }


    // MARK: - Actions
    
    private func testNotification() {
        print("BackupRestoreView: Testing notification...")
        
        // First check notification authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus != .authorized {
                    self.alertTitle = "Notifications Not Enabled"
                    self.alertMessage = "Please enable notifications for this app in Settings to use this feature."
                    self.showingAlert = true
                    return
                }
                
                // Get notification content from viewModel
                let upcomingDeadlines = self.viewModel.getUpcomingDeadlinesForNotification(limit: self.notificationDeadlineCount)
                
                if upcomingDeadlines.isEmpty {
                    // Show alert if no deadlines
                    self.alertTitle = "No Upcoming Deadlines"
                    self.alertMessage = "You have no upcoming deadlines to show in the notification."
                    self.showingAlert = true
                    return
                }
                
                // Create notification content using the formatted settings
                let content = UNMutableNotificationContent()
                let formattedContent = self.viewModel.formatNotificationContent(for: upcomingDeadlines)
                content.title = formattedContent.title
                content.body = formattedContent.body
                content.sound = .default
                
                // Create trigger for 2 seconds from now (shorter delay)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
                
                // Create request with unique identifier
                let request = UNNotificationRequest(identifier: "test-notification-\(UUID().uuidString)", content: content, trigger: trigger)
                
                // Schedule the notification
                UNUserNotificationCenter.current().add(request) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.alertTitle = "Notification Error"
                            self.alertMessage = "Failed to schedule test notification: \(error.localizedDescription)"
                        } else {
                            self.alertTitle = "Test Notification Scheduled"
                            self.alertMessage = "A test notification will appear in 2 seconds. If you don't see it, make sure the app is in the background."
                            
                            // Print for debugging
                            print("Test notification scheduled successfully")
                            print("Content: \(content.title) - \(content.body)")
                        }
                        self.showingAlert = true
                    }
                }
            }
        }
    }

    private func exportAction() {
        print("BackupRestoreView: Export button tapped.")
        do {
            // Pass the current projects, templates, triggers, AND settings from the ViewModel
            try BackupManager.exportData(projects: viewModel.projects, 
                                         templates: viewModel.templates, 
                                         triggers: viewModel.triggers,
                                         appSettings: viewModel.appSettings)
            print("BackupRestoreView: Export successful.")
            // Show success alert
            alertTitle = "Export Successful"
            alertMessage = "All projects, templates, triggers, and settings have been copied to your clipboard."
            showingAlert = true
        } catch let error as BackupError {
            print("BackupRestoreView: Export failed. Error: \(error.localizedDescription)")
            // Show specific backup error alert
            alertTitle = "Export Failed"
            alertMessage = error.localizedDescription
            showingAlert = true
        } catch {
            print("BackupRestoreView: Export failed with unexpected error: \(error)")
            // Show generic error alert
            alertTitle = "Export Failed"
            alertMessage = "An unexpected error occurred during export: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func importAction() {
        print("BackupRestoreView: Import button tapped.")
        do {
            // 1. Get data from clipboard via BackupManager (returns tuple now)
            let importedData = try BackupManager.importData()
            print("BackupRestoreView: Successfully decoded and reconstructed data from clipboard.")
            print("  Projects: \(importedData.projects.count)")
            print("  Templates: \(importedData.templates.count)")
            print("  Triggers: \(importedData.triggers.count)")
            print("  App Settings: imported")

            // 2. Replace ViewModel data 
            viewModel.projects = importedData.projects
            viewModel.templates = importedData.templates
            viewModel.triggers = importedData.triggers // <-- Assign the reconstructed triggers
            viewModel.appSettings = importedData.appSettings // <-- Assign the imported settings

            // 3. Save the new data via ViewModel's save functions
            viewModel.saveProjects()
            viewModel.saveTemplates()
            viewModel.saveTriggers() // <-- Save the triggers
            viewModel.saveAppSettings() // <-- Save the settings

            print("BackupRestoreView: Import successful. ViewModel data replaced and saved.")

            // 4. Show success alert
            alertTitle = "Import Successful"
            alertMessage = "Successfully restored \(importedData.projects.count) projects, \(importedData.templates.count) templates, \(importedData.triggers.count) triggers, and settings from the clipboard. All previous data has been replaced."
            showingAlert = true

        } catch let error as BackupError {
            print("BackupRestoreView: Import failed. Error: \(error.localizedDescription)")
            alertTitle = "Import Failed"
            alertMessage = error.localizedDescription
            showingAlert = true
        } catch {
            print("BackupRestoreView: Import failed with unexpected error: \(error)")
            alertTitle = "Import Failed"
            alertMessage = "An unexpected error occurred during import: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}


// MARK: - Colour settings
private struct ColorSettingsSection: View {
    @ObservedObject var viewModel: DeadlineViewModel
    private var green: Binding<Int> {
        Binding(get: { viewModel.appSettings.colorSettings.greenThreshold },
                set: { n in var s = viewModel.appSettings.colorSettings; s.greenThreshold = n; viewModel.updateColorSettings(s) })
    }
    private var orange: Binding<Int> {
        Binding(get: { viewModel.appSettings.colorSettings.orangeThreshold },
                set: { n in var s = viewModel.appSettings.colorSettings; s.orangeThreshold = n; viewModel.updateColorSettings(s) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Deadline Colours").font(.title2).fontWeight(.semibold)
            Text("Customise when deadlines change colour based on days remaining")
                .font(.subheadline).foregroundColor(.gray)

            HStack {
                Text("Green (safe)")
                Spacer()
                Text("≥")
                Stepper("\(viewModel.appSettings.colorSettings.greenThreshold) days",
                        value: green, in: 8...90)
            }

            HStack {
                Text("Orange (warning)")
                Spacer()
                Text("≥")
                Stepper(
                    "\(viewModel.appSettings.colorSettings.orangeThreshold) days",
                    value: orange,
                    in: 1...(viewModel.appSettings.colorSettings.greenThreshold - 1) // ✅ ClosedRange<Int>
                )
            }



            HStack {
                Text("Red (urgent)")
                Spacer()
                Text("< \(viewModel.appSettings.colorSettings.orangeThreshold) days")
                    .foregroundColor(.gray)
            }

            // Tiny preview
            HStack {
                Text("Preview:")
                Spacer()
                Label("Safe",    systemImage: "circle.fill").foregroundColor(.green).font(.caption)
                Label("Warning", systemImage: "circle.fill").foregroundColor(.orange).font(.caption)
                Label("Urgent",  systemImage: "circle.fill").foregroundColor(.red).font(.caption)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Notification format
private struct NotificationFormatSection: View {
    @ObservedObject var viewModel: DeadlineViewModel
    private var title: Binding<String> {
        Binding(get: { viewModel.appSettings.notificationFormatSettings.titleFormat },
                set: { t in var s = viewModel.appSettings.notificationFormatSettings; s.titleFormat = t; viewModel.updateNotificationFormatSettings(s) })
    }
    private var item: Binding<String> {
        Binding(get: { viewModel.appSettings.notificationFormatSettings.itemFormat },
                set: { v in var s = viewModel.appSettings.notificationFormatSettings; s.itemFormat = v; viewModel.updateNotificationFormatSettings(s) })
    }
    private var showProject: Binding<Bool> {
        Binding(get: { viewModel.appSettings.notificationFormatSettings.showProjectName },
                set: { v in var s = viewModel.appSettings.notificationFormatSettings; s.showProjectName = v; viewModel.updateNotificationFormatSettings(s) })
    }
    private var showDate: Binding<Bool> {
        Binding(get: { viewModel.appSettings.notificationFormatSettings.showDate },
                set: { v in var s = viewModel.appSettings.notificationFormatSettings; s.showDate = v; viewModel.updateNotificationFormatSettings(s) })
    }
    private var dateFmt: Binding<String> {
        Binding(get: { viewModel.appSettings.notificationFormatSettings.dateFormat },
                set: { v in var s = viewModel.appSettings.notificationFormatSettings; s.dateFormat = v; viewModel.updateNotificationFormatSettings(s) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notification Format").font(.title2).fontWeight(.semibold)
            Text("Customise how notification content is formatted")
                .font(.subheadline).foregroundColor(.gray)

            Group {
                Text("Notification Title").font(.subheadline)
                TextField("Notification Title", text: title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            Group {
                Text("Item Format").font(.subheadline)
                TextField("Item Format", text: item)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            Toggle("Show Project Name", isOn: showProject)
            Toggle("Show Date",          isOn: showDate)

            if viewModel.appSettings.notificationFormatSettings.showDate {
                Group {
                    Text("Date Format").font(.subheadline)
                    TextField("Date Format", text: dateFmt)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }

            // Placeholder cheat-sheet
            // Placeholder cheat-sheet
            VStack(alignment: .leading, spacing: 2) {
                Text("Available Placeholders")
                    .font(.subheadline).fontWeight(.semibold)

                ForEach(NotificationFormatSettings.availablePlaceholders.keys.sorted(),
                        id: \.self) { key in
                    if let desc = NotificationFormatSettings.availablePlaceholders[key] {
                        HStack(alignment: .top) {
                            Text(key)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.blue)
                            Text("- \(desc)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }

        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Notification scheduling
private struct NotificationSettingsSection: View {
    @Binding var notificationFrequency: Int
    @Binding var notificationDeadlineCount: Int
    @Binding var notificationTime: Date
    var testAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications").font(.title2).fontWeight(.semibold)

            HStack {
                Text("Frequency")
                Spacer()
                Picker("", selection: $notificationFrequency) {
                    Text("Daily").tag(1)
                    Text("Every 2 days").tag(2)
                    Text("Every 3 days").tag(3)
                    Text("Weekly").tag(7)
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text("Show deadlines")
                Spacer()
                Picker("", selection: $notificationDeadlineCount) {
                    ForEach(1...10, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.menu)
            }


            DatePicker("Notification time",
                       selection: $notificationTime,
                       displayedComponents: .hourAndMinute)

            Button(action: testAction) {
                Label("Test Notification", systemImage: "bell")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Export widget
private struct ExportSection: View {
    var exportAction: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Export Data").font(.title2).fontWeight(.semibold)
            Text("Copies all your current projects and templates to the clipboard as text. Paste this text somewhere safe to create a backup.")
                .font(.subheadline).foregroundColor(.gray)
            Button(action: exportAction) {
                Label("Export to Clipboard", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Import widget
private struct ImportSection: View {
    var importAction: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Import Data").font(.title2).fontWeight(.semibold)
            Text("Restores projects and templates from text copied to the clipboard. WARNING: This will permanently replace ALL current projects and templates.")
                .font(.subheadline).foregroundColor(.gray)
            Button(action: importAction) {
                Label("Import from Clipboard", systemImage: "clipboard.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Preview Provider
struct BackupRestoreView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dummy ViewModel for preview purposes
        BackupRestoreView(viewModel: DeadlineViewModel())
             .preferredColorScheme(.dark)
    }
}


