// Deadline Calendar/Deadline Calendar/BackupRestoreView.swift

import SwiftUI

struct BackupRestoreView: View {
    // Access the shared ViewModel
    @ObservedObject var viewModel: DeadlineViewModel
    
    // State for showing alerts
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
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

                Spacer() // Push content to the top
            }
            .padding() // Padding around the main VStack
            .navigationTitle("Backup & Restore")
            .preferredColorScheme(.dark) // Maintain dark mode
            .alert(isPresented: $showingAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
        .navigationViewStyle(.stack) // Use stack style
    }

    // MARK: - Actions

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