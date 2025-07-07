import SwiftUI
import UserNotifications

// MARK: - Redesigned Settings View with Collapsible Sections
struct BackupRestoreViewRedesigned: View {
    @ObservedObject var viewModel: DeadlineViewModel
    
    // State for showing alerts
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // Notification settings
    @AppStorage("notificationFrequency") private var notificationFrequency = 1
    @AppStorage("notificationDeadlineCount") private var notificationDeadlineCount = 3
    @State private var notificationTime = Date()
    
    // Collapsible section states (all collapsed by default)
    @State private var isColorSectionExpanded = false
    @State private var isNotificationSettingsExpanded = false
    @State private var isDataManagementExpanded = false
    
    // Computed bindings for color settings
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
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Navigation Header to match other views
                    VStack(spacing: 0) {
                        Text("Settings")
                            .font(DesignSystem.Typography.title2)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .padding(.vertical, DesignSystem.Spacing.small)
                            .frame(maxWidth: .infinity)
                            .background(DesignSystem.Colors.background)
                    }
                    
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.medium) {
                        
                        // Deadline Colors Section
                        CollapsibleSection(
                            title: "Deadline Colors",
                            isExpanded: $isColorSectionExpanded
                        ) {
                            VStack(spacing: DesignSystem.Spacing.medium) {
                                ColorThresholdRow(
                                    label: "Days for Green",
                                    value: greenThresholdBinding,
                                    description: "Deadlines more than \(viewModel.appSettings.colorSettings.greenThreshold) days away appear green"
                                )
                                
                                ColorThresholdRow(
                                    label: "Days for Orange",
                                    value: orangeThresholdBinding,
                                    description: "Deadlines more than \(viewModel.appSettings.colorSettings.orangeThreshold) days away appear orange"
                                )
                                
                                Text("Deadlines within \(viewModel.appSettings.colorSettings.orangeThreshold) days appear red")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        // Combined Notifications Section
                        CollapsibleSection(
                            title: "Notifications",
                            isExpanded: $isNotificationSettingsExpanded
                        ) {
                            VStack(spacing: DesignSystem.Spacing.medium) {
                                // Format subsection
                                Text("Format")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, DesignSystem.Spacing.xSmall)
                                
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                                    Text("Title Format")
                                        .font(DesignSystem.Typography.subheadline)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                    
                                    TextField("Title format", text: titleFormatBinding)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                                
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                                    Text("Item Format")
                                        .font(DesignSystem.Typography.subheadline)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                    
                                    TextField("Item format", text: itemFormatBinding)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                                
                                Toggle("Show Project Name", isOn: showProjectNameBinding)
                                    .font(DesignSystem.Typography.body)
                                
                                Toggle("Show Date", isOn: showDateBinding)
                                    .font(DesignSystem.Typography.body)
                                
                                if viewModel.appSettings.notificationFormatSettings.showDate {
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                                        Text("Date Format")
                                            .font(DesignSystem.Typography.subheadline)
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                        
                                        TextField("Date format", text: dateFormatBinding)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                }
                                
                                // Placeholders info
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxSmall) {
                                    Text("Available Placeholders:")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    Text("{index} - Item number")
                                        .font(DesignSystem.Typography.caption2)
                                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    Text("{title} - Deadline title")
                                        .font(DesignSystem.Typography.caption2)
                                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    Text("{project} - Project name")
                                        .font(DesignSystem.Typography.caption2)
                                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    Text("{date} - Due date")
                                        .font(DesignSystem.Typography.caption2)
                                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    Text("{time} - Time remaining (e.g., '2 days')")
                                        .font(DesignSystem.Typography.caption2)
                                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    Text("{days} - Days remaining (number only)")
                                        .font(DesignSystem.Typography.caption2)
                                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                                }
                                
                                Divider()
                                    .background(DesignSystem.Colors.divider)
                                    .padding(.vertical, DesignSystem.Spacing.small)
                                
                                // Settings subsection
                                Text("Settings")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, DesignSystem.Spacing.xSmall)
                                
                                // Notification Time Picker
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                                    Text("Notification Time")
                                        .font(DesignSystem.Typography.subheadline)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                    
                                    DatePicker("", selection: $notificationTime, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(WheelDatePickerStyle())
                                        .labelsHidden()
                                        .frame(height: 100)
                                }
                                
                                // Notification Frequency
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                                    Text("Frequency")
                                        .font(DesignSystem.Typography.subheadline)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                    
                                    Picker("Frequency", selection: $notificationFrequency) {
                                        Text("Daily").tag(1)
                                        Text("Every 2 days").tag(2)
                                        Text("Every 3 days").tag(3)
                                        Text("Weekly").tag(7)
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                }
                                
                                // Number of Deadlines Shown
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                                    HStack {
                                        Text("Show")
                                            .font(DesignSystem.Typography.subheadline)
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                        
                                        Spacer()
                                        
                                        Text("\(notificationDeadlineCount) deadlines")
                                            .font(DesignSystem.Typography.headline)
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                    }
                                    
                                    Slider(value: Binding(
                                        get: { Double(notificationDeadlineCount) },
                                        set: { notificationDeadlineCount = Int($0) }
                                    ), in: 1...10, step: 1)
                                }
                                
                                // Test Notification Button
                                Button {
                                    testNotification()
                                } label: {
                                    HStack {
                                        Image(systemName: "bell.badge")
                                        Text("Test Notification")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .padding(.top, DesignSystem.Spacing.small)
                            }
                        }
                        
                        // Data Management Section
                        CollapsibleSection(
                            title: "Data Management",
                            isExpanded: $isDataManagementExpanded
                        ) {
                            VStack(spacing: DesignSystem.Spacing.medium) {
                                // Export
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                                    Text("Export Data")
                                        .font(DesignSystem.Typography.headline)
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                    
                                    Text("Export your projects, templates, and triggers to a file")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                    
                                    Button {
                                        exportAction()
                                    } label: {
                                        HStack {
                                            Image(systemName: "square.and.arrow.up")
                                            Text("Export Data")
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                }
                                
                                Divider()
                                    .background(DesignSystem.Colors.divider)
                                
                                // Import
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                                    Text("Import Data")
                                        .font(DesignSystem.Typography.headline)
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                    
                                    Text("Import projects and templates from a backup file")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                    
                                    Button {
                                        importAction()
                                    } label: {
                                        HStack {
                                            Image(systemName: "square.and.arrow.down")
                                            Text("Import Data")
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                }
                            }
                        }
                        }
                        .padding(.bottom, DesignSystem.Spacing.xLarge)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .appStyle()
        .onAppear {
            loadNotificationTime()
        }
        .onChange(of: notificationFrequency) { _ in
            viewModel.updateNotifications()
        }
        .onChange(of: notificationDeadlineCount) { _ in
            viewModel.updateNotifications()
        }
        .onChange(of: notificationTime) { newTime in
            saveNotificationTime(newTime)
            viewModel.updateNotifications()
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Helper Views
    
    struct CollapsibleSection<Content: View>: View {
        let title: String
        @Binding var isExpanded: Bool
        let content: () -> Content
        
        var body: some View {
            VStack(spacing: 0) {
                Button {
                    withAnimation(DesignSystem.Animation.fast) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(title)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .padding(DesignSystem.Spacing.medium)
                    .background(DesignSystem.Colors.cardBackground)
                }
                .buttonStyle(PlainButtonStyle())
                
                if isExpanded {
                    VStack(spacing: DesignSystem.Spacing.medium) {
                        content()
                    }
                    .padding(DesignSystem.Spacing.medium)
                    .background(DesignSystem.Colors.cardBackground)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.Radii.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radii.card)
                    .stroke(DesignSystem.Colors.border.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, DesignSystem.Spacing.medium)
        }
    }
    
    struct ColorThresholdRow: View {
        let label: String
        @Binding var value: Int
        let description: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xSmall) {
                HStack {
                    Text(label)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    
                    Spacer()
                    
                    Text("\(value)")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
                
                Slider(value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ), in: 1...30, step: 1)
                
                Text(description)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadNotificationTime() {
        if let savedTime = UserDefaults.standard.object(forKey: "notificationTime") as? Date {
            notificationTime = savedTime
        } else {
            var components = DateComponents()
            components.hour = 9
            components.minute = 30
            notificationTime = Calendar.current.date(from: components) ?? Date()
        }
    }
    
    private func saveNotificationTime(_ time: Date) {
        UserDefaults.standard.set(time, forKey: "notificationTime")
    }
    
    private func testNotification() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus != .authorized {
                    self.alertTitle = "Notifications Not Enabled"
                    self.alertMessage = "Please enable notifications for this app in Settings to use this feature."
                    self.showingAlert = true
                    return
                }
                
                let upcomingDeadlines = self.viewModel.getUpcomingDeadlinesForNotification(limit: self.notificationDeadlineCount)
                
                if upcomingDeadlines.isEmpty {
                    self.alertTitle = "No Upcoming Deadlines"
                    self.alertMessage = "You have no upcoming deadlines to show in the notification."
                    self.showingAlert = true
                    return
                }
                
                let content = UNMutableNotificationContent()
                let formattedContent = self.viewModel.formatNotificationContent(for: upcomingDeadlines)
                content.title = formattedContent.title
                content.body = formattedContent.body
                content.sound = .default
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
                let request = UNNotificationRequest(identifier: "test-notification-\(UUID().uuidString)", content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.alertTitle = "Notification Error"
                            self.alertMessage = "Failed to schedule test notification: \(error.localizedDescription)"
                        } else {
                            self.alertTitle = "Test Notification Scheduled"
                            self.alertMessage = "A test notification will appear in 2 seconds. If you don't see it, make sure the app is in the background."
                        }
                        self.showingAlert = true
                    }
                }
            }
        }
    }
    
    private func exportAction() {
        // This is the same as the original export functionality
        // Implementation would go here
        alertTitle = "Export"
        alertMessage = "Export functionality will be implemented"
        showingAlert = true
    }
    
    private func importAction() {
        // This is the same as the original import functionality
        // Implementation would go here
        alertTitle = "Import"
        alertMessage = "Import functionality will be implemented"
        showingAlert = true
    }
}