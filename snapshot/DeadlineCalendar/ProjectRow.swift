// Deadline Calendar/Deadline Calendar/ProjectRow.swift
import SwiftUI

struct ProjectRow: View {
    // The project data to display in this row
    var project: Project
    
    // Date formatter for displaying dates concisely
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short // e.g., "6/19/24"
        formatter.timeStyle = .none
        return formatter
    }()
    
    // --- Computed Properties for Row Display ---
    
    // Calculate the number of completed and total sub-deadlines
    private var completedCount: Int {
        project.subDeadlines.filter { $0.isCompleted }.count
    }
    private var totalCount: Int {
        project.subDeadlines.count
    }
    
    // Calculate progress as a value between 0.0 and 1.0
    private var progress: Double {
        guard totalCount > 0 else { return project.isFullyCompleted ? 1.0 : 0.0 } // Handle division by zero and already completed
        return Double(completedCount) / Double(totalCount)
    }
    
    // Find the next upcoming (not completed) sub-deadline date
    private var nextSubDeadlineDate: Date? {
        project.subDeadlines
            .filter { !$0.isCompleted } // Only consider incomplete tasks
            .sorted { $0.date < $1.date } // Sort chronologically
            .first?.date // Get the earliest date
    }
    
    // Format the display text for the next/final deadline
    private var deadlineText: String {
        if let nextDate = nextSubDeadlineDate {
            return "Next: \(dateFormatter.string(from: nextDate))"
        } else if !project.isFullyCompleted && totalCount > 0 {
            // All tasks done, but project not marked fully complete? Show final deadline.
             return "Final: \(dateFormatter.string(from: project.finalDeadlineDate))"
        } else {
            // Project is fully completed or has no tasks, show final deadline
            return "Final: \(dateFormatter.string(from: project.finalDeadlineDate))"
        }
    }
    
    // Format the progress text (e.g., "3 / 5 tasks")
    private var progressText: String {
         guard totalCount > 0 else { return "No tasks" }
         return "\(completedCount) / \(totalCount) tasks"
    }

    var body: some View {
        HStack(spacing: 12) {
            // --- Progress Indicator (Optional: Circular Progress View) ---
            // Simple text-based indicator for now
            VStack {
                 if totalCount > 0 {
                     Text("\(Int(progress * 100))%")
                         .font(.caption)
                         .fontWeight(.bold)
                         .foregroundColor(progress >= 1.0 ? .green : .orange) // Green when complete
                 } else {
                     Image(systemName: "minus.circle") // Icon for no tasks
                         .foregroundColor(.gray)
                 }
            }
            .frame(width: 40) // Allocate some fixed width

            // --- Project Details ---
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)
                    .foregroundColor(.white) // Visible on dark background
                    .lineLimit(1) // Prevent long titles from wrapping excessively

                // Display Deadline Info (Next or Final)
                Text(deadlineText)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Display Task Progress Text
                 if totalCount > 0 { // Only show if there are tasks
                     Text(progressText)
                         .font(.caption)
                         .foregroundColor(progress >= 1.0 ? .green : .orange)
                 }
            }

            Spacer() // Pushes content to the left
            
             // --- Optional: Mini Progress Bar ---
             if totalCount > 0 {
                 ProgressView(value: progress)
                     .progressViewStyle(LinearProgressViewStyle(tint: progress >= 1.0 ? .green : .orange))
                     .frame(width: 50) // Small progress bar
                     .padding(.leading, 5)
             }

            // --- Navigation Indicator ---
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 10) // Consistent row padding
        .background(Color.black) // Match the list background
    }
}

// MARK: - Preview Provider
struct ProjectRow_Previews: PreviewProvider {
    // Sample Project 1: In Progress
    static var sampleProjectInProgress: Project = {
        let finalDeadline = Calendar.current.date(byAdding: .day, value: 15, to: Date())!
        let sub1 = SubDeadline(title: "Task 1", date: Calendar.current.date(byAdding: .day, value: 5, to: Date())!, isCompleted: true)
        let sub2 = SubDeadline(title: "Task 2", date: Calendar.current.date(byAdding: .day, value: 10, to: Date())!, isCompleted: false)
        let sub3 = SubDeadline(title: "Task 3", date: Calendar.current.date(byAdding: .day, value: 12, to: Date())!, isCompleted: false)
        return Project(title: "Website Redesign Project - Active", finalDeadlineDate: finalDeadline, subDeadlines: [sub1, sub2, sub3], templateName: "Web Dev")
    }()
    
    // Sample Project 2: Completed
    static var sampleProjectCompleted: Project = {
        let finalDeadline = Calendar.current.date(byAdding: .day, value: -10, to: Date())! // Past deadline
        let sub1 = SubDeadline(title: "Task A", date: Calendar.current.date(byAdding: .day, value: -20, to: Date())!, isCompleted: true)
        let sub2 = SubDeadline(title: "Task B", date: Calendar.current.date(byAdding: .day, value: -15, to: Date())!, isCompleted: true)
         return Project(title: "Video Shoot - Completed", finalDeadlineDate: finalDeadline, subDeadlines: [sub1, sub2])
    }()
    
    // Sample Project 3: No Sub-deadlines
    static var sampleProjectNoTasks: Project = {
        let finalDeadline = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
         return Project(title: "Quick Meeting Prep", finalDeadlineDate: finalDeadline, subDeadlines: [])
    }()

    static var previews: some View {
        List { // Preview within a List for context
            ProjectRow(project: sampleProjectInProgress)
            ProjectRow(project: sampleProjectCompleted)
            ProjectRow(project: sampleProjectNoTasks)
        }
        .listStyle(PlainListStyle())
        .preferredColorScheme(.dark)
        .background(Color.black)
    }
} 