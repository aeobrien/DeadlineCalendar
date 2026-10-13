import SwiftUI
import WidgetKit

// MARK: - Widget View

// The view that displays the content of a widget entry.
struct DeadlineWidgetEntryView: View {
    // The timeline entry containing the data to display.
    var entry: DeadlineProvider.Entry
    // Environment variable to detect the widget's size.
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: widgetSpacing) {
            // Widget Header
            HStack {
                Text("Upcoming Deadlines")
                    .font(.system(size: titleFontSize, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                // Show current time (optional)
                Text(entry.date, style: .time)
                    .font(.system(size: timestampFontSize))
                    .foregroundColor(.gray)
            }
            
            // Main Content
            if entry.upcomingSubDeadlines.isEmpty {
                // Empty State
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    Text("No upcoming deadlines!")
                        .font(.system(size: emptyStateFontSize, weight: .medium))
                        .foregroundColor(.white)
                    Text("Great job staying on track.")
                        .font(.system(size: emptyStateFontSize - 2))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .multilineTextAlignment(.center)
            } else {
                // List of Sub-Deadlines
                VStack(alignment: .leading, spacing: rowSpacing) {
                    ForEach(Array(entry.upcomingSubDeadlines.prefix(numberOfItemsToShow()).enumerated()), id: \.element.id) { index, subDeadlineInfo in
                        SubDeadlineRow(subDeadlineInfo: subDeadlineInfo)
                    }
                    
                    // Show count if there are more items
                    if entry.upcomingSubDeadlines.count > numberOfItemsToShow() {
                        Text("+ \(entry.upcomingSubDeadlines.count - numberOfItemsToShow()) more")
                            .font(.system(size: emptyStateFontSize, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.top, 2)
                    }
                }
            }
            
            Spacer() // Push content to top
        }
        .padding(widgetPadding)
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    /* --- ORIGINAL BODY COMMENTED OUT ---
    // ... original body code lines 19-92 ...
     */ // --- END ORIGINAL BODY ---

    // --- Layout Helper Functions/Properties --- (Keep these for now, though unused by temp body)

    // Determines the number of items to show based on widget family.
    func numberOfItemsToShow() -> Int {
        switch family {
        case .systemSmall: return 2 // Show 1 or 2 items max on small
        case .systemMedium: return 3 // Show more on medium
        case .systemLarge: return 5 // Show even more on large
        @unknown default:
            return 3 // Default for unknown future sizes
        }
    }
    
    // Dynamic padding based on widget family
    var widgetPadding: EdgeInsets {
        switch family {
        case .systemSmall: return EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        default: return EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        }
    }

    // Dynamic spacing between major elements
    var widgetSpacing: CGFloat {
         return family == .systemSmall ? 4 : 6
    }
    
    // Dynamic spacing between rows
    var rowSpacing: CGFloat {
         return family == .systemSmall ? 4 : 6
    }

    // Dynamic font sizes
        var titleFontSize: CGFloat { return family == .systemSmall ? 14 : 16 }
        var emptyStateFontSize: CGFloat { return family == .systemSmall ? 12 : 14 }
        var timestampFontSize: CGFloat { return 10 } // Keep timestamp small
    }


    // MARK: - SubDeadline Row View

// A view representing a single row for an upcoming sub-deadline.
struct SubDeadlineRow: View {
    /// The sub-deadline data to display.
    let subDeadlineInfo: WidgetSubDeadlineInfo
    /// Access widget family for layout tweaks.
    @Environment(\.widgetFamily) var family

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            // Color indicator bar based on urgency.
            RoundedRectangle(cornerRadius: 2)
                .fill(colorForDeadline)
                .frame(width: 5)

            // Main content (Title, Project, Date)
            VStack(alignment: .leading, spacing: 2) {
                // Combined Project and Sub-deadline Title to match the main app
                Text(subDeadlineInfo.projectTitle == "Standalone Deadlines" ? subDeadlineInfo.title : "\(subDeadlineInfo.projectTitle) \(subDeadlineInfo.title)")
                    .font(.system(size: titleFontSize, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Spacer() // Pushes date info to the right
            
            // Date / Days Remaining
            Text(displayDaysRemaining)
                .font(.system(size: dateFontSize, weight: .semibold))
                .foregroundColor(daysRemainingColor)
                .lineLimit(1)
                .padding(.leading, 4) // Add padding to avoid sticking to Spacer
        }
        .padding(.vertical, rowVerticalPadding)
        .padding(.horizontal, rowHorizontalPadding)
        .background(Color.gray.opacity(0.2)) // Subtle background for each row
        .cornerRadius(6)
    }

    // --- Date & Formatting Helpers ---

    // Calculates the number of days remaining until the sub-deadline.
    var daysRemaining: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDeadlineDay = calendar.startOfDay(for: subDeadlineInfo.date)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfDeadlineDay)
        return components.day ?? 0
    }

    private var displayDate: String {
        let calendar = Calendar.current
        if calendar.isDate(subDeadlineInfo.date, inSameDayAs: Date()) {
            return "Today"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: subDeadlineInfo.date)
        }
    }

    // Shows “X days”, “Tomorrow”, “Due Today”, or “N days overdue” – never a calendar date.
    private var displayDaysRemaining: String {
        let days = daysRemaining

        if days < 0 {
            let unit = abs(days) == 1 ? "day" : "days"
            return "\(abs(days)) \(unit) overdue"
        } else if days == 0 {
            return "Due Today"
        } else if days == 1 {
            return "Tomorrow"
        } else {
            let unit = days == 1 ? "day" : "days"
            return "\(days) \(unit)"
        }
    }


    // Determines the color based on urgency (days remaining).
    var colorForDeadline: Color {
        let days = daysRemaining
        if days < 0 {
            return .red // Overdue
        } else if days < 7 {
            return .red // Less than a week
        } else if days <= 21 {
            return .orange // 1 to 3 weeks
        } else {
            return .green // More than 3 weeks
        }
    }
    
    // Determines the color for the days remaining text.
    var daysRemainingColor: Color {
        let days = daysRemaining
        if days < 0 { return .red }
        else if days <= 1 { return .red } // Today/Tomorrow in Red
        else if days <= 7 { return .orange } // Within week in Orange
        else { return .gray } // Further out in Gray
    }
    
    // --- Layout Helpers for Row ---
    var titleFontSize: CGFloat { return family == .systemSmall ? 12 : 14 }
    var dateFontSize: CGFloat { return family == .systemSmall ? 11 : 13 }
    var rowVerticalPadding: CGFloat { return family == .systemSmall ? 3 : 5 }
    var rowHorizontalPadding: CGFloat { return family == .systemSmall ? 6 : 8 }
}


// MARK: - Preview Provider

// Provides previews for the widget view in different states and families.
struct DeadlineWidget_Previews: PreviewProvider {
    static var previews: some View {
        // Preview with sample data
        DeadlineWidgetEntryView(entry: SubDeadlineEntry(
            date: Date(),
            upcomingSubDeadlines: [WidgetSubDeadlineInfo.example1, WidgetSubDeadlineInfo.example2]
        ))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
        .previewDisplayName("Medium Widget - Sample Data")

        // Preview for small family
        DeadlineWidgetEntryView(entry: SubDeadlineEntry(
            date: Date(),
            upcomingSubDeadlines: [WidgetSubDeadlineInfo.example1, WidgetSubDeadlineInfo.example2]
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
        .previewDisplayName("Small Widget - Sample Data")
        
         // Preview for large family
         DeadlineWidgetEntryView(entry: SubDeadlineEntry(
             date: Date(),
             upcomingSubDeadlines: [
                 WidgetSubDeadlineInfo.example1,
                 WidgetSubDeadlineInfo(subDeadline: SubDeadline(title: "Storyboard", date: Date().addingTimeInterval(86400 * 5)), project: Project(title: "October Video", finalDeadlineDate: Date())),
                 WidgetSubDeadlineInfo.example2,
                 WidgetSubDeadlineInfo(subDeadline: SubDeadline(title: "Final Sound Mix", date: Date().addingTimeInterval(86400 * 10)), project: Project(title: "November Short", finalDeadlineDate: Date())),
                 WidgetSubDeadlineInfo(subDeadline: SubDeadline(title: "Client Delivery", date: Date().addingTimeInterval(86400 * 14)), project: Project(title: "November Short", finalDeadlineDate: Date()))
             ]
         ))
         .previewContext(WidgetPreviewContext(family: .systemLarge))
         .previewDisplayName("Large Widget - More Data")

        // Preview with empty state
        DeadlineWidgetEntryView(entry: SubDeadlineEntry(
            date: Date(),
            upcomingSubDeadlines: []
        ))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
        .previewDisplayName("Medium Widget - Empty State")
    }
}
