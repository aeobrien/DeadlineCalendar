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
        print("WIDGET_LOG: --- Starting loadUpcomingSubDeadlines ---") // START MARKER

        // --- 1. Access UserDefaults ---
        guard let userDefaults = UserDefaults(suiteName: "group.com.yourapp.deadlines") else {
            print("WIDGET_LOG: Error - Failed to access shared UserDefaults suite 'group.com.yourapp.deadlines'. Returning empty.") // ERROR 1
            return []
        }
        print("WIDGET_LOG: Successfully accessed shared UserDefaults.") // SUCCESS 1

        // --- 2. Retrieve Data ---
        guard let data = userDefaults.data(forKey: projectsKey) else {
            print("WIDGET_LOG: No data found in UserDefaults for key '\(projectsKey)'. Returning empty.") // ERROR 2
            return []
        }
        print("WIDGET_LOG: Found data for key '\(projectsKey)'. Size: \(data.count) bytes.") // SUCCESS 2

        // --- 3. Decode Data ---
        var allProjects: [Project] = []
        let decoder = JSONDecoder()
        do {
            allProjects = try decoder.decode([Project].self, from: data)
            print("WIDGET_LOG: Successfully decoded \(allProjects.count) projects.") // SUCCESS 3
            // Optional: Log project titles if needed for debugging, but be mindful of log size
            // print("WIDGET_LOG: Decoded Project Titles: \(allProjects.map { $0.title })")
        } catch {
            print("WIDGET_LOG: Error - Failed to decode projects data from UserDefaults.") // ERROR 3 Start
            print("  Key: '\(projectsKey)'")
            print("  Error Details: \(error)")
            // Log detailed decoding error
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("  Decoding Error: TypeMismatch - Expected '\(type)', Path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")), Context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("  Decoding Error: ValueNotFound - Expected '\(type)', Path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")), Context: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("  Decoding Error: KeyNotFound - Missing key '\(key.stringValue)', Path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")), Context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("  Decoding Error: DataCorrupted - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")), Context: \(context.debugDescription)")
                @unknown default:
                    print("  Decoding Error: Unknown DecodingError occurred.")
                }
            }
            print("WIDGET_LOG: --- END DECODING ERROR --- Returning empty.") // ERROR 3 End
            return []
        }

        // --- 4. Filter Active Projects ---
        let activeProjects = allProjects.filter { !$0.isFullyCompleted }
        print("WIDGET_LOG: Found \(activeProjects.count) active (non-completed) projects.") // STEP 4

        // --- 5. Extract Upcoming SubDeadlines ---
        let upcomingSubDeadlines = activeProjects.flatMap { project -> [WidgetSubDeadlineInfo] in
            // Log project being processed
            // print("WIDGET_LOG: Processing project '\(project.title)' (\(project.subDeadlines.count) total subdeadlines)")
            
            // --- OPTIMIZATION: Extract title before mapping subdeadlines ---
            let currentProjectTitle = project.title 
            
            let projectSubDeadlines = project.subDeadlines
                .filter { subDeadline in
                    let isUpcoming = Calendar.current.compare(subDeadline.date, to: Date(), toGranularity: .day) != .orderedAscending
                    let keep = !subDeadline.isCompleted && isUpcoming
                    // Optional: Log filtering decision per subdeadline
                    // print("WIDGET_LOG:   - SubDeadline '\(subDeadline.title)' (\(subDeadline.date)): isCompleted=\(subDeadline.isCompleted), isUpcoming=\(isUpcoming) -> Keep=\(keep)")
                    return keep
                }
                .map { subDeadline -> WidgetSubDeadlineInfo in // Explicit return type
                    // --- OPTIMIZATION: Use extracted title, avoid capturing 'project' here ---
                    WidgetSubDeadlineInfo(
                        id: subDeadline.id, 
                        title: subDeadline.title, 
                        date: subDeadline.date, 
                        projectTitle: currentProjectTitle, // Use extracted title
                        isCompleted: subDeadline.isCompleted
                    )
                }
            // Optional: Log how many upcoming were found for this project
            // if !projectSubDeadlines.isEmpty { print("WIDGET_LOG:   -> Found \(projectSubDeadlines.count) upcoming for '\(project.title)'") }
            return projectSubDeadlines
        }
        print("WIDGET_LOG: Extracted \(upcomingSubDeadlines.count) upcoming sub-deadlines from active projects.") // STEP 5

        // --- 6. Sort SubDeadlines ---
        let sortedSubDeadlines = upcomingSubDeadlines.sorted { $0.date < $1.date }
        print("WIDGET_LOG: Sorted \(sortedSubDeadlines.count) sub-deadlines.") // STEP 6
        // Optional: Log sorted deadlines
        // print("WIDGET_LOG: Sorted Titles & Dates: \(sortedSubDeadlines.map { "\($0.title) (\($0.date))" })")

        // --- 7. Limit Results ---
        let limit = 4 // Define the limit clearly
        let deadlinesToShow = Array(sortedSubDeadlines.prefix(limit))
        print("WIDGET_LOG: Limited to top \(deadlinesToShow.count) sub-deadlines (limit was \(limit)).") // STEP 7

        // --- 8. Return Results ---
        print("WIDGET_LOG: --- Finished loadUpcomingSubDeadlines. Returning \(deadlinesToShow.count) items. ---") // END MARKER
        return deadlinesToShow
    }
}
