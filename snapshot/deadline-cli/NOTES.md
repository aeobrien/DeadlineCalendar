# deadline-cli — Notes

## Data Source: iCloud Backup Files

The CLI reads from iCloud Drive backup files synced to the Mac at:

    ~/Library/Mobile Documents/iCloud~AOTondra~Deadline-Calendar/Documents/DeadlineCalendarBackups/

These are `.deadlinebackup` files (JSON with ISO 8601 dates) created by the DeadlineCalendar iOS app's backup system. The CLI always reads from the **most recent** backup file (sorted by filename timestamp).

### Read path (automatic)
The app creates backups regularly. iCloud syncs them to the Mac. The CLI reads them directly — no setup required beyond having iCloud Drive enabled.

### Write path (semi-automatic)
When the CLI modifies data (complete, trigger, adjust commands), it:
1. Reads the latest backup
2. Applies the change
3. Writes a **new** `.deadlinebackup` file to the same iCloud directory
4. iCloud syncs it back to the phone

The user then needs to **restore from this backup** in the app to apply the change. This is a limitation of the current architecture — the app doesn't auto-detect external backup files.

**Future improvement:** Add an auto-restore-from-latest feature to the app, or switch to a shared data format that both the app and CLI write to directly (e.g., a shared iCloud document or CloudKit).

## Date Encoding

The iCloud backup files use **ISO 8601** date encoding (`.iso8601` strategy in JSONEncoder/JSONDecoder). This is different from the app's UserDefaults storage which uses `deferredToDate` (seconds since 2001-01-01).

## Trigger Resolution

In the backup format, project-level triggers are sometimes empty — triggers live at the top level with a `projectID` field. The CLI's `loadProjectsResolved()` method resolves top-level triggers back into their projects for display.

## Usage

```bash
# Build
cd deadline-cli && swift build

# Quick status — overdue + next 14 days
swift run deadline-cli status

# Full list of all projects
swift run deadline-cli list

# Mark something done
swift run deadline-cli complete "De-extinction" "Music Final"

# Activate a trigger
swift run deadline-cli trigger "Music Therapy" "Storyboard"

# Change a date
swift run deadline-cli adjust "August Topic" "Script" --date 2026-04-15

# Full JSON export
swift run deadline-cli export
```

Or use the built binary directly:
```bash
.build/debug/deadline-cli status
```
