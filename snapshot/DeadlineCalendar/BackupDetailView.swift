// Deadline Calendar/DeadlineCalendar/BackupDetailView.swift

import SwiftUI

struct BackupDetailView: View {
    let document: DeadlineCalendarBackupDocument
    @ObservedObject var viewModel: DeadlineViewModel
    @StateObject private var backupManager = iCloudBackupManager.shared
    
    @State private var backupData: DeadlineCalendarBackupData?
    @State private var isLoading = true
    @State private var selectedTab = 0
    @State private var showingRestoreConfirmation = false
    @State private var showingRestoreError = false
    @State private var restoreError: String = ""
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading backup...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let data = backupData {
                VStack(spacing: 0) {
                    // Segmented Control
                    Picker("View", selection: $selectedTab) {
                        Text("Summary").tag(0)
                        Text("Projects").tag(1)
                        Text("Templates").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    // Content based on selected tab
                    TabView(selection: $selectedTab) {
                        summaryView(data: data)
                            .tag(0)
                        
                        projectsView(data: data)
                            .tag(1)
                        
                        templatesView(data: data)
                            .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            } else {
                Text("Failed to load backup data")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Backup Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Restore") {
                    showingRestoreConfirmation = true
                }
                .foregroundColor(DesignSystem.Colors.primary)
            }
        }
        .onAppear {
            loadBackupData()
        }
        .alert("Restore Backup?", isPresented: $showingRestoreConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                restoreBackup()
            }
        } message: {
            Text("This will replace all current projects, templates, and settings with the data from this backup. This action cannot be undone.")
        }
        .alert("Restore Failed", isPresented: $showingRestoreError) {
            Button("OK") {}
        } message: {
            Text(restoreError)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Summary View
    
    private func summaryView(data: DeadlineCalendarBackupData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Backup Info
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "Created", value: formatDate(data.createdDate))
                        InfoRow(label: "Device", value: data.deviceName)
                        InfoRow(label: "Version", value: data.version)
                    }
                } label: {
                    Label("Backup Information", systemImage: "info.circle")
                }
                
                // Content Summary
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Projects")
                            Spacer()
                            Text("\(data.projects.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Templates")
                            Spacer()
                            Text("\(data.templates.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Triggers")
                            Spacer()
                            Text("\(data.triggers.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        let totalSubDeadlines = data.projects.reduce(0) { $0 + $1.subDeadlines.count }
                        HStack {
                            Text("Sub-deadlines")
                            Spacer()
                            Text("\(totalSubDeadlines)")
                                .foregroundColor(.secondary)
                        }
                        
                        let completedSubDeadlines = data.projects.reduce(0) { total, project in
                            total + project.subDeadlines.filter { $0.isCompleted }.count
                        }
                        HStack {
                            Text("Completed")
                            Spacer()
                            Text("\(completedSubDeadlines) of \(totalSubDeadlines)")
                                .foregroundColor(.secondary)
                        }
                    }
                } label: {
                    Label("Content Summary", systemImage: "doc.text")
                }
                
                // Settings Summary
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "Green Threshold", value: "\(data.appSettings.colorSettings.greenThreshold) days")
                        InfoRow(label: "Orange Threshold", value: "\(data.appSettings.colorSettings.orangeThreshold) days")
                        InfoRow(label: "Notification Title", value: data.appSettings.notificationFormatSettings.titleFormat)
                    }
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .padding()
        }
    }
    
    // MARK: - Projects View
    
    private func projectsView(data: DeadlineCalendarBackupData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(data.projects, id: \.id) { project in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(project.title)
                                    .font(.headline)
                                Spacer()
                                Text(formatDate(project.finalDeadlineDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let templateName = project.templateName {
                                Label(templateName, systemImage: "doc.plaintext")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            // Sub-deadlines
                            ForEach(project.subDeadlines.sorted(by: { $0.date < $1.date }), id: \.id) { subDeadline in
                                HStack {
                                    Image(systemName: subDeadline.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(subDeadline.isCompleted ? .green : .secondary)
                                        .imageScale(.small)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(subDeadline.title)
                                            .font(.subheadline)
                                            .strikethrough(subDeadline.isCompleted)
                                        
                                        Text(formatDate(subDeadline.date))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if !subDeadline.subtasks.isEmpty {
                                        Text("\(subDeadline.subtasks.filter { $0.isCompleted }.count)/\(subDeadline.subtasks.count)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            // Project triggers
                            let projectTriggers = data.triggers.filter { $0.projectID == project.id }
                            if !projectTriggers.isEmpty {
                                Divider()
                                
                                ForEach(projectTriggers, id: \.id) { trigger in
                                    HStack {
                                        Image(systemName: trigger.isActive ? "bell.fill" : "bell")
                                            .foregroundColor(trigger.isActive ? .purple : .secondary)
                                            .imageScale(.small)
                                        
                                        Text(trigger.name)
                                            .font(.caption)
                                            .foregroundColor(trigger.isActive ? .primary : .secondary)
                                        
                                        Spacer()
                                        
                                        if trigger.isActive, let date = trigger.activationDate {
                                            Text("Activated \(formatRelativeDate(date))")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                if data.projects.isEmpty {
                    Text("No projects in this backup")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Templates View
    
    private func templatesView(data: DeadlineCalendarBackupData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(data.templates, id: \.id) { template in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(template.name)
                                .font(.headline)
                            
                            if !template.subDeadlines.isEmpty {
                                Divider()
                                
                                Text("Sub-deadlines")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(template.subDeadlines, id: \.id) { subDeadline in
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.secondary)
                                            .imageScale(.small)
                                        
                                        Text(subDeadline.title)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        Text("\(subDeadline.offset.value) \(subDeadline.offset.unit.rawValue) before")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            if !template.templateTriggers.isEmpty {
                                Divider()
                                
                                Text("Triggers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(template.templateTriggers, id: \.id) { trigger in
                                    HStack {
                                        Image(systemName: "bell")
                                            .foregroundColor(.purple)
                                            .imageScale(.small)
                                        
                                        Text(trigger.name)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        Text("\(trigger.offset.value) \(trigger.offset.unit.rawValue) before")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                if data.templates.isEmpty {
                    Text("No templates in this backup")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadBackupData() {
        Task {
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    document.open { success in
                        if success {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: iCloudBackupError.backupRestorationFailed("Failed to open document"))
                        }
                    }
                }
                
                await MainActor.run {
                    self.backupData = document.backupData
                    self.isLoading = false
                }
            } catch {
                print("BackupDetailView: Failed to load backup: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func restoreBackup() {
        Task {
            do {
                try await backupManager.restoreFromBackup(document, to: viewModel)
                
                // Dismiss the view after successful restore
                await MainActor.run {
                    // The view will be dismissed by the parent
                }
            } catch {
                await MainActor.run {
                    restoreError = error.localizedDescription
                    showingRestoreError = true
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Info Row Component

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}