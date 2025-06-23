import SwiftUI

struct TemplateEditorView: View {
    // ViewModel for data operations
    @ObservedObject var viewModel: DeadlineViewModel
    // The template being edited, passed as a binding. Nil means create new.
    @Binding var templateToEdit: Template?
    // Environment variable to dismiss the view
    @Environment(\.dismiss) var dismiss

    // State for the template name being edited
    @State private var templateName: String = ""
    // State for the sub-deadlines being edited
    @State private var subDeadlines: [TemplateSubDeadline] = []
    
    // State to hold the original template data for comparison
    @State private var originalTemplateData: Template? = nil
    
    // State for managing the 'update projects?' alert
    @State private var showingUpdateAlert = false
    @State private var templateJustSaved: Template? = nil // To hold the template for the alert action

    // State for managing template triggers in the editor
    @State private var templateTriggers: [TemplateTrigger] = []
    @State private var showingAddTemplateTriggerAlert = false
    @State private var newTemplateTriggerName: String = ""
    
    // State for managing sub-deadline addition modal
    @State private var showingAddSubDeadlineModal = false
    @State private var newSubDeadlineTitle: String = ""
    @State private var newSubDeadlineOffset = TimeOffset(value: 7, unit: .days, before: true)
    @State private var newSubDeadlineTriggerID: UUID? = nil

    // Computed property to determine if editing an existing template
    private var isEditing: Bool {
        templateToEdit != nil
    }
    
    // Computed property for the navigation title
    private var editorTitle: String {
        isEditing ? "Edit Template" : "New Template"
    }
    
    // Computed property to check if the form is valid for saving
    private var isFormValid: Bool {
        !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // Add more validation if needed (e.g., at least one sub-deadline?)
    }
    
    // Computed property to get sorted sub-deadlines by calculated date
    private var sortedSubDeadlines: [TemplateSubDeadline] {
        let referenceDate = Date() // Use current date as reference for sorting
        return subDeadlines.sorted { first, second in
            let firstDate = (try? first.offset.calculateDate(from: referenceDate)) ?? referenceDate
            let secondDate = (try? second.offset.calculateDate(from: referenceDate)) ?? referenceDate
            return firstDate < secondDate
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // Section for Template Name
                Section("Template Name") {
                    TextField("Enter template name", text: $templateName)
                }

                // MARK: - Template Triggers  (now re-orderable)
                Section(
                    header: HStack {
                        Text("Template Triggers")
                        Spacer()
                        EditButton()                       // ← lives right here
                    }
                ) {
                    if templateTriggers.isEmpty {
                        Text("No triggers yet. Tap + to add one.")
                            .foregroundColor(.gray)
                    } else {
                        // Editable rows, drag-reorder enabled
                        ForEach($templateTriggers) { $trigger in
                            TextField("Trigger Name", text: $trigger.name)
                        }
                        .onDelete(perform: deleteTemplateTrigger)
                        .onMove { indices, newOffset in
                            templateTriggers.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }

                    // Add-new button (unchanged)
                    Button {
                        newTemplateTriggerName = ""
                        showingAddTemplateTriggerAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Template Trigger")
                        }
                    }
                    .buttonStyle(.borderless)
                }                       // keep the existing .alert(…) call immediately after this


                // Section for Sub-deadlines
                Section("Sub-deadlines") {
                    // --- List of Sub-deadlines ---
                    List {
                        ForEach($subDeadlines) { $subDeadline in
                            TemplateSubDeadlineEditorRow(
                                subDeadline: $subDeadline,
                                availableTemplateTriggers: $templateTriggers // Pass available triggers
                            )
                            .onChange(of: subDeadline.offset) { _ in
                                sortSubDeadlinesByDate()
                            }
                        }
                        .onDelete(perform: deleteSubDeadline)
                        // .onMove(perform: moveSubDeadline) // Optional: Reordering
                    }

                    // Button to add a new sub-deadline
                    Button {
                        // Reset modal fields
                        newSubDeadlineTitle = ""
                        newSubDeadlineOffset = TimeOffset(value: 7, unit: .days, before: true)
                        newSubDeadlineTriggerID = nil
                        showingAddSubDeadlineModal = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Sub-deadline Step")
                        }
                    }
                    .buttonStyle(.borderless) // Ensure button works correctly inside List
                }
            }
            .navigationTitle(editorTitle)
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
                        saveTemplate()
                        // Dismissal might be handled differently depending on alert outcome
                        // dismiss() // Let's remove dismiss() here for now, handle after save/alert
                    }
                    .disabled(!isFormValid) // Disable save if form is invalid
                }
                
            }
            .onAppear(perform: loadTemplateData) // Load data when the view appears
            .alert("Update Projects?", isPresented: $showingUpdateAlert, presenting: templateJustSaved) { savedTemplate in
                // Alert buttons
                Button("Update Projects") {
                    // Ensure we have the necessary data
                    guard let original = originalTemplateData else {
                        print("TemplateEditorView Error: Original template data missing for sync.")
                        dismiss() // Dismiss anyway or show error?
                        return
                    }
                    // Call new ViewModel function to update template AND sync projects
                    viewModel.updateTemplateAndSyncProjects(original: original, updated: savedTemplate)
                    dismiss() // Dismiss after initiating update and sync
                }
                Button("Just Save Template", role: .cancel) {
                    // Call the original ViewModel function to only update the template definition
                    viewModel.updateTemplate(savedTemplate)
                    dismiss() // Dismiss after saving just the template
                }
            } message: { savedTemplate in
                // Alert message
                Text("Do you want to update all projects created using the template '\\(savedTemplate.name)' with these changes?")
            }
            .preferredColorScheme(.dark) // Consistent theme
            .sheet(isPresented: $showingAddSubDeadlineModal) {
                NavigationView {
                    Form {
                        Section("Sub-deadline Details") {
                            TextField("Title", text: $newSubDeadlineTitle)
                            
                            // Offset configuration
                            HStack(spacing: 5) {
                                TextField("Value", value: $newSubDeadlineOffset.value, formatter: {
                                    let formatter = NumberFormatter()
                                    formatter.numberStyle = .decimal
                                    formatter.minimum = 1
                                    return formatter
                                }())
                                .frame(width: 50)
                                .keyboardType(.numberPad)
                                
                                Picker("Unit", selection: $newSubDeadlineOffset.unit) {
                                    ForEach(TimeOffsetUnit.allCases) { unit in
                                        Text(unit.rawValue.capitalized).tag(unit)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                Picker("Before/After", selection: $newSubDeadlineOffset.before) {
                                    Text("Before").tag(true)
                                    Text("After").tag(false)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 120)
                            }
                            
                            // Trigger selector
                            Picker("Requires Trigger", selection: $newSubDeadlineTriggerID) {
                                Text("None").tag(nil as UUID?)
                                ForEach(templateTriggers) { trigger in
                                    Text(trigger.name).tag(trigger.id as UUID?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .navigationTitle("New Sub-deadline")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingAddSubDeadlineModal = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Add") {
                                if !newSubDeadlineTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    let newSubDeadline = TemplateSubDeadline(
                                        title: newSubDeadlineTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                                        offset: newSubDeadlineOffset,
                                        templateTriggerID: newSubDeadlineTriggerID
                                    )
                                    subDeadlines.append(newSubDeadline)
                                    sortSubDeadlinesByDate()
                                    showingAddSubDeadlineModal = false
                                }
                            }
                            .disabled(newSubDeadlineTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .preferredColorScheme(.dark)
                }
            }
        }
    }

    // MARK: - Data Handling Functions

    // Load existing template data or set defaults for a new template
    private func loadTemplateData() {
        if let template = templateToEdit {
            // Editing existing: Load name and sub-deadlines
            templateName = template.name
            subDeadlines = template.subDeadlines
            templateTriggers = template.templateTriggers // <-- Load template triggers
            // Store a copy of the original data for diffing later
            originalTemplateData = template 
            sortSubDeadlinesByDate() // Sort sub-deadlines after loading
            print("TemplateEditorView: Loaded data for template: '\(template.name)' (\(templateTriggers.count) triggers).")
        } else {
            // Creating new: Set defaults
            templateName = ""
            subDeadlines = []
            templateTriggers = [] // <-- Default to empty triggers
            originalTemplateData = nil // Ensure original data is nil for new templates
            print("TemplateEditorView: Initializing for new template")
        }
    }

    // Add a new, default sub-deadline to the list
    private func addNewSubDeadline() {
        let newSubDeadline = TemplateSubDeadline() // Creates with default values
        subDeadlines.append(newSubDeadline)
        sortSubDeadlinesByDate()
        print("TemplateEditorView: Added new sub-deadline step.")
    }
    
    // Sort sub-deadlines by their calculated dates
    private func sortSubDeadlinesByDate() {
        let referenceDate = Date() // Use current date as reference for sorting
        subDeadlines.sort { first, second in
            let firstDate = (try? first.offset.calculateDate(from: referenceDate)) ?? referenceDate
            let secondDate = (try? second.offset.calculateDate(from: referenceDate)) ?? referenceDate
            return firstDate < secondDate
        }
    }

    // Delete sub-deadlines from the list
    private func deleteSubDeadline(at offsets: IndexSet) {
        subDeadlines.remove(atOffsets: offsets)
        print("TemplateEditorView: Deleted sub-deadline at offsets: \(offsets)")
    }
    
    // Delete template trigger definitions from the list
    private func deleteTemplateTrigger(at offsets: IndexSet) {
        let idsToDelete = offsets.map { templateTriggers[$0].id }
        // Before deleting the definition, check if any sub-deadline uses it
        let linkedSubDeadlines = subDeadlines.filter { idsToDelete.contains($0.templateTriggerID ?? UUID()) }
        if !linkedSubDeadlines.isEmpty {
            // Option 1: Prevent deletion (show alert)
            print("TemplateEditorView Warning: Cannot delete template trigger used by sub-deadlines: \(linkedSubDeadlines.map { $0.title })")
            // TODO: Show an alert to the user here.
            return // Stop deletion
            // Option 2: Unlink sub-deadlines first (maybe too aggressive)
            // for i in subDeadlines.indices {
            //     if idsToDelete.contains(subDeadlines[i].templateTriggerID ?? UUID()) {
            //         subDeadlines[i].templateTriggerID = nil
            //     }
            // }
        }
        // Proceed with deletion only if not linked (or after unlinking if chosen)
        templateTriggers.remove(atOffsets: offsets)
        print("TemplateEditorView: Removed template trigger definition at offsets: \(offsets).")
    }

    // Optional: Move sub-deadlines in the list
    // private func moveSubDeadline(from source: IndexSet, to destination: Int) {
    //     subDeadlines.move(fromOffsets: source, toOffset: destination)
    //     print("TemplateEditorView: Moved sub-deadline from \(source) to \(destination)")
    // }

    // Save the template (either update existing or add new)
    private func saveTemplate() {
        let trimmedName = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            print("TemplateEditorView: Save failed - Template name is empty.")
            return
        }
        
        if templateToEdit != nil { // Check if editing an existing template
            // Editing: Prepare data and trigger alert, DO NOT save yet.
            // Construct the updated template data from state variables
            let updatedTemplateData = Template(id: templateToEdit!.id, // Use original ID
                                               name: trimmedName, 
                                               subDeadlines: subDeadlines,
                                               templateTriggers: templateTriggers // <-- Include triggers
                                               )
            templateJustSaved = updatedTemplateData // Store the *proposed* updated template
            showingUpdateAlert = true         // Show the alert
        } else {
            // Creating: Create a new template object and add it via ViewModel
            let newTemplate = Template(name: trimmedName, 
                                       subDeadlines: subDeadlines,
                                       templateTriggers: templateTriggers // <-- Include triggers
                                       )
            viewModel.addTemplate(newTemplate)
            print("TemplateEditorView: Adding new template: \(newTemplate.name)")
            dismiss() // Dismiss immediately when creating a new template
        }
    }
}

// MARK: - Preview Provider
struct TemplateEditorView_Previews: PreviewProvider {
    // Create a State variable wrapper for the binding in the preview
    struct PreviewWrapper: View {
        @StateObject var viewModel = DeadlineViewModel.preview // Use preview instance
        @State var template: Template? = nil // Start with nil (New Template)
        @State var editingTemplate: Template? = Template.example // Start editing example

        var body: some View {
            VStack {
                // Preview for creating a new template
                TemplateEditorView(viewModel: viewModel, templateToEdit: $template)
                    .previewDisplayName("New Template")
                
                Divider()
                
                // Preview for editing an existing template
                TemplateEditorView(viewModel: viewModel, templateToEdit: $editingTemplate)
                    .previewDisplayName("Edit Template")
            }
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .preferredColorScheme(.dark)
    }
}

// Extension on DeadlineViewModel for preview data (if not already existing)
extension DeadlineViewModel {
    static var preview: DeadlineViewModel {
        let vm = DeadlineViewModel()
        // Ensure the example template exists for the edit preview
        if !vm.templates.contains(where: { $0.id == Template.example.id }) {
             vm.addTemplate(Template.example)
        }
         // Add another template if needed
         if vm.templates.count < 2 {
             vm.addTemplate(Template(name: "Another Template"))
         }
        return vm
    }
}

// --- Create/Modify TemplateSubDeadlineEditorRow --- 
// REMOVE THIS DUPLICATE DEFINITION - It exists in TemplateSubDeadlineEditorRow.swift
/*
struct TemplateSubDeadlineEditorRow: View {
    // ... (All the code for the struct we added here previously) ...
}
*/ 
