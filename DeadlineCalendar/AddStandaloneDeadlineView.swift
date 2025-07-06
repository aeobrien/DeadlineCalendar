import SwiftUI

/// A view presented as a sheet to add a new standalone deadline.
struct AddStandaloneDeadlineView: View {
    // Access the shared view model to add the deadline.
    @ObservedObject var viewModel: DeadlineViewModel
    
    // Environment variable to dismiss the sheet.
    @Environment(\.dismiss) var dismiss
    
    // State variables for the deadline details.
    @State private var title: String = ""
    @State private var date: Date = Date() // Default to today

    var body: some View {
        NavigationView {
            Form {
                // Section for deadline details.
                Section(header: Text("Deadline Details")) {
                    // Text field for the deadline title.
                    TextField("Deadline Title", text: $title)
                    
                    // Date picker for the deadline date.
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("New Standalone Deadline") // Set the navigation bar title.
            .navigationBarTitleDisplayMode(.inline) // Use inline title style.
            .preferredColorScheme(.dark) // Maintain dark mode consistency.
            .toolbar {
                // Toolbar item for the Cancel button.
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss() // Dismiss the sheet without saving.
                    }
                }
                
                // Toolbar item for the Save button.
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDeadline() // Call the save function.
                    }
                    // Disable the Save button if the title is empty.
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack) // Consistent navigation style.
    }
    
    /// Creates a new SubDeadline object and adds it via the view model.
    private func saveDeadline() {
        // Trim whitespace from the title.
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure the title is not empty after trimming.
        guard !trimmedTitle.isEmpty else {
            print("AddStandaloneDeadlineView Error: Title cannot be empty.")
            // Optionally show an alert to the user here.
            return
        }
        
        // Create the new standalone deadline instance.
        let newDeadline = SubDeadline(
            title: trimmedTitle,
            date: date,
            isCompleted: false, // Starts as not completed.
            subtasks: [], // Standalone deadlines don't have subtasks initially.
            templateSubDeadlineID: nil, // Not from a template.
            triggerID: nil // Standalone deadlines don't use triggers.
        )
        
        // Add the deadline using the view model.
        viewModel.addStandaloneDeadline(newDeadline)
        
        print("AddStandaloneDeadlineView: Saved standalone deadline '\(newDeadline.title)' for date \(newDeadline.date)")
        
        // Dismiss the sheet after saving.
        dismiss()
    }
}

// MARK: - Preview Provider
struct AddStandaloneDeadlineView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a dummy ViewModel for the preview.
        // Assuming DeadlineViewModel has a preview instance.
        AddStandaloneDeadlineView(viewModel: DeadlineViewModel.preview)
            .preferredColorScheme(.dark) // Match the app's theme in preview.
    }
}
