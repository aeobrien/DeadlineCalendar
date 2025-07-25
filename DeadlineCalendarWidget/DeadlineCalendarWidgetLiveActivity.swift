//
//  DeadlineCalendarWidgetLiveActivity.swift
//  DeadlineCalendarWidget
//
//  Created by Aidan O'Brien on 16/10/2024.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct DeadlineCalendarWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct DeadlineCalendarWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeadlineCalendarWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension DeadlineCalendarWidgetAttributes {
    fileprivate static var preview: DeadlineCalendarWidgetAttributes {
        DeadlineCalendarWidgetAttributes(name: "World")
    }
}

extension DeadlineCalendarWidgetAttributes.ContentState {
    fileprivate static var smiley: DeadlineCalendarWidgetAttributes.ContentState {
        DeadlineCalendarWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: DeadlineCalendarWidgetAttributes.ContentState {
         DeadlineCalendarWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: DeadlineCalendarWidgetAttributes.preview) {
   DeadlineCalendarWidgetLiveActivity()
} contentStates: {
    DeadlineCalendarWidgetAttributes.ContentState.smiley
    DeadlineCalendarWidgetAttributes.ContentState.starEyes
}
