# Step evidence

The live Mac `/Applications` directory contains no Deadline Calendar bundle. The installed live app is **Deadline Calendar** (`AOTondra.Deadline-Calendar`, version 1.0, build 1) on the paired iPhone **Mirador**, confirmed with `xcrun devicectl device info apps --device 417083F1-F65A-512D-9BA0-59D97BBA1F82` on 17 October 2026.

The device's installed version is matched to the available release artifact at `/Users/aidan/Worktrees/deadline-release-3fc25c2/build/Build/Products/Release-iphoneos/Deadline Calendar.app` (version 1.0, build 1). Its source revision is `3fc25c2`.

- Steps 1–2: `DeadlineCalendar/ProjectsListViewRedesigned.swift:119-121,177-180` shows the Projects screen's lower-right plus button opening `AddProjectView`.
- Steps 2–5: `DeadlineCalendar/AddProjectView.swift:57-65,131-163,236-252` supplies the exact Add New Project, Project Title, Final Deadline Date, Use Template, Add Sub-deadline Step, Repeat Project, Cancel and Save labels.
- Step 4: `DeadlineCalendar/AddProjectView.swift:331-336,440-458` shows each new row begins as New Step with title field and date picker.
- Step 5: `DeadlineCalendar/AddProjectView.swift:161-231` supplies Fixed Interval, Every, Month(s), Limit occurrences and Max N occurrences.
- Step 6: `DeadlineCalendar/AddProjectView.swift:348-407` creates the project and generates repeat occurrences; `DeadlineCalendar/ContentView.swift:624-667` identifies an Admin project with a one-month, two-occurrence pattern as the rolling Admin pair after completion.

No screen was opened or controlled, no calendar file was written, and this walkthrough has not been launched.
