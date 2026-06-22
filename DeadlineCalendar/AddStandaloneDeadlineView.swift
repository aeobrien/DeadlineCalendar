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
    
    // State variables for repetition settings
    @State private var enableRepetition: Bool = false
    @State private var repetitionType: RepetitionType = .fixedInterval
    @State private var intervalValue: Int = 1
    @State private var intervalUnit: TimeOffsetUnit = .weeks
    @State private var dayOfMonthPosition: DayOfMonthPosition = .first
    @State private var dayOfMonthWeekday: RepetitionWeekday = .monday
    @State private var useDayNumber: Bool = false
    @State private var dayNumber: Int = 1
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var hasMaxOccurrences: Bool = false
    @State private var maxOccurrences: Int = 10

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
                
                // Section for repetition settings
                Section(header: Text("Repetition Settings")) {
                    Toggle("Repeat", isOn: $enableRepetition.animation())
                    
                    if enableRepetition {
                        Picker("Repetition Type", selection: $repetitionType) {
                            Text("Fixed Interval").tag(RepetitionType.fixedInterval)
                            Text("Day of Month").tag(RepetitionType.dayOfMonth)
                        }
                        .pickerStyle(.segmented)
                        
                        if repetitionType == .fixedInterval {
                            // Fixed interval settings
                            HStack {
                                Text("Every")
                                Picker("Value", selection: $intervalValue) {
                                    ForEach(1..<100) { value in
                                        Text("\(value)").tag(value)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 80)
                                
                                Picker("Unit", selection: $intervalUnit) {
                                    Text("Day(s)").tag(TimeOffsetUnit.days)
                                    Text("Week(s)").tag(TimeOffsetUnit.weeks)
                                    Text("Month(s)").tag(TimeOffsetUnit.months)
                                }
                                .pickerStyle(.menu)
                            }
                        } else if repetitionType == .dayOfMonth {
                            // Day of month settings
                            Toggle("Use specific day number", isOn: $useDayNumber.animation())
                            
                            if useDayNumber {
                                Picker("Day of month", selection: $dayNumber) {
                                    ForEach(1...31, id: \.self) { day in
                                        Text("\(day)").tag(day)
                                    }
                                }
                                .pickerStyle(.menu)
                            } else {
                                HStack {
                                    Picker("Position", selection: $dayOfMonthPosition) {
                                        ForEach(DayOfMonthPosition.allCases) { position in
                                            Text(position.rawValue).tag(position)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    
                                    Picker("Weekday", selection: $dayOfMonthWeekday) {
                                        ForEach(RepetitionWeekday.allCases) { weekday in
                                            Text(weekday.displayName).tag(weekday)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                        }
                        
                        // End date settings
                        Toggle("End date", isOn: $hasEndDate.animation())
                        if hasEndDate {
                            DatePicker("End by", selection: $endDate, in: date..., displayedComponents: .date)
                        }
                        
                        // Max occurrences settings
                        Toggle("Limit occurrences", isOn: $hasMaxOccurrences.animation())
                        if hasMaxOccurrences {
                            Stepper("Max \(maxOccurrences) occurrences", value: $maxOccurrences, in: 1...100)
                        }
                    }
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
        
        // Create repetition pattern if enabled
        var repetitionPattern: RepetitionPattern? = nil
        if enableRepetition {
            repetitionPattern = RepetitionPattern(
                type: repetitionType,
                intervalValue: intervalValue,
                intervalUnit: intervalUnit,
                dayOfMonthPosition: dayOfMonthPosition,
                dayOfMonthWeekday: dayOfMonthWeekday,
                dayOfMonthDay: useDayNumber ? dayNumber : nil,
                maxOccurrences: hasMaxOccurrences ? maxOccurrences : nil,
                endDate: hasEndDate ? endDate : nil
            )
        }
        
        // Create the new standalone deadline instance.
        let newDeadline = SubDeadline(
            title: trimmedTitle,
            date: date,
            isCompleted: false, // Starts as not completed.
            subtasks: [], // Standalone deadlines don't have subtasks initially.
            templateSubDeadlineID: nil, // Not from a template.
            triggerID: nil, // Standalone deadlines don't use triggers.
            repetitionPattern: repetitionPattern
        )
        
        // Add the deadline using the view model.
        viewModel.addStandaloneDeadline(newDeadline)
        
        // If repetition is enabled, also create future occurrences
        if let pattern = repetitionPattern, pattern.type != .none {
            viewModel.generateRepetitionOccurrences(for: newDeadline)
        }
        
        print("AddStandaloneDeadlineView: Saved standalone deadline '\(newDeadline.title)' for date \(newDeadline.date)")
        if repetitionPattern != nil {
            print("  - With repetition pattern: \(repetitionPattern!.type.rawValue)")
        }
        
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
