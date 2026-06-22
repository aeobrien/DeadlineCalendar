# DeadlineCalendar

## Overview
Work deadline management app. Enter one delivery date and the app auto-calculates all sub-deadlines (X days before delivery = milestone Y). Designed for recurring monthly project deliveries. Includes a widget for at-a-glance deadline visibility. Built as a native iOS app in SwiftUI with WidgetKit.

## Phase
Active / maintenance

## Status
**Current state:** Actively used. Shared iCloud data layer live with two-way CLI sync.
**Last updated:** 2026-04-06

## Tech Stack
- **Language:** Swift
- **Framework:** SwiftUI, WidgetKit
- **IDE:** Xcode
- **Platform:** iOS

## Key Features
- Single delivery date entry with automatic sub-deadline calculation
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
| (none yet) | — | — |

## Linked Projects
| Project | Relationship | Notes |
|---------|-------------|-------|
| Momentum | related-to | Both use the same shared iCloud data pattern; Dashboard reads both |
| Ledger | related-to | Dashboard integration; CLI tools part of Ledger ecosystem |
