# Read and manage DeadlineCalendar

The app and the command-line tool use the existing DeadlineCalendar JSON file. The default remains its iCloud Documents location. A command can select another existing file with `--data-file /absolute/path/DeadlineCalendar.json`; that option never reads the default location or a legacy backup. A missing, corrupt or unavailable selected file is an error, not an empty registry.

Build the maintained tool with `swift build --package-path deadline-cli`. The executable is `deadline-cli/.build/debug/deadline-cli` in this checkout. No installer, published session route or live iCloud write is part of this change.

## Read

`deadline-cli list` and `deadline-cli status` keep their human-readable output. Add `--json` for structured projects/deadlines, including their IDs. `deadline-cli export` prints the complete saved envelope as JSON; diagnostics go to stderr. Default reads may use an available legacy backup if the shared file is genuinely absent, and explicitly identify that fallback. Mutations never promote a backup over the shared file.

Examples below omit `--data-file`; append it to every command when using a selected file. Do not use a real file for a test. These commands show the supported interface, not permission to change records.

## Add after approval

Show the intended title, date and destination to the user and obtain approval first. Generate and retain one UUID for this addition, then use:

```
deadline-cli add "Agreed title" --date 2030-02-01 --id DEADLINE_UUID --approved
deadline-cli list --json
```

No destination means Standalone Deadlines. The tool creates that container in an existing valid document if necessary. `--project-id PROJECT_UUID` chooses an existing exact project; `--project TITLE` is allowed only when its title match is unique. Repeating the same UUID and unchanged initial content is a no-op success; changed content or a reused ID is refused. If a reply is lost, read that ID before any retry. Omitting the ID makes automatic retries unsafe because a fresh command generates a new ID.

## Edit or complete

```
deadline-cli update --project-id PROJECT_UUID --deadline-id DEADLINE_UUID --title "Revised title" --date 2030-02-03 --completed true
```

Supply one or more changed fields. Read back with `list --json` or `export`. Existing `complete PROJECT_TITLE DEADLINE_TITLE`, `adjust PROJECT_TITLE DEADLINE_TITLE --date YYYY-MM-DD`, and `trigger PROJECT_TITLE TRIGGER_NAME` remain supported. Title matches must be unique and are resolved inside the write transaction. Missing targets and invalid dates return a nonzero exit without a write. Ordinary edits do not acquire an extra approval requirement.

## Remove after approving the exact preview

```
deadline-cli delete --project-id PROJECT_UUID --deadline-id DEADLINE_UUID --preview
```

The preview contains the complete target, including nested subtasks, and the file revision. Obtain approval for that removal before applying it:

```
deadline-cli delete --project-id PROJECT_UUID --deadline-id DEADLINE_UUID --revision REVISION_FROM_PREVIEW --approved
```

It removes that deadline and its nested subtasks. Other recurrence occurrences, the project, templates and triggers remain. Any intervening file change invalidates the revision; show a new preview and obtain renewed approval before removal. A repeated removal of an already absent target reports that nothing changed. The approval flag is an acknowledgement of actual user consent, not a way to grant it.

## App save failures and changed data

The app saves the shared file before changing its local cache, widgets or notifications. A failed save keeps the editor open and retains the attempted document in this app session. The notice offers a copy of that attempt. Reload closes old editors and reads the current file; review the retained attempt before making a new edit. A later successful save replaces that retained copy, and quitting the app does not preserve an in-memory attempt.

External change notifications do not silently advance an open editor's baseline. If another participating local writer saves first, an old app save is refused rather than overwriting the newer data. Reload uses a new editor generation. Related recurrence/trigger changes and backup restores save together. Existing multi-selection deletion still performs separate removals; if a later removal fails, earlier successful removals remain. This change does not make that gesture an all-or-nothing bulk operation.

When the shared file is genuinely absent, the app can migrate correctly decoded local data. Corrupt data, non-data cache values, conflicting legacy copies, unavailable iCloud content and unresolved file versions stop migration without deleting old keys. The existing SavedProjects alias and older templates without a trigger field remain supported. Missing legacy trigger dates are filled using the existing template/default-date rule within the same coordinated commit. Unsupported or malformed formats are not silently converted to empty data.

These checks coordinate local writers and detect stale local snapshots. They do not make offline devices a single instantaneous database. iCloud synchronization, unresolved remote conflicts, physical-device operation, visible editor interaction and deployment still require their own acceptance. No real deadline or cloud account was changed in the fixture tests.
