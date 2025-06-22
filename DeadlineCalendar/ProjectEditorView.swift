import SwiftUI

// View for editing an existing Project
struct ProjectEditorView: View {
    @ObservedObject var viewModel: DeadlineViewModel
    let projectToEditID: UUID // ID of the project being edited
    /// Optional sub-deadline ID to scroll to when the editor appears.
    let scrollToSubDeadlineID: UUID?

    @Environment(\.dismiss) var dismiss

    // State for editable properties
    @State private var projectTitle: String
    @State private var finalDeadlineDate: Date
    @State private var subDeadlines: [SubDeadline]
    
    // Internal state to hold the original project data once loaded
    @State private var originalProject: Project?
    
    // State for creating a trigger from the dedicated section
    @State private var showingAddTriggerAlert = false
    @State private var newTriggerSectionName: String = ""
    
    init(viewModel: DeadlineViewModel, projectToEditID: UUID, scrollToSubDeadlineID: UUID? = nil) {
        self.viewModel = viewModel
        self.projectToEditID = projectToEditID
        self.scrollToSubDeadlineID = scrollToSubDeadlineID

        // Find the project and initialize state here
        if let project = viewModel.projects.first(where: { $0.id == projectToEditID }) {
            _projectTitle = State(initialValue: project.title)
            _finalDeadlineDate = State(initialValue: project.finalDeadlineDate)
            _subDeadlines = State(initialValue: project.subDeadlines)
            _originalProject = State(initialValue: project)
        } else {
            // Fallback for when project is not found. The view will dismiss on appear.
            _projectTitle = State(initialValue: "")
            _finalDeadlineDate = State(initialValue: Date())
            _subDeadlines = State(initialValue: [])
            _originalProject = State(initialValue: nil)
            print("ProjectEditorView Error: Project with ID \(projectToEditID) not found during init.")
        }
    }
    
    // Computed property to check if the form is valid
    private var isFormValid: Bool {
        !projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // Add other validation if needed
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                Form {
                    // Section for Project Details
                    Section("Project Details") {
                        TextField("Project Title", text: $projectTitle)
                        DatePicker("Final Deadline", selection: $finalDeadlineDate, displayedComponents: .date)
                    }

                    // --- Section for Managing Project Triggers ---
                    Section("Project Triggers") {
                        // List existing triggers for this project
                        let projectTriggers = viewModel.triggers(for: projectToEditID)
                        if projectTriggers.isEmpty {
                            Text("No triggers defined for this project yet.")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(projectTriggers) { trigger in
                                HStack {
                                    Text(trigger.name)
                                    Spacer()
                                    // Show status (optional)
                                    if trigger.isActive {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    } else {
                                         Image(systemName: "circle")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .onDelete(perform: deleteTriggerInSection)
                        }

                        // Button to add a new trigger directly
                        Button {
                            newTriggerSectionName = "" // Clear field before showing
                            showingAddTriggerAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add New Trigger")
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                    // Alert for adding trigger from the dedicated section
                    .alert("Add Project Trigger", isPresented: $showingAddTriggerAlert, actions: {
                        TextField("Trigger Name", text: $newTriggerSectionName)
                        Button("Add") {
                            if !newTriggerSectionName.isEmpty {
                                let newTrigger = Trigger(name: newTriggerSectionName, projectID: projectToEditID)
                                viewModel.addTrigger(newTrigger)
                                newTriggerSectionName = "" // Reset
                            } // else: Handle empty name?
                        }
                        Button("Cancel", role: .cancel) { newTriggerSectionName = "" }
                    }, message: {
                         Text("Enter the name for the new trigger needed by this project.")
                    })

                    // Section for Sub-deadlines
                    Section("Sub-deadlines") {
                        // The List is now directly inside the section.
                        List {
                            ForEach($subDeadlines) { $subDeadline in
                                EditableSubDeadlineRow(subDeadline: $subDeadline,
                                                        viewModel: viewModel,
                                                        projectID: projectToEditID)
                                    .id(subDeadline.id) // The ID for the ScrollViewReader
                            }
                            .onDelete(perform: deleteSubDeadline)
                        }
                        
                        // Button to add a new sub-deadline manually
                        Button {
                            addNewSubDeadline()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Manual Sub-deadline")
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .navigationTitle("Edit Project")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Cancel Button
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    // Save Button
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveProjectChanges()
                            dismiss()
                        }
                        .disabled(!isFormValid)
                    }
                }
                .onAppear {
                    // Handle initial setup and scrolling here
                    if self.originalProject == nil {
                        print("ProjectEditorView: Dismissing on appear because original project was not found on init.")
                        dismiss()
                        return // Early exit
                    }
                    
                    // Scroll to the target sub-deadline if an ID was provided
                    if let targetID = scrollToSubDeadlineID {
                        // Use a slight delay to ensure the list has rendered its rows
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(targetID, anchor: .top)
                            }
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - Data Handling

    private func addNewSubDeadline() {
        // Create a new SubDeadline instance. 
        // Since it's added manually, it won't have a templateSubDeadlineID.
        // Default its date relative to the final deadline? Or just today?
        let defaultDate = Calendar.current.date(byAdding: .day, value: -7, to: finalDeadlineDate) ?? Date()
        let newSub = SubDeadline(title: "New Manual Step", date: defaultDate, templateSubDeadlineID: nil) 
        subDeadlines.append(newSub)
        subDeadlines.sort { $0.date < $1.date } // Keep sorted
        print("ProjectEditorView: Added new manual sub-deadline.")
    }

    private func deleteSubDeadline(at offsets: IndexSet) {
        // Simply remove from the local state array. Changes saved on overall save.
        subDeadlines.remove(atOffsets: offsets)
        print("ProjectEditorView: Removed sub-deadline at offsets: \(offsets).")
    }

    // --- Action Handlers for Trigger Section ---

    private func deleteTriggerInSection(at offsets: IndexSet) {
        // Get the actual triggers for the current project to map offsets correctly
        let projectTriggers = viewModel.triggers(for: projectToEditID)
        // Get the IDs of the triggers to delete based on the IndexSet
        let triggersToDelete = offsets.map { projectTriggers[$0] }

        for trigger in triggersToDelete {
            print("ProjectEditorView: Deleting trigger '\(trigger.name)' via section delete.")
            // Call the ViewModel function to delete the trigger
            // This will also handle unlinking from any sub-deadlines
            viewModel.deleteTrigger(triggerID: trigger.id)
        }
    }

    private func saveProjectChanges() {
        guard var projectToUpdate = originalProject else {
            print("ProjectEditorView Error: Original project data not loaded. Cannot save.")
            return
        }
        
        // Update the project object with data from the state variables
        projectToUpdate.title = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        projectToUpdate.finalDeadlineDate = finalDeadlineDate
        // Sort subdeadlines before saving, just in case
        projectToUpdate.subDeadlines = subDeadlines.sorted { $0.date < $1.date }
        
        // Recalculate dates for template-linked subdeadlines if the final deadline changed
        if projectToUpdate.finalDeadlineDate != originalProject?.finalDeadlineDate {
             print("ProjectEditorView: Final deadline changed. Recalculating template-linked sub-deadline dates...")
             // We need access to the original template data for the offsets.
             if let templateID = projectToUpdate.templateID,
                let template = viewModel.templates.first(where: { $0.id == templateID }) {
                 
                 let templateSubDeadlinesByID = Dictionary(uniqueKeysWithValues: template.subDeadlines.map { ($0.id, $0) })
                 
                 for i in projectToUpdate.subDeadlines.indices {
                     if let templateSubID = projectToUpdate.subDeadlines[i].templateSubDeadlineID,
                        let templateSub = templateSubDeadlinesByID[templateSubID] {
                         do {
                             let newDate = try templateSub.offset.calculateDate(from: projectToUpdate.finalDeadlineDate)
                             if projectToUpdate.subDeadlines[i].date != newDate {
                                 print("  - Recalculating date for '\(projectToUpdate.subDeadlines[i].title)' to \(newDate)")
                                 projectToUpdate.subDeadlines[i].date = newDate
                             }
                         } catch {
                             print("  - Error recalculating date for '\(projectToUpdate.subDeadlines[i].title)': \(error)")
                         }
                     }
                 }
                 // Re-sort again after potential date changes
                 projectToUpdate.subDeadlines.sort { $0.date < $1.date }
             } else {
                 print("ProjectEditorView Warning: Could not find template data to recalculate dates.")
             }
        }

        // Call the ViewModel's update function
        print("ProjectEditorView: Saving changes for project '\(projectToUpdate.title)'.")
        viewModel.updateProject(projectToUpdate)
    }
}

// MARK: - Editable Sub-Deadline Row
// A helper view for editing a SubDeadline within the ProjectEditorView list
struct EditableSubDeadlineRow: View {
    @Binding var subDeadline: SubDeadline
    @ObservedObject var viewModel: DeadlineViewModel
    let projectID: UUID

    // State for potentially showing a trigger creation sheet/alert
    @State private var showingCreateTriggerAlert = false
    @State private var newTriggerName: String = ""
    
    // Define a constant dummy UUID for the "Create New" option
    static let createNewTriggerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    // Computed property for available triggers for THIS project
    private var availableTriggers: [Trigger] {
        viewModel.triggers(for: projectID)
    }

    var body: some View {
        VStack(alignment: .leading) { // Use VStack to stack controls
            HStack {
                // Editable Title
                TextField("Sub-deadline Title", text: $subDeadline.title)
                    .strikethrough(subDeadline.isCompleted, color: .gray)
            
                Spacer()
            
                // Editable Date
                DatePicker("", selection: $subDeadline.date, displayedComponents: .date)
                    .labelsHidden() // Hide the default DatePicker label
            
                // Completion Toggle
                Button {
                    subDeadline.isCompleted.toggle()
                } label: {
                    Image(systemName: subDeadline.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(subDeadline.isCompleted ? .green : .gray)
                }
                .buttonStyle(.borderless)
            }

            // --- Trigger Selector ---
            HStack {
                Text("Requires Trigger:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Picker("Trigger", selection: $subDeadline.triggerID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(availableTriggers) { trigger in
                        Text(trigger.name).tag(trigger.id as UUID?)
                    }
                     // Add option to create a new trigger - Use the constant ID
                    Text("Create New Trigger...").tag(Self.createNewTriggerID as UUID?)
                }
                .pickerStyle(.menu)
                .font(.caption)
                .onChange(of: subDeadline.triggerID) { selectedID in
                    // Check if the "Create New" dummy ID was selected
                    if selectedID == Self.createNewTriggerID {
                        // Show the alert. We don't need complex revert logic here anymore.
                        // Clear the temp trigger name before showing
                        newTriggerName = ""
                        showingCreateTriggerAlert = true
                    }
                }
            }
            // Alert for creating a new trigger
            .alert("New Trigger", isPresented: $showingCreateTriggerAlert, actions: {
                TextField("Trigger Name (e.g., Assets Received)", text: $newTriggerName)
                Button("Create & Link") {
                    if !newTriggerName.isEmpty {
                        let newTrigger = Trigger(name: newTriggerName, projectID: projectID)
                        viewModel.addTrigger(newTrigger)
                        // Link the new trigger immediately after creation
                        subDeadline.triggerID = newTrigger.id
                        newTriggerName = "" // Reset field
                    } else {
                         // Handle empty name? Maybe disable button or show feedback.
                    }
                }
                Button("Cancel", role: .cancel) {
                    // If cancelled, reset the selection back to "None"
                    if subDeadline.triggerID == Self.createNewTriggerID {
                         // Reset the picker selection explicitly to None
                        subDeadline.triggerID = nil
                    }
                    newTriggerName = ""
                 }
            }, message: {
                Text("Enter the name for the new trigger for this project.")
            })
            // --- End Trigger Selector ---
        }
        // Add identifier if needed for ForEach stability, although UUID should be stable
        // .id(subDeadline.id) 
    }
}

// MARK: - Preview Provider
struct ProjectEditorView_Previews: PreviewProvider {
    static var previews: some View { // Return type remains `some View`
        // Need a ViewModel with a sample project for the preview
        let previewViewModel = DeadlineViewModel.preview // Use existing preview VM
        
        // --- Setup Logic ---
        // Ensure there's a project to edit in the preview VM by adding one if needed.
        // This modification happens *before* the view is returned.
        if previewViewModel.projects.isEmpty {
            let finalDeadline = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
             let subDeadlineDate1 = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
             let subDeadlineDate2 = Calendar.current.date(byAdding: .day, value: 20, to: Date())!
            let sampleProject = Project(
                 id: UUID(),
                 title: "Sample Edit Project",
                 finalDeadlineDate: finalDeadline,
                 subDeadlines: [
                     SubDeadline(id: UUID(), title: "Editable Design", date: subDeadlineDate1, isCompleted: true, templateSubDeadlineID: UUID()), // Add dummy template ID
                     SubDeadline(id: UUID(), title: "Editable Dev", date: subDeadlineDate2, isCompleted: false)
                 ],
                 templateID: UUID() // Add dummy template ID
             )
             previewViewModel.addProject(sampleProject) // Modify the VM instance
        }
        // --- End Setup Logic ---

        // Safely get the ID of the first project for the preview
        guard let projectIDToEdit = previewViewModel.projects.first?.id else {
             // Return a fallback view if no project exists, wrapped in AnyView
             return AnyView(
                 Text("Error: No project found for preview.")
                    .preferredColorScheme(.dark)
            )
        }

        // --- Return the View ---
        // Return the actual view to be previewed, wrapped in AnyView
         return AnyView(
             ProjectEditorView(viewModel: previewViewModel, projectToEditID: projectIDToEdit)
                 .preferredColorScheme(.dark)
         )
    }
} 