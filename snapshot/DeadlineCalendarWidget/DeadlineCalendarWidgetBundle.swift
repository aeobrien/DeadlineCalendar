//
//  DeadlineCalendarWidgetBundle.swift
//  DeadlineCalendarWidget
//
//  Created by Aidan O'Brien on 16/10/2024.
//

import WidgetKit
import SwiftUI

// MARK: - Main Widget Definition

@main
struct DeadlineCalendarWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeadlineCalendarWidget()
    }
}

// MARK: - Individual Widget Configuration

struct DeadlineCalendarWidget: Widget {
    let kind: String = "DeadlineCalendarWidget"

    var body: some WidgetConfiguration {
        // Reverted back to StaticConfiguration as ConfigurationIntent was not found
        StaticConfiguration(kind: kind, provider: DeadlineProvider()) {
            // Provide the view for the widget entry
            entry in
            DeadlineWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Upcoming Tasks") // Updated display name slightly
        .description("Shows upcoming sub-deadlines from your projects.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}



