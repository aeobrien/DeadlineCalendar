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

    var body: some View {
        NavigationView {
            Form {
                // Section for Template Name
                Section("Template Name") {
                    TextField("Enter template name", text: $templateName)
                }

                // Section for Template Triggers
                Section("Template Triggers") {
                    List {
                        if templateTriggers.isEmpty {
                            Text("No triggers defined for this template.")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(templateTriggers) { triggerDef in
                                Text(triggerDef.name)
                            }
                            .onDelete(perform: deleteTemplateTrigger)
                        }
                    }
                    Button {
                        newTemplateTriggerName = "" // Clear before show
                        showingAddTemplateTriggerAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Template Trigger")
                        }
                    }
                    .buttonStyle(.borderless)
                }
                .alert("Add Template Trigger", isPresented: $showingAddTemplateTriggerAlert, actions: {
                    TextField("Trigger Definition Name", text: $newTemplateTriggerName)
                    
                    Button("Add", action: {
                        if !newTemplateTriggerName.isEmpty {
                            if !templateTriggers.contains(where: { $0.name.lowercased() == newTemplateTriggerName.lowercased() }) {
                                 let newTriggerDef = TemplateTrigger(name: newTemplateTriggerName)
                                 templateTriggers.append(newTriggerDef)
                                 newTemplateTriggerName = ""
                            } else {
                                 print("TemplateEditorView Warning: Template trigger name already exists.")
                                 // TODO: Show feedback alert
                            }
                        }
                    })
                    
                    Button("Cancel", role: .cancel, action: {
                        newTemplateTriggerName = "" 
                    })
                }, message: {
                    Text("Enter a name for the type of event that can trigger sub-deadlines (e.g., 'Assets Received', 'Client Approval').")
                })

                // Section for Sub-deadlines
                Section("Sub-deadlines") {
                    // --- List of Sub-deadlines ---
                    List {
                        ForEach($subDeadlines) { $subDeadline in
                            TemplateSubDeadlineEditorRow(
                                subDeadline: $subDeadline,
                                availableTemplateTriggers: $templateTriggers // Pass available triggers
                            )
                        }
                        .onDelete(perform: deleteSubDeadline)
                        // .onMove(perform: moveSubDeadline) // Optional: Reordering
                    }

                    // Button to add a new sub-deadline
                    Button {
                        addNewSubDeadline()
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
        print("TemplateEditorView: Added new sub-deadline step.")
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