// DeadlineProvider.swift (Widget Extension)

import WidgetKit
import SwiftUI

// MARK: - Widget Data Structures

// Represents a single SubDeadline shown in the widget.
// Includes the parent project's title for context.
struct WidgetSubDeadlineInfo: Identifiable, Hashable {
    let id: UUID // Use SubDeadline's ID
    let title: String
    let date: Date
    let projectTitle: String
    let isCompleted: Bool // Keep track if needed for display

    // Initializer linking SubDeadline and Project
    init(subDeadline: SubDeadline, project: Project) {
        self.id = subDeadline.id
        self.title = subDeadline.title
        self.date = subDeadline.date
        self.projectTitle = project.title
        self.isCompleted = subDeadline.isCompleted
    }
    
    // --- CORRECTED STATIC EXAMPLES ---
    // Create dummy SubDeadline and Project objects for the examples
    // Note: Ensure Models.swift (defining Project/SubDeadline) is included in the Widget target
    
    // Example 1 Data
    private static let exampleProject1 = Project(title: "October Video", finalDeadlineDate: Date().addingTimeInterval(86400 * 10))
    private static let exampleSubDeadline1 = SubDeadline(title: "Script Due", date: Calendar.current.date(byAdding: .day, value: 3, to: Date())!)
    // Initialize example1 using the correct initializer
    static var example1 = WidgetSubDeadlineInfo(subDeadline: exampleSubDeadline1, project: exampleProject1)

    // Example 2 Data
    private static let exampleProject2 = Project(title: "November Short", finalDeadlineDate: Date().addingTimeInterval(86400 * 20))
    private static let exampleSubDeadline2 = SubDeadline(title: "Animation Review", date: Calendar.current.date(byAdding: .day, value: 7, to: Date())!)
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
    
    // Key for accessing project data in UserDefaults.
    // MUST match the key used in the main app's ViewModel.
    private let projectsKey = "projects_v2_key"

    // Provides a placeholder view for the widget gallery.
    func placeholder(in context: Context) -> SubDeadlineEntry {
        print("Widget Provider: Providing placeholder entry (empty data).")
        // Return entry with empty data for placeholder
        let entry = SubDeadlineEntry(date: Date(), upcomingSubDeadlines: [])
        return entry
    }

    // Provides a snapshot entry for transient situations (e.g., widget gallery preview).
    func getSnapshot(in context: Context, completion: @escaping (SubDeadlineEntry) -> Void) {
        print("Widget Provider: Providing snapshot entry (using loaded data or empty).")
        // Attempt to load real data, but default to empty if it fails or is empty.
        let subDeadlines = loadUpcomingSubDeadlines() // Keep loading attempt
        let entry = SubDeadlineEntry(date: Date(), upcomingSubDeadlines: subDeadlines)
        completion(entry)
    }

    // Provides the timeline (entries) for the widget.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SubDeadlineEntry>) -> Void) {
        print("Widget Provider: Providing timeline.")
        let subDeadlines = loadUpcomingSubDeadlines()
        
        // Create a single timeline entry for the immediate future.
        let entry = SubDeadlineEntry(date: Date(),
                                     upcomingSubDeadlines: subDeadlines) // Use loaded data (or empty if loading failed)

        // Define when the next timeline update should occur.
        // Refresh more frequently if desired, e.g., every 15-30 minutes.
        // Or, calculate based on the next upcoming deadline date.
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        
        // Create the timeline with the single entry and the refresh policy.
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        
        print("Widget Provider: Timeline generated with \(entry.upcomingSubDeadlines.count) sub-deadlines. Next update around \(nextUpdateDate).")
        completion(timeline)
    }

    // --- Helper Function to Load and Process Data ---
    
    // Loads projects from UserDefaults and extracts upcoming sub-deadlines.
    private func loadUpcomingSubDeadlines() -> [WidgetSubDeadlineInfo] {
        print("Widget Provider: Loading projects from UserDefaults...")
        guard let userDefaults = UserDefaults(suiteName: "group.com.yourapp.deadlines") else {
            print("Widget Provider Error: Failed to access shared UserDefaults.")
            return []
        }

        var allProjects: [Project] = []
        guard let data = userDefaults.data(forKey: projectsKey) else {
            // Log if no data found for the key.
            print("Widget Provider: No data found in UserDefaults for key '\(projectsKey)'. Returning empty.")
            return []
        }

        // Attempt to load and decode the project data with error handling.
        let decoder = JSONDecoder()
        do {
            allProjects = try decoder.decode([Project].self, from: data)
            print("Widget Provider: Successfully loaded and decoded \(allProjects.count) projects.")
        } catch {
            // Log decoding failure.
            print("Widget Provider Error: Failed to decode projects data from UserDefaults. Key: \(projectsKey). Error: \(error). Returning empty.")
            // Return empty if decoding fails to prevent using potentially corrupt/outdated structure
            return []
        }

        // Filter projects: Keep only those not fully completed.
        let activeProjects = allProjects.filter { !$0.isFullyCompleted }
        print("Widget Provider: Found \(activeProjects.count) active projects.")

        // Extract upcoming (non-completed, future or today) sub-deadlines from active projects.
        let upcomingSubDeadlines = activeProjects.flatMap { project -> [WidgetSubDeadlineInfo] in
            // Filter sub-deadlines within each project.
            project.subDeadlines
                .filter { subDeadline in
                    // Keep if not completed AND the date is today or in the future.
                    !subDeadline.isCompleted && Calendar.current.compare(subDeadline.date, to: Date(), toGranularity: .day) != .orderedAscending
                }
                .map { subDeadline in
                    // Convert to WidgetSubDeadlineInfo, including the project title.
                    WidgetSubDeadlineInfo(subDeadline: subDeadline, project: project)
                }
        }
        
        print("Widget Provider: Extracted \(upcomingSubDeadlines.count) upcoming sub-deadlines from active projects.")

        // Sort the extracted sub-deadlines by date (earliest first).
        let sortedSubDeadlines = upcomingSubDeadlines.sorted { $0.date < $1.date }

        // Limit the number of deadlines shown in the widget (e.g., top 4).
        // This limit could also depend on the widget family size (context.family).
        let deadlinesToShow = Array(sortedSubDeadlines.prefix(4))
        print("Widget Provider: Returning \(deadlinesToShow.count) sub-deadlines for the widget entry.")
        
        return deadlinesToShow
    }
}
