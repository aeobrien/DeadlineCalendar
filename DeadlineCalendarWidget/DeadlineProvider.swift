// DeadlineProvider.swift (Widget Extension)

import WidgetKit
import SwiftUI
import Foundation


// MARK: - Widget Data Structures

// Represents a single SubDeadline shown in the widget.
// Includes the parent project's title for context.
struct WidgetSubDeadlineInfo: Identifiable, Hashable {
    let id: UUID // Use SubDeadline's ID
    let title: String
    let date: Date
    let projectTitle: String
    let isCompleted: Bool // Keep track if needed for display

    // --- OPTIMIZATION: Add an initializer that doesn't require the full Project ---
    init(id: UUID, title: String, date: Date, projectTitle: String, isCompleted: Bool) {
        self.id = id
        self.title = title
        self.date = date
        self.projectTitle = projectTitle
        self.isCompleted = isCompleted
    }

    // Initializer linking SubDeadline and Project (Keep for other uses, like previews)
    init(subDeadline: SubDeadline, project: Project) {
        self.init(id: subDeadline.id, 
                  title: subDeadline.title, 
                  date: subDeadline.date, 
                  projectTitle: project.title, 
                  isCompleted: subDeadline.isCompleted)
    }
    
    // --- CORRECTED STATIC EXAMPLES ---
    // Create dummy SubDeadline and Project objects for the examples
    // Note: Ensure Models.swift (defining Project/SubDeadline) is included in the Widget target
    
    // Example 1 Data
    private static let exampleProject1 = Project(title: "October Video", finalDeadlineDate: Date().addingTimeInterval(86400 * 10))
    private static let exampleSubDeadline1 = SubDeadline(title: "Script Due", date: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date())
    // Initialize example1 using the correct initializer
    static var example1 = WidgetSubDeadlineInfo(subDeadline: exampleSubDeadline1, project: exampleProject1)

    // Example 2 Data
    private static let exampleProject2 = Project(title: "November Short", finalDeadlineDate: Date().addingTimeInterval(86400 * 20))
    private static let exampleSubDeadline2 = SubDeadline(title: "Animation Review", date: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
    // Initialize example2 using the correct initializer
    static var example2 = WidgetSubDeadlineInfo(subDeadline: exampleSubDeadline2, project: exampleProject2)
}

// The timeline entry for the widget.
// Contains the date for the entry and the list of upcoming sub-deadlines to display.
struct SubDeadlineEntry: TimelineEntry {
    let date: Date // The date this timeline entry applies
    let upcomingSubDeadlines: [WidgetSubDeadlineInfo] // SubDeadlines to show
}

// MARK: - Timeline Provider

struct DeadlineProvider: TimelineProvider {
    typealias Entry = SubDeadlineEntry

    // Provides a placeholder view for the widget gallery.
    func placeholder(in context: Context) -> SubDeadlineEntry {
        print("Widget Provider: Providing placeholder entry (empty data).")
        // Return entry with empty data for placeholder
        let entry = SubDeadlineEntry(date: Date(), upcomingSubDeadlines: [])
        return entry
    }

    // Provides a snapshot entry for transient situations (e.g., widget gallery preview).
    func getSnapshot(in context: Context, completion: @escaping (SubDeadlineEntry) -> Void) {
        print("Widget Provider: Providing snapshot entry (using placeholder data).") // Updated log message
        // --- Return static placeholder data for snapshot --- 
        let entry = SubDeadlineEntry(date: Date(), 
                                     upcomingSubDeadlines: [
                                        WidgetSubDeadlineInfo.example1, // Use the static examples
                                        WidgetSubDeadlineInfo.example2
                                     ].prefix(2).filter { _ in !context.isPreview } // Attempt to show examples only if not in preview? (Or adjust logic)
                                     // Or simply return empty: upcomingSubDeadlines: []
                                    )
        // Let's simplify further for now and just return empty for snapshot:
        // let entry = SubDeadlineEntry(date: Date(), upcomingSubDeadlines: [])
        
        // Using static examples for snapshot:
        let exampleEntry = SubDeadlineEntry(date: Date(), 
                                          upcomingSubDeadlines: [WidgetSubDeadlineInfo.example1, WidgetSubDeadlineInfo.example2])
                                          
        completion(exampleEntry) // Provide entry with static examples
    }

    // Provides the timeline (entries) for the widget.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SubDeadlineEntry>) -> Void) {
        print("Widget Provider: Providing timeline.")
        
        // Load data directly
        let subDeadlines = loadUpcomingSubDeadlines()
        
        // Create a single timeline entry for the immediate future.
        let entry = SubDeadlineEntry(date: Date(),
                                     upcomingSubDeadlines: subDeadlines)

        // Define when the next timeline update should occur.
        // Refresh more frequently if desired, e.g., every 15-30 minutes.
        // Or, calculate based on the next upcoming deadline date.
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        
        // Create the timeline with the single entry and the refresh policy.
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        
        print("Widget Provider: Timeline generated with \(entry.upcomingSubDeadlines.count) sub-deadlines. Next update around \(nextUpdateDate).")
        completion(timeline)
    }
    
    private func loadUpcomingSubDeadlines() -> [WidgetSubDeadlineInfo] {
            let projectsKey = "projects_v2_key"
            
            // Access shared UserDefaults
            guard let userDefaults = UserDefaults(suiteName: "group.com.yourapp.deadlines") else {
                print("Widget: Failed to access shared UserDefaults")
                return []
            }
            
            // Get projects data
            guard let data = userDefaults.data(forKey: projectsKey) else {
                print("Widget: No projects data found")
                return []
            }
            
            // Decode projects using the shared Project model
            do {
                let projects = try JSONDecoder().decode([Project].self, from: data)
                return getUpcomingSubDeadlines(from: projects, limit: 5)
            } catch {
                print("Widget: Failed to decode projects: \(error)")
                return []
            }
        }
    
    // Extract upcoming sub-deadlines from projects while matching the app's filtering logic
        private func getUpcomingSubDeadlines(from projects: [Project], limit: Int) -> [WidgetSubDeadlineInfo] {
            let today = Date()
            var upcomingSubDeadlines: [WidgetSubDeadlineInfo] = []

            // Filter to active projects
            let activeProjects = projects.filter { !$0.isFullyCompleted }

            for project in activeProjects {
                let projectTitle = project.title
                for subDeadline in project.subDeadlines {
                    // Match the same conditions used in the main app
                    if !subDeadline.isCompleted,
                       Calendar.current.compare(subDeadline.date, to: today, toGranularity: .day) != .orderedAscending,
                       isSubDeadlineActive(subDeadline, in: project) {
                        upcomingSubDeadlines.append(
                            WidgetSubDeadlineInfo(
                                id: subDeadline.id,
                                title: subDeadline.title,
                                date: subDeadline.date,
                                projectTitle: projectTitle,
                                isCompleted: subDeadline.isCompleted
                            )
                        )
                    }
                }
            }

            return upcomingSubDeadlines
                .sorted { $0.date < $1.date }
                .prefix(limit)
                .map { $0 }
        }

        // Determine if a sub-deadline should be visible based on its trigger status
        private func isSubDeadlineActive(_ subDeadline: SubDeadline, in project: Project) -> Bool {
            guard let triggerID = subDeadline.triggerID else {
                return true
            }
            if let trigger = project.triggers.first(where: { $0.id == triggerID }) {
                return trigger.isActive
            }
            return false
        }

    }
