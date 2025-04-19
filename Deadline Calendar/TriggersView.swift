import SwiftUI

// Represents an item in the TriggersView list, combining trigger and project info
struct TriggerListItem: Identifiable {
    let trigger: Trigger
    let projectName: String
    let projectFinalDeadline: Date // Needed for sorting

    var id: UUID { trigger.id } // Use trigger's ID
}

struct TriggersView: View {
    @ObservedObject var viewModel: DeadlineViewModel

    // Computed property to get inactive triggers, sorted by project deadline
    private var inactiveTriggersSorted: [TriggerListItem] {
        // Create a dictionary of project final deadlines for efficient lookup
        let projectDeadlines = Dictionary(uniqueKeysWithValues: viewModel.projects.map { ($0.id, $0.finalDeadlineDate) })

        return viewModel.triggers
            .filter { !$0.isActive } // Only show inactive triggers
            .compactMap { trigger -> TriggerListItem? in
                // Find the associated project name and deadline
                guard let project = viewModel.projects.first(where: { $0.id == trigger.projectID }) else {
                    print("TriggersView Warning: Could not find project (ID: \(trigger.projectID)) for trigger '\(trigger.name)' (ID: \(trigger.id)). Excluding from list.")
                    return nil // Exclude triggers whose projects are missing
                }
                return TriggerListItem(
                    trigger: trigger,
                    projectName: project.title,
                    projectFinalDeadline: project.finalDeadlineDate
                )
            }
            .sorted { $0.projectFinalDeadline < $1.projectFinalDeadline } // Sort by project deadline
    }

    var body: some View {
        NavigationView {
            List {
                if inactiveTriggersSorted.isEmpty {
                    Text("No pending triggers.")
                        .foregroundColor(.gray)
                        .padding(.vertical, 50)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.black) // Match theme
                } else {
                    ForEach(inactiveTriggersSorted) { item in
                        Button {
                            // Activate the trigger when the row is tapped
                            print("TriggersView: Activating trigger '\(item.trigger.name)'")
                            viewModel.activateTrigger(triggerID: item.trigger.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    // Combine Project Name and Trigger Name
                                    Text("\(item.projectName): \(item.trigger.name)") 
                                        .font(.headline)
                                }
                                Spacer()
                                Image(systemName: "play.circle") // Icon indicating activation action
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    // Optional: Add .onDelete for triggers if needed
                    // .onDelete(perform: deleteTriggerAction)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Pending Triggers")
            .background(Color.black.edgesIgnoringSafeArea(.all)) // Maintain theme
            .preferredColorScheme(.dark)
        }
        .navigationViewStyle(.stack) // Ensure correct navigation behavior
    }
    
    // Optional: Action to delete triggers from this view
//    private func deleteTriggerAction(at offsets: IndexSet) {
//        let triggersToDelete = offsets.map { inactiveTriggersSorted[$0].trigger }
//        for trigger in triggersToDelete {
//            print("TriggersView: Deleting trigger '\(trigger.name)'")
//            viewModel.deleteTrigger(triggerID: trigger.id)
//        }
//    }
}

// MARK: - Preview Provider
struct TriggersView_Previews: PreviewProvider {
    static var previews: some View {
        let previewViewModel = DeadlineViewModel.preview // Use existing preview setup

        // --- Preview Setup Logic ---
        // Ensure preview VM has projects
        if previewViewModel.projects.isEmpty {
             let sampleProject1 = Project(id: UUID(), title: "Preview Project A", finalDeadlineDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())!)
             let sampleProject2 = Project(id: UUID(), title: "Preview Project Z", finalDeadlineDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!)
             previewViewModel.addProject(sampleProject1)
             previewViewModel.addProject(sampleProject2)
        }
        
        // Clear existing triggers before adding preview ones to avoid duplicates across previews
        // This ensures a consistent state each time the preview runs.
        previewViewModel.triggers = []
        
        // Add sample triggers if projects exist
        if let project1 = previewViewModel.projects.first, let project2 = previewViewModel.projects.last {
             let trigger1 = Trigger(name: "Receive Assets", projectID: project1.id)
             let trigger2 = Trigger(name: "Client Approval", projectID: project1.id)
             let trigger3 = Trigger(name: "Await Feedback", projectID: project2.id)
             let trigger4 = Trigger(name: "Already Active Trigger", projectID: project1.id, isActive: true)
             previewViewModel.addTrigger(trigger1)
             previewViewModel.addTrigger(trigger2)
             previewViewModel.addTrigger(trigger3)
             previewViewModel.addTrigger(trigger4)
        }
        // --- End Preview Setup Logic ---

        // --- Return the View ---
        // Now that setup is complete, return the view to be previewed.
        // Wrap in AnyView to help compiler resolve the type.
        return AnyView(
            TriggersView(viewModel: previewViewModel)
                .preferredColorScheme(.dark)
        )
    }
} 