import SwiftUI

// Represents a single item in the AllDeadlinesView list
struct DeadlineListItem: Identifiable, Hashable {
    let id = UUID() // Unique ID for the list item itself
    let projectID: UUID
    let projectName: String
    let subDeadlineID: UUID
    let subDeadlineTitle: String
    let subDeadlineDate: Date
    let isSubDeadlineCompleted: Bool
    
    // We might also want to represent the Project's final deadline in this list.
    // We can add a flag or type for that if needed.
    // let isFinalDeadline: Bool = false 
}

// Add an Identifiable struct to hold the parameters for the sheet
struct EditSheetParameters: Identifiable {
    let id = UUID()
    let projectID: UUID
    let subDeadlineID: UUID?
}

struct AllDeadlinesView: View {
    // Observe the shared ViewModel
    @ObservedObject var viewModel: DeadlineViewModel
    
    // State to trigger navigation to project detail
    @State private var selectedProjectID: UUID?
    @State private var navigateToProject = false
    
    // Replace multiple state variables with a single one for the sheet
    @State private var editSheetParameters: EditSheetParameters?

    // --- NEW STATE ---
    // State variable to control the display format (days remaining vs. due date)
    @State private var showDueDate: Bool = false 
    // --- END NEW STATE ---

    // Computed property to generate the flat list of deadlines
    private var allDeadlinesSorted: [DeadlineListItem] {
        var items: [DeadlineListItem] = []
        
        // Iterate through each project
        for project in viewModel.projects {
            // Iterate through each sub-deadline within the project
            for subDeadline in project.subDeadlines {
                // *** Only include if NOT completed AND its trigger (if any) is active ***
                if !subDeadline.isCompleted && viewModel.isSubDeadlineActive(subDeadline) {
                    items.append(DeadlineListItem(
                        projectID: project.id,
                        projectName: project.title,
                        subDeadlineID: subDeadline.id,
                        subDeadlineTitle: subDeadline.title,
                        subDeadlineDate: subDeadline.date,
                        isSubDeadlineCompleted: subDeadline.isCompleted // Keep this property, even though we filter
                    ))
                }
            }
            
            // Optionally: Add the project's final deadline as an item too (if needed and not completed)
            // Consider if a Project itself can be "completed"
        }
        
        // Sort the combined list chronologically by date
        items.sort { $0.subDeadlineDate < $1.subDeadlineDate }
        
        return items
    }

    var body: some View {
        NavigationView {
            VStack {
                // List displaying all deadlines
                List {
                    ForEach(allDeadlinesSorted) { item in
                    HStack(spacing: 12) {
                            // Vertical Color Strip based on due date
                            Capsule()
                                .fill(stripColor(for: item.subDeadlineDate))
                                .frame(width: 5)

                            // Combined Project and Task Title
                            Text("\(item.projectName) \(item.subDeadlineTitle)")
                                .fontWeight(.medium)
                                .foregroundColor(dateColor(for: item.subDeadlineDate, isCompleted: item.isSubDeadlineCompleted))

                            Spacer()

                            // Days remaining or formatted due date
                            Text(showDueDate ? formattedDate(item.subDeadlineDate) : daysRemainingText(for: item.subDeadlineDate))
                                .font(.subheadline)
                                .foregroundColor(dateColor(for: item.subDeadlineDate, isCompleted: item.isSubDeadlineCompleted))
                                .lineLimit(1)
                                .frame(minWidth: 80, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button("View Project") {
                                selectedProjectID = item.projectID
                                navigateToProject = true
                            }
                            Button("Edit Deadline") {
                                // Set the parameters for the sheet
                                editSheetParameters = EditSheetParameters(
                                    projectID: item.projectID,
                                    subDeadlineID: item.subDeadlineID
                                )
                            }
                        }
                         
                         // --- Swipe Actions ---
                         .swipeActions(edge: .leading, allowsFullSwipe: true) {
                             Button {
                                 completeSubDeadlineAction(item: item)
                             } label: {
                                 Label("Complete", systemImage: "checkmark.circle.fill")
                             }
                             .tint(.green) // Set button color
                         }
                         .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                             Button(role: .destructive) {
                                 deleteSubDeadlineAction(item: item)
                             } label: {
                                 Label("Delete", systemImage: "trash.fill")
                             }
                         }
                         // --- End Swipe Actions ---
                    }
                }
                .listStyle(.plain) // Use plain list style
                
                // Hidden NavigationLink triggered by state change
                NavigationLink(
                    destination: projectDetailNavigationDestination(), 
                    isActive: $navigateToProject
                ) {
                    EmptyView()
                }
            }
            .navigationTitle("All Deadlines")
            .preferredColorScheme(.dark) // Keep consistent theme
            // --- NEW TOOLBAR ---
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDueDate.toggle()
                    } label: {
                        Text(showDueDate ? "Show Days Left" : "Show Due Date")
                    }
                }
            }
            // --- END NEW TOOLBAR ---
        }
        // Ensure NavigationViewStyle allows detail view to replace correctly on iPad/macOS if needed
        .navigationViewStyle(.stack) // Use stack style for phone-like navigation
        .sheet(item: $editSheetParameters) { params in
            ProjectEditorView(viewModel: viewModel,
                              projectToEditID: params.projectID,
                              scrollToSubDeadlineID: params.subDeadlineID)
        }
    }
    
    // Helper function to determine font weight based on date proximity and completion
    private func fontWeight(for date: Date, isCompleted: Bool) -> Font.Weight {
        if !isCompleted && Calendar.current.isDateInToday(date) {
            return .bold // Bold if due today and not done
        } else if !isCompleted && date < Calendar.current.startOfDay(for: Date()) {
             return .semibold // Semibold if overdue and not done
        }
        return .regular // Regular weight otherwise
    }
    
    // Helper function to determine text color based on date and completion
    private func dateColor(for date: Date, isCompleted: Bool) -> Color {
        if isCompleted {
            return .gray // Gray if completed
        } else if date < Calendar.current.startOfDay(for: Date()) {
            return .red // Red if overdue
        } else if Calendar.current.isDateInToday(date) {
            return .orange // Orange if due today
        }
        return .primary // Default color
    }
    
    // MARK: - Helper Functions for Row Appearance
    
    // Calculate days remaining until the deadline date
    private func daysRemaining(until date: Date) -> Int {
        // Use start of day for comparison to avoid time-of-day issues
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDeadlineDay = calendar.startOfDay(for: date)
        
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfDeadlineDay)
        return components.day ?? 0
    }
    
    // Determine the color for the vertical strip
    private func stripColor(for date: Date) -> Color {
        let days = daysRemaining(until: date)
        
        if days < 0 {
            return .red // Overdue is also red
        } else if days < 7 {
            return .red // Less than a week
        } else if days <= 21 {
            return .orange // 1 to 3 weeks
        } else {
            return .green // More than 3 weeks
        }
    }
    
    // Create the display text for days remaining
    private func daysRemainingText(for date: Date) -> String {
        let days = daysRemaining(until: date)
        
        if days < 0 {
            let dayString = abs(days) == 1 ? "day" : "days"
            return "\(abs(days)) \(dayString) overdue"
        } else if days == 0 {
            return "Due Today"
        } else if days == 1 {
            return "Tomorrow"
        } else {
            return "\(days) days"
        }
    }

    // --- NEW HELPER FUNCTION ---
    // Formats the date into a readable string (e.g., "Jun 23, 2024")
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy" // Example format, adjust as needed
        return formatter.string(from: date)
    }
    // --- END NEW HELPER FUNCTION ---
    
    // MARK: - Action Handlers
    
    // Action to mark a sub-deadline as complete
    private func completeSubDeadlineAction(item: DeadlineListItem) {
        // Find the project and sub-deadline in the ViewModel
        guard let projectIndex = viewModel.projects.firstIndex(where: { $0.id == item.projectID }),
              let subDeadlineIndex = viewModel.projects[projectIndex].subDeadlines.firstIndex(where: { $0.id == item.subDeadlineID }) else {
            print("AllDeadlinesView Error: Could not find project or sub-deadline to complete.")
            return
        }
        
        let project = viewModel.projects[projectIndex]
        let subDeadline = project.subDeadlines[subDeadlineIndex]
        
        print("AllDeadlinesView: Marking '\(subDeadline.title)' in project '\(project.title)' as complete.")
        viewModel.toggleSubDeadlineCompletion(subDeadline, in: project)
    }
    
    // Action to delete a sub-deadline
    private func deleteSubDeadlineAction(item: DeadlineListItem) {
        print("AllDeadlinesView: Deleting '\(item.subDeadlineTitle)' (ID: \(item.subDeadlineID)) from project '\(item.projectName)' (ID: \(item.projectID)).")
        // Call the new ViewModel function (needs to be created)
        viewModel.deleteSubDeadline(subDeadlineID: item.subDeadlineID, fromProjectID: item.projectID)
    }

    // Helper function to find the project for navigation
    @ViewBuilder
    private func projectDetailNavigationDestination() -> some View {
        if let projectID = selectedProjectID,
           let project = viewModel.projects.first(where: { $0.id == projectID }) {
            // Navigate to the existing ProjectDetailView
            ProjectDetailView(project: project, viewModel: viewModel)
        } else {
            // Fallback or error view if project not found (shouldn't happen ideally)
            Text("Error: Project not found.")
        }
    }
}

// MARK: - Preview Provider
struct AllDeadlinesView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a ViewModel instance with preview data
        let previewViewModel = DeadlineViewModel.preview // Assuming you have a preview setup
        
        // Add some sample projects with varying dates if needed
        if previewViewModel.projects.isEmpty {
             let sampleProject1 = Project(title: "Preview Project Alpha", finalDeadlineDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())!)
             // Add subdeadlines to sampleProject1...
             let sampleProject2 = Project(title: "Preview Project Beta", finalDeadlineDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!)
             // Add subdeadlines to sampleProject2...
             // previewViewModel.addProject(sampleProject1)
             // previewViewModel.addProject(sampleProject2)
             // previewViewModel.addProject(Project(title: "Due Today Project", finalDeadlineDate: Date())) // Example for today
        }
        
        return AllDeadlinesView(viewModel: previewViewModel)
             .preferredColorScheme(.dark)
    }
}

// Ensure DeadlineViewModel has a static preview instance
// extension DeadlineViewModel {
//    static var preview: DeadlineViewModel {
//        let vm = DeadlineViewModel()
        // Add sample projects and templates here for robust previewing
        // ...
//        return vm
//    }
// } 
