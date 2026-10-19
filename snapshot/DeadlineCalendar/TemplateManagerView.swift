// Deadline Calendar/Deadline Calendar/TemplateManagerView.swift

import SwiftUI

struct TemplateManagerView: View {
    @ObservedObject var viewModel: DeadlineViewModel
    @Environment(\.dismiss) var dismiss
    
    // State to control presenting the TemplateEditorView sheet
    @State private var showingTemplateEditor = false
    // State to hold the template being edited (nil for creating new)
    @State private var templateToEdit: Template? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // --- List of Templates ---
                List {
                    // Check if there are any templates.
                    if viewModel.templates.isEmpty {
                        Text("No templates defined. Tap '+' to create one.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        // Display each template.
                        ForEach(viewModel.templates) { template in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(template.name)
                                        .font(.headline)
                                    Text("\(template.subDeadlines.count) step\(template.subDeadlines.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                // Button to trigger editing this template
                                Button {
                                    templateToEdit = template
                                    showingTemplateEditor = true
                                } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(BorderlessButtonStyle()) // Prevent row tap activation
                            }
                            .contentShape(Rectangle()) // Allow tapping empty space for edit
                            .onTapGesture { // Allow tapping row to edit
                                templateToEdit = template
                                showingTemplateEditor = true
                            }
                        }
                        // Implement swipe-to-delete action.
                        .onDelete(perform: deleteTemplates)
                    }
                }
                .listStyle(InsetGroupedListStyle()) // Use inset grouped for better sectioning appearance
            }
            .navigationTitle("Manage Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Toolbar item for closing the view.
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                // Toolbar item for adding a new template.
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                         EditButton() // Standard edit button to enable delete
                         Button {
                             templateToEdit = nil // Ensure we are creating new
                             showingTemplateEditor = true
                         } label: {
                             Image(systemName: "plus.circle.fill")
                         }
                    }
                }
            }
            // Sheet presentation for the TemplateEditorView.
            .sheet(isPresented: $showingTemplateEditor) {
                // Pass the viewModel and the template to edit (which might be nil)
                TemplateEditorView(viewModel: viewModel, templateToEdit: $templateToEdit)
            }
        }
        .preferredColorScheme(.dark)
    }

    // --- Action Functions ---

    // Function to handle deleting templates from the list via swipe action.
    private func deleteTemplates(at offsets: IndexSet) {
        // Convert IndexSet to Array of Templates to delete, respecting current sort/filter if any
        // In this case, the list directly reflects viewModel.templates, so we can map indices.
        let templatesToDelete = offsets.map { viewModel.templates[$0] }
        print("TemplateManagerView: Deleting templates at indices: \(offsets)")
        for template in templatesToDelete {
            viewModel.deleteTemplate(template)
        }
    }
}

// MARK: - Placeholder Template Editor View
// Replace this with the actual TemplateEditorView implementation later.
// Commenting out or deleting the placeholder view as it's now replaced
/*
struct TemplateEditorViewPlaceholder: View {
    @ObservedObject var viewModel: DeadlineViewModel
    @Binding var templateToEdit: Template?
    @Environment(\.dismiss) var dismiss
    
    // Computed property for the navigation title to avoid complex interpolation
    private var editorTitle: String {
        if let template = templateToEdit {
            return "Edit \(template.name)"
        } else {
            return "New Template"
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                Text(templateToEdit == nil ? "Create New Template" : "Edit Template")
                    .font(.largeTitle)
                Text("Implementation Pending...")
                    .foregroundColor(.gray)
                    .padding()
                Spacer()
            }
            .navigationTitle(editorTitle) // Use the computed property
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                         // Add save logic here using viewModel.add/update
                         print("TemplateEditorPlaceholder: Save tapped (Logic pending)")
                         dismiss()
                    }
                    // .disabled(formIsIncomplete)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
*/


// MARK: - Preview Provider
struct TemplateManagerView_Previews: PreviewProvider {
    // Helper function to create and configure the ViewModel for previews
    static func createPreviewViewModel() -> DeadlineViewModel {
        let previewViewModel = DeadlineViewModel()
        // Add a couple of templates for the preview if empty.
        if previewViewModel.templates.isEmpty {
            // Create Template 1 with an explicitly defined sub-deadline offset
            let subDeadline1 = TemplateSubDeadline(title: "Step 1", offset: TimeOffset()) // Explicit default offset
            let template1 = Template(name: "Template One", subDeadlines: [subDeadline1])
            previewViewModel.addTemplate(template1)
            
            // Create Template 2
            let template2 = Template(name: "Template Two", subDeadlines: [])
            previewViewModel.addTemplate(template2)
        }
        return previewViewModel
    }

    static var previews: some View {
        // Create the configured ViewModel using the helper function.
        let viewModel = createPreviewViewModel()
        
        // Return the TemplateManagerView, injecting the prepared ViewModel.
        TemplateManagerView(viewModel: viewModel)
            .preferredColorScheme(.dark) // Apply directly to the view if needed
    }
} 