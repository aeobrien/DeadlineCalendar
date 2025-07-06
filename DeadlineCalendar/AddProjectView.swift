import SwiftUI

struct AddProjectView: View {
    // Environment variable to dismiss the view.
    @Environment(\.dismiss) var dismiss
    // The shared view model for accessing templates and adding projects.
    @ObservedObject var viewModel: DeadlineViewModel

    // State variables for the form inputs.
    @State private var projectTitle: String = ""
    // Default to one month from now for the final deadline.
    @State private var finalDeadlineDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    // State to hold the ID of the selected template. Changed to allow "No Template" option.
    @State private var selectedTemplateID: UUID? = nil // nil = No template / Manual
    
    // NEW State: Stores the sub-deadlines for the current project being configured.
    // This will be populated either from a template or added manually.
    @State private var projectSubDeadlines: [SubDeadline] = []
    
    // NEW State: Track whether to use a template or add manually
    @State private var useTemplate: Bool = true // Default to using a template
    
    // Date formatter for sub-deadline rows
    private let subDeadlineDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    // Computed property to check if the form is valid for saving.
    private var isFormValid: Bool {
        // Title must not be empty.
        // If using template, template must be selected (though we can auto-select).
        // If adding manually, it's valid even with 0 sub-deadlines initially.
        !projectTitle.trimmingCharacters(in: .whitespaces).isEmpty
        // Consider adding: && (useTemplate ? selectedTemplateID != nil : true)
        // For simplicity, just ensuring title is non-empty is often sufficient.
    }

    var body: some View {
        NavigationView {
            Form {
                // Section for basic project details.
                Section(header: Text("Project Details").foregroundColor(.gray)) {
                    TextField("Project Title (e.g., October Video)", text: $projectTitle)
                    
                    DatePicker("Final Deadline Date",
                               selection: $finalDeadlineDate,
                               displayedComponents: .date)
                        .datePickerStyle(.graphical) // Use graphical for better date picking experience
                        .onChange(of: finalDeadlineDate) { _ in
                            // Recalculate sub-deadlines if using a template when the date changes
                            if useTemplate, let template = selectedTemplate {
                                updateSubDeadlinesFromTemplate(template: template)
                            }
                        }
                }
                
                // Section for selecting a template OR choosing manual mode
                Section(header: Text("Sub-deadline Source").foregroundColor(.gray)) {
                    Toggle("Use Template", isOn: $useTemplate.animation()) // Add animation
                    
                    // Show template picker only if 'Use Template' is toggled on
                    if useTemplate {
                        // Check if templates are available.
                        if viewModel.templates.isEmpty {
                            Text("No templates available. Create one in Template Manager or toggle off 'Use Template'.")
                                .foregroundColor(.orange)
                        } else {
                            // Picker to select a template.
                            Picker("Template", selection: $selectedTemplateID) {
                                // Default "None" option - should not be selectable if useTemplate is true?
                                // Text("Select a Template...").tag(nil as UUID?)
                                
                                // Iterate over available templates.
                                ForEach(viewModel.templates) { template in
                                    Text(template.name).tag(template.id as UUID?)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedTemplateID) { newTemplateID in
                                // Update sub-deadlines when template selection changes
                                if let template = selectedTemplate {
                                    updateSubDeadlinesFromTemplate(template: template)
                                } else {
                                    // Handle case where selection goes back to nil (if possible)
                                    projectSubDeadlines = []
                                }
                            }
                        }
                    }
                }
                
                // --- Section for Template Triggers (Read-only preview) ---
                if useTemplate, let template = selectedTemplate, !template.templateTriggers.isEmpty {
                    Section(header: Text("Triggers").foregroundColor(.gray)) {
                        ForEach(template.templateTriggers) { trigger in
                            HStack {
                                Text(trigger.name)
                                Spacer()
                                // Show when the trigger will be due
                                if let calculatedDate = try? trigger.offset.calculateDate(from: finalDeadlineDate) {
                                    Text(calculatedDate, formatter: subDeadlineDateFormatter)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Invalid date")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                
                // --- Section for Managing Sub-Deadlines (Editable) ---
                Section(header: Text(useTemplate ? "Derived Sub-Deadlines" : "Manual Sub-Deadlines").foregroundColor(.gray)) {
                    // List the editable sub-deadlines
                    List {
                        // Use the simple display row, not the editable one
                        ForEach(projectSubDeadlines) { subDeadline in // Iterate over immutable array
                            // Editable Row for SubDeadline - Remove dateFormatter argument
                            AddProjectSubDeadlineRow(subDeadline: subDeadline)
                        }
                        .onDelete(perform: deleteSubDeadline)
                        // Add .onMove if reordering is desired
                    }

                    // Button to add a new sub-deadline manually
                    Button {
                        addNewSubDeadline()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Sub-deadline Step")
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
            // Set the navigation bar title.
            .navigationTitle("Add New Project")
            .navigationBarTitleDisplayMode(.inline)
            // Add toolbar items for Cancel and Save buttons.
            .toolbar {
                // Leading item: Cancel button.
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        print("AddProjectView: Cancel button tapped.")
                        dismiss() // Dismiss the view without saving.
                    }
                }
                // Trailing item: Save button.
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        print("AddProjectView: Save button tapped.")
                        saveProject() // Call the modified save function.
                        dismiss() // Dismiss the view after saving.
                    }
                    // Disable the Save button if the form is not valid.
                    .disabled(!isFormValid)
                }
            }
            // Initial setup when the view appears
            .onAppear {
                setupInitialState()
            }
            // React to changes in the useTemplate toggle
            .onChange(of: useTemplate) { useTpl in
                if useTpl {
                    // Switched TO template mode: try selecting first template and generating subs
                    if selectedTemplateID == nil, let firstTemplate = viewModel.templates.first {
                        selectedTemplateID = firstTemplate.id
                        updateSubDeadlinesFromTemplate(template: firstTemplate)
                    } else if let currentTemplate = selectedTemplate {
                         updateSubDeadlinesFromTemplate(template: currentTemplate)
                    } else {
                        projectSubDeadlines = [] // No template selected/available
                    }
                } else {
                    // Switched TO manual mode: clear template selection and existing subs
                    selectedTemplateID = nil
                    projectSubDeadlines = [] // Start fresh for manual entry
                }
            }
        }
        // Apply dark color scheme consistent with the rest of the app
        .preferredColorScheme(.dark)
    }

    // --- Helper Functions ---
    
    // Finds the selected Template object based on the selectedTemplateID.
    private var selectedTemplate: Template? {
        guard useTemplate, let id = selectedTemplateID else { return nil }
        return viewModel.templates.first { $0.id == id }
    }
    
    // Initial setup on view appear
    private func setupInitialState() {
        // Default to using template if templates exist
        useTemplate = !viewModel.templates.isEmpty
        
        if useTemplate, let firstTemplate = viewModel.templates.first {
            selectedTemplateID = firstTemplate.id
            updateSubDeadlinesFromTemplate(template: firstTemplate)
        } else {
            // No templates, or user previously chose manual: start manual
            useTemplate = false
            selectedTemplateID = nil
            projectSubDeadlines = []
        }
    }

    // Updates the projectSubDeadlines state based on the selected template and date
    private func updateSubDeadlinesFromTemplate(template: Template) {
        print("AddProjectView: Updating sub-deadlines from template '\(template.name)' for date \(finalDeadlineDate)")
        var calculatedSubDeadlines: [SubDeadline] = []
        for templateSub in template.subDeadlines {
            do {
                let calculatedDate = try templateSub.offset.calculateDate(from: finalDeadlineDate)
                let newSubDeadline = SubDeadline(
                    title: templateSub.title,
                    date: calculatedDate,
                    templateSubDeadlineID: templateSub.id
                )
                calculatedSubDeadlines.append(newSubDeadline)
            } catch {
                print("AddProjectView Error: Failed to calculate date for sub-deadline '\(templateSub.title)'. Error: \(error.localizedDescription)")
                // Skip this sub-deadline if calculation fails
            }
        }
        // Update the state variable, sorting chronologically
        projectSubDeadlines = calculatedSubDeadlines.sorted { $0.date < $1.date }
    }
    
    // Adds a new, empty sub-deadline to the list for manual editing
    private func addNewSubDeadline() {
        // Add a default sub-deadline, perhaps dated relative to the final deadline or today
        let defaultDate = Calendar.current.date(byAdding: .day, value: -7, to: finalDeadlineDate) ?? Date()
        let newSubDeadline = SubDeadline(title: "New Step", date: defaultDate)
        projectSubDeadlines.append(newSubDeadline)
        // Sort again after adding
        projectSubDeadlines.sort { $0.date < $1.date }
        print("AddProjectView: Added new manual sub-deadline step.")
    }

    // Deletes sub-deadlines from the list
    private func deleteSubDeadline(at offsets: IndexSet) {
        projectSubDeadlines.remove(atOffsets: offsets)
        print("AddProjectView: Deleted sub-deadline at offsets: \(offsets)")
    }

    // MODIFIED Function called when the Save button is tapped.
    private func saveProject() {
        let trimmedTitle = projectTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            print("AddProjectView Error: Project title cannot be empty.")
            // Optionally show an alert
            return
        }
        
        // Get the template ID and name *if* a template was used
        let currentTemplateID = useTemplate ? selectedTemplateID : nil
        let currentTemplateName = useTemplate ? selectedTemplate?.name : nil
        
        print("AddProjectView: Saving project '\(trimmedTitle)' with final date \(finalDeadlineDate). Template Used: \(currentTemplateName ?? "None")")
        
        // Create the project using the template if one was selected
        let newProject: Project
        if useTemplate, let template = selectedTemplate {
            // Use createProjectFromTemplate to properly create triggers
            newProject = viewModel.createProjectFromTemplate(
                template: template,
                title: trimmedTitle,
                finalDeadline: finalDeadlineDate
            )
        } else {
            // Create without template
            newProject = Project(
                title: trimmedTitle,
                finalDeadlineDate: finalDeadlineDate,
                subDeadlines: projectSubDeadlines.sorted { $0.date < $1.date }, // Ensure sorted on save
                templateID: nil,
                templateName: nil
            )
        }
        
        // Add the newly created project using the ViewModel.
        viewModel.addProject(newProject)
        
        print("AddProjectView: Project added successfully.")
    }
    
    // REMOVED: Helper function to calculate preview dates - no longer needed
}

// MARK: - Simple Sub-Deadline Row for AddProjectView
// Displays derived/manual sub-deadline info without editing controls.
private struct AddProjectSubDeadlineRow: View {
    let subDeadline: SubDeadline // Use immutable SubDeadline, not binding
    
    // Date formatter for display
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        HStack {
            Text(subDeadline.title)
            Spacer()
            Text(subDeadline.date, formatter: Self.dateFormatter)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Editable SubDeadline Row View - REMOVED DUPLICATE DEFINITION
// This view is now defined in ProjectEditorView.swift
/*
struct EditableSubDeadlineRow: View {
    @Binding var subDeadline: SubDeadline
    let dateFormatter: DateFormatter

    var body: some View {
        HStack {
            // Editable Title
            TextField("Sub-deadline Title", text: $subDeadline.title)
                .textFieldStyle(PlainTextFieldStyle()) // Use plain style for seamless integration
            
            Spacer()
            
            // Editable Date
            DatePicker("", selection: $subDeadline.date, displayedComponents: .date)
                .labelsHidden() // Hide the default label
                .datePickerStyle(.compact)
                // Optionally format the displayed date text if needed, but DatePicker handles it
                // .overlay(Text(subDeadline.date, formatter: dateFormatter).foregroundColor(.gray).padding(.leading, 5), alignment: .leading)
        }
    }
}
*/


// MARK: - Preview Provider
struct AddProjectView_Previews: PreviewProvider {
    // Helper function to create and configure the ViewModel for previews
    static func createPreviewViewModel() -> DeadlineViewModel {
        let previewViewModel = DeadlineViewModel()
        // Ensure the preview ViewModel has at least one template for realistic previews.
        if previewViewModel.templates.isEmpty {
             let exampleTemplate = Template(
                 name: "Preview Template",
                 subDeadlines: [
                     TemplateSubDeadline(title: "Design", offset: TimeOffset(value: 2, unit: .weeks)),
                     TemplateSubDeadline(title: "Develop", offset: TimeOffset(value: 1, unit: .weeks))
                 ]
             )
             // Add the template directly to the ViewModel
             previewViewModel.addTemplate(exampleTemplate)
             
             let exampleTemplate2 = Template(name: "Empty Template")
             previewViewModel.addTemplate(exampleTemplate2)
        }
        return previewViewModel
    }
    
    static var previews: some View {
        // Create the configured ViewModel using the helper function.
        let viewModel = createPreviewViewModel()
        
        // Return the AddProjectView, injecting the prepared ViewModel.
        AddProjectView(viewModel: viewModel)
            .preferredColorScheme(.dark)
    }
} 
