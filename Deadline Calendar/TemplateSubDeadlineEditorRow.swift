// Deadline Calendar/Deadline Calendar/TemplateSubDeadlineEditorRow.swift
import SwiftUI

struct TemplateSubDeadlineEditorRow: View {
    // Binding to the sub-deadline being edited in this row
    @Binding var subDeadline: TemplateSubDeadline
    // Binding to the list of available triggers defined in the *template*
    @Binding var availableTemplateTriggers: [TemplateTrigger]

    // State for creating a new template trigger via alert
    @State private var showingCreateTemplateTriggerAlert = false
    @State private var newTemplateTriggerName: String = ""

    // Define a constant dummy UUID for the "Create New" picker option
    static let createNewTemplateTriggerID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    // Formatter for the numeric offset value
    private static var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 1 // Offset value must be at least 1
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // --- Title Editor ---
            TextField("Sub-deadline Title", text: $subDeadline.title)

            // --- Offset Editor ---
            HStack(spacing: 5) {
                // Text Field for the numeric offset value
                TextField("Value", value: $subDeadline.offset.value, formatter: Self.numberFormatter)
                    .frame(width: 50) // Limit width for numeric input
                    .keyboardType(.numberPad) // Show number pad on iOS

                // Picker for the time unit (Days, Weeks, Months)
                Picker("Unit", selection: $subDeadline.offset.unit) {
                    ForEach(TimeOffsetUnit.allCases) { unit in
                        Text(unit.rawValue.capitalized).tag(unit)
                    }
                }
                .pickerStyle(.menu)

                // Toggle for Before/After the deadline
                Picker("Before/After", selection: $subDeadline.offset.before) {
                    Text("Before").tag(true)
                    Text("After").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            .font(.caption)

            // --- Template Trigger Selector ---
            HStack {
                Text("Requires Trigger:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Picker("Trigger", selection: $subDeadline.templateTriggerID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(availableTemplateTriggers) { triggerDef in
                        Text(triggerDef.name).tag(triggerDef.id as UUID?)
                    }
                    // Add option to create a new template trigger
                    Text("Create New Trigger...").tag(Self.createNewTemplateTriggerID as UUID?)
                }
                .pickerStyle(.menu)
                .font(.caption)
                .onChange(of: subDeadline.templateTriggerID) { selectedID in
                    if selectedID == Self.createNewTemplateTriggerID {
                        newTemplateTriggerName = ""
                        showingCreateTemplateTriggerAlert = true
                    }
                }
            }
            // Alert for creating a new TEMPLATE trigger (adds to parent view's state)
            .alert("New Template Trigger", isPresented: $showingCreateTemplateTriggerAlert, actions: {
                TextField("Trigger Definition Name", text: $newTemplateTriggerName)
                Button("Create & Link") {
                    if !newTemplateTriggerName.isEmpty {
                        // Check for duplicates before adding
                        if !availableTemplateTriggers.contains(where: { $0.name.lowercased() == newTemplateTriggerName.lowercased() }) {
                            let newTriggerDef = TemplateTrigger(name: newTemplateTriggerName)
                            // Add to the binding array passed from TemplateEditorView
                            availableTemplateTriggers.append(newTriggerDef)
                            // Link this sub-deadline to the newly created definition
                            subDeadline.templateTriggerID = newTriggerDef.id
                            newTemplateTriggerName = ""
                        } else {
                            print("TemplateSubDeadlineEditorRow Warning: Template trigger name already exists.")
                            // TODO: Show feedback alert
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    // Reset picker selection to None if Create was cancelled
                    if subDeadline.templateTriggerID == Self.createNewTemplateTriggerID {
                        subDeadline.templateTriggerID = nil
                    }
                    newTemplateTriggerName = ""
                }
            }, message: {
                Text("Enter a name for the type of event that can trigger this sub-deadline within the template.")
            })
            // --- End Template Trigger Selector ---
        }
    }
}

// MARK: - Preview Provider
struct TemplateSubDeadlineEditorRow_Previews: PreviewProvider {
    // Updated Preview Wrapper
    struct PreviewWrapper: View {
        @State var subDeadline = TemplateSubDeadline(
            title: "Preview Step",
            offset: TimeOffset(value: 3, unit: .weeks, before: true)
        )
        // Provide sample state for the available triggers binding
        @State var sampleTriggers = [
            TemplateTrigger(name: "Existing Trigger 1"),
            TemplateTrigger(name: "Existing Trigger 2")
        ]

        var body: some View {
            Form { // Embed in Form for realistic preview context
                TemplateSubDeadlineEditorRow(
                    subDeadline: $subDeadline,
                    availableTemplateTriggers: $sampleTriggers // Pass the binding
                )
            }
            .preferredColorScheme(.dark)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
} 