// Deadline Calendar/Deadline Calendar/ProjectDetailView.swift
import SwiftUI

struct ProjectDetailView: View {
    // The project being displayed by this view
    // Using @State allows potential future modifications if needed within this view scope,
    // but primary updates will go through the ViewModel.
    @State var project: Project
    // ViewModel for accessing shared data and actions
    @ObservedObject var viewModel: DeadlineViewModel
    // Environment variable for dismissing the view (if presented modally/pushed)
    @Environment(\.dismiss) var dismiss
    // State to control the presentation of the project editor sheet
    @State private var showingEditSheet = false

    // Date formatter for displaying dates clearly
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium // e.g., "Oct 26, 2023"
        formatter.timeStyle = .none   // only date, no time
        return formatter
    }()

    var body: some View {
        List { // Using List for scrollability and sectioning
            // --- Project Header Section ---
            Section("Project Info") {
                HStack {
                    Text("Final Deadline:")
                        .font(.headline)
                    Spacer()
                    Text(project.finalDeadlineDate, formatter: dateFormatter)
                }
                // Display template name if available
                if let templateName = project.templateName {
                    HStack {
                        Text("Template:")
                            .font(.headline)
                        Spacer()
                        Text(templateName)
                            .foregroundColor(.gray)
                    }
                }
            }

            // --- Sub-deadlines Section ---
            Section("Sub-deadlines") {
                // Check if there are any sub-deadlines
                if project.subDeadlines.isEmpty {
                    Text("No sub-deadlines for this project.")
                        .foregroundColor(.gray)
                } else {
                    // Iterate through the sub-deadlines
                    // Need to use indices if we want to modify via ViewModel
                    ForEach(project.subDeadlines.indices, id: \.self) { index in
                        let subDeadline = project.subDeadlines[index]
                        VStack(alignment: .leading, spacing: 2) {
                            // Completion Toggle Button
                            Button {
                                // Find the actual index in the viewModel's array if necessary
                                // This assumes the passed `project` is up-to-date or we find it.
                                // A safer approach might be to pass the Project ID and SubDeadline ID
                                // to the ViewModel toggle function.
                                toggleCompletion(for: subDeadline)
                            } label: {
                                Image(systemName: subDeadline.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(subDeadline.isCompleted ? .green : .gray)
                            }
                            .buttonStyle(BorderlessButtonStyle()) // Allow interaction within the row

                            // Sub-deadline Details
                            VStack(alignment: .leading, spacing: 2) {
                                Text(subDeadline.title)
                                    .strikethrough(subDeadline.isCompleted, color: .gray)
                                HStack(spacing: 4) {
                                    Text(dateFormatter.string(from: subDeadline.date))
                                    if let original = originalDate(for: subDeadline), original != subDeadline.date {
                                        Text("(originally \(dateFormatter.string(from: original)))")
                                            .foregroundColor(.red)
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.gray)
                            }
                            Spacer() // Push content to the left
                        }
                    }
                }
            }
        }
        .navigationTitle(project.title) // Set navigation title to project title
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        // Add Toolbar for Edit button
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        // Sheet presentation for the editor
        .sheet(isPresented: $showingEditSheet, onDismiss: updateLocalProject) {
            ProjectEditorView(viewModel: viewModel,
                              projectToEditID: project.id)
        }
    }

    // MARK: - Actions

    // Toggles the completion status of a specific sub-deadline
    private func toggleCompletion(for subDeadline: SubDeadline) {
        print("ProjectDetailView: Toggling completion for sub-deadline '\(subDeadline.title)' in project '\(project.title)'")
        // Call the ViewModel function to handle the state update and persistence
        viewModel.toggleSubDeadlineCompletion(subDeadline, in: project)
        
        // Find the index of the sub-deadline within the local @State project
        // and manually update its completion state to reflect the change immediately in the UI.
        // This is necessary because the `project` state variable is a *copy* (struct)
        // and won't automatically update when the ViewModel changes the original data.
        // NOTE: An alternative would be to find the project in the ViewModel again after the toggle,
        // but updating the local state directly is often simpler for immediate UI feedback.
        if let index = project.subDeadlines.firstIndex(where: { $0.id == subDeadline.id }) {
            // Create a mutable copy of the sub-deadline to toggle its state
            // This toggles the state LOCALLY for instant UI update.
            // The ViewModel handles the actual data persistence.
            project.subDeadlines[index].isCompleted.toggle()
            // -------------------------------------------------------
            // Re-sort the subDeadlines array within the @State project variable AFTER toggling
            // to maintain consistent ordering if completion status affects sorting later.
            project.subDeadlines.sort { $0.date < $1.date } // Keep sorted by date
            // -------------------------------------------------------
            print("ProjectDetailView: Updated local project state for sub-deadline ID: \(subDeadline.id)")
        } else {
             print("ProjectDetailView: Error - Could not find sub-deadline ID \(subDeadline.id) in local project state after toggle.")
             // Consider reloading the project data from the view model if this happens frequently
             // Or ensure the project passed in is always the latest reference.
        }
    }
}

// MARK: - ProjectDetailView Helpers
extension ProjectDetailView {
    /// Refreshes the local project state after editing completes.
    private func updateLocalProject() {
        if let updated = viewModel.projects.first(where: { $0.id == project.id }) {
            project = updated
        }
    }

    /// Calculates the original template-based date for a sub-deadline, if defined.
    private func originalDate(for subDeadline: SubDeadline) -> Date? {
        guard let templateID = project.templateID,
              let template = viewModel.templates.first(where: { $0.id == templateID }),
              let templateSubID = subDeadline.templateSubDeadlineID,
              let templateDef = template.subDeadlines.first(where: { $0.id == templateSubID }) else {
            return nil
        }
        return try? templateDef.offset.calculateDate(from: project.finalDeadlineDate)
    }
}
// MARK: - Preview Provider
struct ProjectDetailView_Previews: PreviewProvider {
    // Helper function to create a sample project for previewing
    static func createSampleProject() -> Project {
        let finalDeadline = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let subDeadlineDate1 = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let subDeadlineDate2 = Calendar.current.date(byAdding: .day, value: 20, to: Date())!

        return Project(
            id: UUID(),
            title: "Sample App Preview Project",
            finalDeadlineDate: finalDeadline,
            subDeadlines: [
                SubDeadline(id: UUID(), title: "Design Mockups", date: subDeadlineDate1, isCompleted: true),
                SubDeadline(id: UUID(), title: "Development Phase 1", date: subDeadlineDate2, isCompleted: false)
            ],
            templateName: "Sample Template"
        )
    }

    // Create a static ViewModel instance for the preview
    static var previewViewModel: DeadlineViewModel = { // Use a computed static property
        let vm = DeadlineViewModel()
        // You might want to add the sample project to the ViewModel 
        // if the view relies on finding it within the ViewModel's data
        // vm.addProject(createSampleProject()) // Example if needed
        return vm
    }()

    static var previews: some View {
        NavigationView { // Embed in NavigationView for title display
            ProjectDetailView(
                project: createSampleProject(), // Use the sample project
                viewModel: previewViewModel    // Use the static preview ViewModel
            )
        }
        .preferredColorScheme(.dark)
    }
} 