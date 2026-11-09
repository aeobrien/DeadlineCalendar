# DeadlineCalendar

## Overview
Work deadline management app. Enter one delivery date and either use a template to calculate sub-deadlines from its offsets or add sub-deadlines manually. Designed for recurring monthly project deliveries. Includes a widget for at-a-glance deadline visibility. Built as a native iOS app in SwiftUI with WidgetKit.

## Phase
Active / maintenance

## Status
**Lane:** work
**Current state:** Actively used. Shared iCloud data layer live with two-way CLI sync.
**Last updated:** 2026-11-05

## Tech Stack
- **Language:** Swift
- **Framework:** SwiftUI, WidgetKit
- **IDE:** Xcode
- **Platform:** iOS

## Key Features
- Delivery-date projects with automatic sub-deadline calculation
- Standalone deadlines with optional repetition (`DeadlineCalendar/AddStandaloneDeadlineView.swift`)
- Recurring monthly delivery support
- Home screen widget (DeadlineCalendarWidget)
- Backup management
- Shared iCloud JSON data layer (`DeadlineCalendar.json`) for cross-platform sync
- CLI tool (`deadline-cli`) for reading/writing data from the command line

## Key Files
- `Models.swift` — Data models
- `DeadlineRow.swift` — Row display component
- `BackupManager.swift` — Backup handling
- `DeadlineCalendarWidget/` — WidgetKit extension
- `DeadlineCalendar/SharedDataStore.swift` — iCloud shared JSON file manager
- `deadline-cli/` — Swift CLI package (list, status, complete, trigger, adjust, add, export)

## Subsystems
| Subsystem | Doc | Status |
|-----------|-----|--------|
| iOS app, WidgetKit extension, and CLI | `DeadlineCalendarWidget/`, `deadline-cli/` | Active |

## Linked Projects
| Project | Relationship | Notes |
|---------|-------------|-------|
| Momentum | related-to | Both use the same shared iCloud data pattern; Dashboard reads both |
| Ledger | related-to | Dashboard integration; CLI tools part of Ledger ecosystem |
