// Deadline Calendar/Deadline Calendar/CompletedProjectsView.swift
import SwiftUI

struct CompletedProjectsView: View {
    // ViewModel for accessing project data and actions
    @ObservedObject var viewModel: DeadlineViewModel
    // Environment variable to dismiss the view
    @Environment(\.dismiss) var dismiss

    // Filter completed projects from the ViewModel
    private var completedProjects: [Project] {
        viewModel.projects
            .filter { $0.isFullyCompleted }
            .sorted { $0.finalDeadlineDate > $1.finalDeadlineDate } // Sort newest completed first
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) { // Use zero spacing for consistency
                // Display a message if there are no completed projects
                if completedProjects.isEmpty {
                    VStack {
                        Spacer()
                        Text("No projects have been completed yet.")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.edgesIgnoringSafeArea(.all))
                } else {
                    // List the completed projects
                    List {
                        Section(header: Text("Completed Projects (") + Text("\(completedProjects.count)").bold() + Text(")")) { // Header with count
                            ForEach(completedProjects) { project in
                                // Use the ProjectRow for display consistency
                                ProjectRow(project: project)
                                    // Add swipe actions for completed projects
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) { // Mark as Active
                                        Button {
                                            markProjectAsActive(project: project)
                                        } label: {
                                            Label("Mark Active", systemImage: "arrow.uturn.backward.circle.fill")
                                        }
                                        .tint(.blue)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) { // Delete Permanently
                                        Button(role: .destructive) {
                                            deleteProjectPermanently(project: project)
                                        } label: {
                                            Label("Delete", systemImage: "trash.fill")
                                        }
                                    }
                            }
                            .listRowBackground(Color.black) // Match background
                        }
                    }
                    .listStyle(PlainListStyle()) // Consistent list style
                    .background(Color.black) // Ensure list background is black
                }
            }
            .navigationTitle("Completed Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Done button to dismiss the sheet
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(Color.black.edgesIgnoringSafeArea(.all)) // Set overall background
            .preferredColorScheme(.dark) // Enforce dark mode
        }
    }

    // MARK: - Action Functions

    // Action to permanently delete a completed project
    private func deleteProjectPermanently(project: Project) {
        print("CompletedProjectsView: Deleting project '\(project.title)' permanently.")
        viewModel.deleteProject(project)
        // The view will update automatically as viewModel.projects changes.
    }

    // Action to mark a completed project as active again
    // This requires modifying the project's sub-deadlines' completion status.
    private func markProjectAsActive(project: Project) {
        print("CompletedProjectsView: Marking project '\(project.title)' as active.")
        var updatedProject = project
        
        // Iterate through sub-deadlines and mark them as incomplete
        // This assumes marking active means resetting all sub-tasks.
        // Adjust logic if a different behavior is desired (e.g., keep completed tasks).
        for i in updatedProject.subDeadlines.indices {
            updatedProject.subDeadlines[i].isCompleted = false
        }
        
        // Now update the project in the ViewModel
        viewModel.updateProject(updatedProject)
        print("CompletedProjectsView: Project '\(updatedProject.title)' marked as active (all sub-deadlines reset). Updated via ViewModel.")
        
        // Optionally, dismiss the view after marking as active, or let the user stay
        // dismiss()
    }
}

// MARK: - Preview Provider
struct CompletedProjectsView_Previews: PreviewProvider {
    // Create a preview ViewModel with some completed projects
    static var previewViewModel: DeadlineViewModel = {
        let vm = DeadlineViewModel()
        // Clear existing default data if necessary for clean preview
        // vm.projects = []
        // vm.templates = []
        
        // Add sample active project
        let activeProj = ProjectRow_Previews.sampleProjectInProgress
        if !vm.projects.contains(where: { $0.id == activeProj.id }) {
             vm.addProject(activeProj)
        }
        
        // Add sample completed project
        var completedProj = ProjectRow_Previews.sampleProjectCompleted // Use the one from ProjectRow
        // Ensure all its sub-deadlines are actually marked completed for this preview
        for i in completedProj.subDeadlines.indices {
            completedProj.subDeadlines[i].isCompleted = true
        }
         if !vm.projects.contains(where: { $0.id == completedProj.id }) {
             vm.addProject(completedProj)
         }
        
        // Add another completed project for variety
        let finalDeadline3 = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let completedProj2 = Project(title: "Archived Task Set", finalDeadlineDate: finalDeadline3, subDeadlines: [
            SubDeadline(title: "Phase 1 Done", date: Calendar.current.date(byAdding: .day, value: -70, to: Date())!, isCompleted: true),
            SubDeadline(title: "Phase 2 Done", date: Calendar.current.date(byAdding: .day, value: -65, to: Date())!, isCompleted: true)
        ])
        if !vm.projects.contains(where: { $0.id == completedProj2.id }) {
            vm.addProject(completedProj2)
        }

        print("Preview ViewModel created with \(vm.projects.count) projects, \(vm.projects.filter { $0.isFullyCompleted }.count) completed.")
        return vm
    }()

    static var previews: some View {
        CompletedProjectsView(viewModel: previewViewModel)
            .preferredColorScheme(.dark)
    }
} 