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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // --- Notification Settings Section ---
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notifications")
                            .font(.title2).fontWeight(.semibold)
                        
                        // Frequency picker
                        HStack {
                            Text("Frequency")
                                .font(.subheadline)
                            Spacer()
                            Picker("", selection: $notificationFrequency) {
                                Text("Daily").tag(1)
                                Text("Every 2 days").tag(2)
                                Text("Every 3 days").tag(3)
                                Text("Weekly").tag(7)
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // Number of deadlines picker
                        HStack {
                            Text("Show deadlines")
                                .font(.subheadline)
                            Spacer()
                            Picker("", selection: $notificationDeadlineCount) {
                                ForEach(1...10, id: \.self) { count in
                                    Text("\(count)").tag(count)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // Time picker
                        DatePicker("Notification time", 
                                 selection: $notificationTime,
                                 displayedComponents: .hourAndMinute)
                            .font(.subheadline)
                        
                        // Test notification button
                        Button {
                            testNotification()
                        } label: {
                            Label("Test Notification", systemImage: "bell")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    
                    // --- Export Section ---
                VStack(alignment: .leading, spacing: 10) {
                    Text("Export Data")
                        .font(.title2).fontWeight(.semibold)
                    Text("Copies all your current projects and templates to the clipboard as text. Paste this text somewhere safe to create a backup.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Button {
                        exportAction()
                    } label: {
                        Label("Export to Clipboard", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity) // Make button wide
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue) // Style the button
                }
                .padding()
                .background(Color(.secondarySystemBackground)) // Subtle background
                .cornerRadius(10)

                // --- Import Section ---
                VStack(alignment: .leading, spacing: 10) {
                    Text("Import Data")
                        .font(.title2).fontWeight(.semibold)
                    Text("Restores projects and templates from text copied to the clipboard. WARNING: This will permanently replace ALL current projects and templates.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Button {
                        importAction()
                    } label: {
                        Label("Import from Clipboard", systemImage: "clipboard.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange) // Use a different color for caution
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)

                }
                .padding() // Padding around the main VStack
            }
            .navigationTitle("Settings")
            .preferredColorScheme(.dark) // Maintain dark mode
            .alert(isPresented: $showingAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onChange(of: notificationFrequency) { _ in
                viewModel.updateNotifications()
            }
            .onChange(of: notificationDeadlineCount) { _ in
                viewModel.updateNotifications()
            }
            .onChange(of: notificationTime) { newTime in
                // Save time to UserDefaults
                UserDefaults.standard.set(newTime, forKey: "notificationTime")
                viewModel.updateNotifications()
            }
            .onAppear {
                // Load saved notification time
                if let savedTime = UserDefaults.standard.object(forKey: "notificationTime") as? Date {
                    notificationTime = savedTime
                } else {
                    // Default to 9:30 AM
                    var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                    components.hour = 9
                    components.minute = 30
                    if let defaultTime = Calendar.current.date(from: components) {
                        notificationTime = defaultTime
                    }
                }
            }
        }
        .navigationViewStyle(.stack) // Use stack style
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
                
                // Create notification content
                let content = UNMutableNotificationContent()
                content.title = "Upcoming Deadlines"
                
                var bodyText = ""
                for (index, deadline) in upcomingDeadlines.enumerated() {
                    let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: deadline.date).day ?? 0
                    let dayText = daysUntil == 0 ? "Today" : daysUntil == 1 ? "Tomorrow" : "In \(daysUntil) days"
                    bodyText += "\(index + 1). \(deadline.title) - \(dayText)\n"
                }
                content.body = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
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
            // Pass the current projects, templates, AND triggers from the ViewModel
            try BackupManager.exportData(projects: viewModel.projects, 
                                         templates: viewModel.templates, 
                                         triggers: viewModel.triggers)
            print("BackupRestoreView: Export successful.")
            // Show success alert
            alertTitle = "Export Successful"
            alertMessage = "All projects, templates, and triggers have been copied to your clipboard."
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

            // 2. Replace ViewModel data 
            viewModel.projects = importedData.projects
            viewModel.templates = importedData.templates
            viewModel.triggers = importedData.triggers // <-- Assign the reconstructed triggers

            // 3. Save the new data via ViewModel's save functions
            viewModel.saveProjects()
            viewModel.saveTemplates()
            viewModel.saveTriggers() // <-- Save the triggers

            print("BackupRestoreView: Import successful. ViewModel data replaced and saved.")

            // 4. Show success alert
            alertTitle = "Import Successful"
            alertMessage = "Successfully restored \(importedData.projects.count) projects, \(importedData.templates.count) templates, and \(importedData.triggers.count) triggers from the clipboard. All previous data has been replaced."
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

// MARK: - Preview Provider
struct BackupRestoreView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dummy ViewModel for preview purposes
        BackupRestoreView(viewModel: DeadlineViewModel())
             .preferredColorScheme(.dark)
    }
} 