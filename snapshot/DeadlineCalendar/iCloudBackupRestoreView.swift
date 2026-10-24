// Deadline Calendar/DeadlineCalendar/iCloudBackupRestoreView.swift

import SwiftUI

struct iCloudBackupRestoreView: View {
    @ObservedObject var viewModel: DeadlineViewModel
    @StateObject private var backupManager = iCloudBackupManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCreateBackupAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var documentToDelete: DeadlineCalendarBackupDocument?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedBackup: DeadlineCalendarBackupDocument?
    @State private var showingBackupDetail = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // iCloud Status Section
                    statusSection
                    
                    // Actions Section
                    actionsSection
                    
                    // Available Backups Section
                    availableBackupsSection
                    
                    // Information Section
                    informationSection
                }
                .padding()
            }
            .navigationTitle("iCloud Backup")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await backupManager.loadAvailableBackups()
            }
            .refreshable {
                await backupManager.loadAvailableBackups()
            }
            .alert("Create Backup", isPresented: $showingCreateBackupAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    createBackup()
                }
            } message: {
                Text("This will create a backup of all your projects, templates, and settings in iCloud.")
            }
            .alert("Delete Backup", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let document = documentToDelete {
                        deleteBackup(document)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this backup? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .sheet(item: $selectedBackup) { document in
                NavigationView {
                    BackupDetailView(document: document, viewModel: viewModel)
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Sections
    
    private var statusSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("iCloud Status", systemImage: "cloud")
                        .font(.headline)
                    Spacer()
                    if backupManager.iCloudAvailable {
                        Label("Available", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    } else {
                        Label("Not Available", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
                
                if !backupManager.iCloudAvailable {
                    Text("Please sign in to iCloud and enable iCloud Drive in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let lastBackupDate = backupManager.lastBackupDate {
                    HStack {
                        Text("Last Backup")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatRelativeDate(lastBackupDate))
                            .font(.subheadline)
                    }
                }
            }
        }
    }
    
    private var actionsSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                Button(action: {
                    showingCreateBackupAlert = true
                }) {
                    HStack {
                        Label("Create Backup Now", systemImage: "arrow.up.doc")
                        Spacer()
                        if backupManager.isCreatingBackup {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.primary)
                .disabled(!backupManager.iCloudAvailable || backupManager.isCreatingBackup)
                
                if !backupManager.iCloudAvailable {
                    Text("iCloud must be available to create backups")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var availableBackupsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Available Backups", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                    Spacer()
                    if backupManager.isLoadingBackups {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                if backupManager.availableBackups.isEmpty {
                    Text("No backups found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(backupManager.availableBackups, id: \.fileURL) { document in
                        BackupRow(document: document) {
                            selectedBackup = document
                        } onRestore: {
                            restoreBackup(document)
                        } onDelete: {
                            documentToDelete = document
                            showingDeleteConfirmation = true
                        }
                        
                        if document != backupManager.availableBackups.last {
                            Divider()
                        }
                    }
                }
            }
        }
    }
    
    private var informationSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("About iCloud Backups", systemImage: "info.circle")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Text("• Backups are stored in your personal iCloud Drive")
                    .font(.caption)
                
                Text("• Backups include all projects, templates, triggers, and settings")
                    .font(.caption)
                
                Text("• Backups are available across all your devices signed into the same iCloud account")
                    .font(.caption)
                
                Text("• Automatic backups are created daily when you open the app")
                    .font(.caption)
                
                Text("• This complements the existing clipboard export/import functionality")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private func createBackup() {
        Task {
            do {
                try await backupManager.createBackup(
                    projects: viewModel.projects,
                    templates: viewModel.templates,
                    triggers: viewModel.triggers,
                    appSettings: viewModel.appSettings
                )
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func restoreBackup(_ document: DeadlineCalendarBackupDocument) {
        Task {
            do {
                try await backupManager.restoreFromBackup(document, to: viewModel)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func deleteBackup(_ document: DeadlineCalendarBackupDocument) {
        Task {
            do {
                try await backupManager.deleteBackup(document)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Backup Row Component

private struct BackupRow: View {
    let document: DeadlineCalendarBackupDocument
    let onTap: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    @State private var metadata: BackupMetadata?
    @State private var isLoadingMetadata = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingMetadata {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
                .frame(height: 60)
            } else if let metadata = metadata {
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metadata.deviceName)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Text(metadata.formattedCreationDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(metadata.formattedFileSize)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Quick actions
                HStack(spacing: 16) {
                    Button(action: onRestore) {
                        Label("Restore", systemImage: "arrow.down.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    
                    Spacer()
                    
                    Button(action: onDelete) {
                        Label("Delete", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadMetadata()
        }
        .contextMenu {
            Button(action: onRestore) {
                Label("Restore Backup", systemImage: "arrow.down.doc")
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete Backup", systemImage: "trash")
            }
        }
    }
    
    private func loadMetadata() async {
        do {
            print("BackupRow: Loading metadata for \(document.fileURL.lastPathComponent)")
            metadata = try await document.getMetadata()
            isLoadingMetadata = false
            print("BackupRow: Successfully loaded metadata")
        } catch {
            print("BackupRow: Failed to load metadata for \(document.fileURL.path)")
            print("BackupRow: Error: \(error)")
            
            // Create fallback metadata from filename
            let filename = document.fileURL.lastPathComponent
            let fallbackMetadata = BackupMetadata(
                filename: filename,
                creationDate: Date(),
                deviceName: UIDevice.current.name,
                fileSize: 0,
                fileURL: document.fileURL
            )
            
            metadata = fallbackMetadata
            isLoadingMetadata = false
        }
    }
}