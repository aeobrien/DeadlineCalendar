# Read and manage deadlines from Claude or Codex

Candidate instructions only. The reviewed implementation is not yet fully accepted or installed. Root must publish this guide through the existing shared manual after final app acceptance and installation; there is no separate deadline service to launch.

## Find the maintained interface

For either ordinary client, use the shared manual's deadline-management instructions when the job is to read upcoming deadlines, add one, change its date/title/completion, or remove an exact deadline. The published instructions must identify the installed absolute binary, accepted commit/digest, supported platform and current guide. Reading this file by an explicit path establishes candidate awareness only; fresh Claude and Codex discovery still needs separate evidence. Do not substitute the dashboard task registry for DeadlineCalendar records.

Once installed, use `/Users/aidan/.local/bin/deadline-cli`; root must confirm it resolves to the accepted versioned artifact. Until then, the maintained candidate executable is `/Users/aidan/Dev/DeadlineCalendar-session-storage/deadline-cli/.build/debug/deadline-cli`, for temporary fixtures only. Do not claim the old primary source has these commands before integration. Never rebuild as part of every user operation.

## Read the current state

`/Users/aidan/.local/bin/deadline-cli list --json`

`/Users/aidan/.local/bin/deadline-cli status --json`

`/Users/aidan/.local/bin/deadline-cli export`

List includes project/deadline IDs; export provides the full saved envelope. Read stderr as well as stdout: a legacy-backup fallback is historical data, not proof that the shared file is current or writable. If the file is unavailable/corrupt/conflicted, report that and preserve it. Do not hydrate it or create an empty replacement as a workaround. Normal operating-system permissions remain in force.

Every command supports `--data-file /absolute/path/DeadlineCalendar.json` for a user-selected existing file. Pass it to every command in that operation; omitting it changes the destination back to the actual iCloud default. Temporary fixture checks always use an explicit path.

## Add with approval, then read back

Resolve the destination project by exact ID and explain the complete proposed title/date/destination. Obtain user approval. Retain one generated deadline UUID for this approved operation.

`/Users/aidan/.local/bin/deadline-cli add 'Approved title' --date 2030-02-01 --project-id PROJECT_UUID --id DEADLINE_UUID --approved`

Read list/export and match the exact IDs and fields. With no destination option the tool uses Standalone Deadlines, creating its container in an already valid document if needed. If the reply is lost, read the retained ID before retrying. The same ID and initial content are an already-applied no-op; reused ID/different content is an error. Never generate a fresh ID merely because a reply was lost. The flag acknowledges actual approval; it does not create it.

## Edit exact records

`/Users/aidan/.local/bin/deadline-cli update --project-id PROJECT_UUID --deadline-id DEADLINE_UUID --title 'Revised title' --date 2030-02-03 --completed true`

Supply only intended changed fields. Read back the exact ID and resulting fields. Ordinary edits require no added approval rule. Missing, duplicate or ambiguous targets fail without guessing. Title convenience commands remain available but prefer IDs for session work. Do not use array indices captured from a previous read.

## Remove the approved exact content

`/Users/aidan/.local/bin/deadline-cli delete --project-id PROJECT_UUID --deadline-id DEADLINE_UUID --preview`

Show the complete target, including nested subtasks, and explain that recurrence siblings/project/templates/triggers remain. Obtain approval for that content, retain the preview's revision, then apply:

`/Users/aidan/.local/bin/deadline-cli delete --project-id PROJECT_UUID --deadline-id DEADLINE_UUID --revision APPROVED_REVISION --approved`

Any intervening change invalidates that preview. Read a new preview and obtain renewed approval; never silently replace the revision in an old approval. After a lost reply, read the target: an absent target means the removal already happened, not permission to remove a similar one. A repeated removal of that absent exact target is a no-op. A recreated/reused target cannot be deleted using stale approval.

## Conflict and failure recovery

A nonzero exit is not success. Preserve the error, read the current exact record when available, and explain what remains uncertain. Busy/unavailable does not authorize a forced overwrite or blind add. The app keeps a failed attempt in memory and offers a copy; explicit reload reads current data and invalidates old editors. Do not keep editing a stale form after reload. An app save and CLI edit share local coordination but offline devices still synchronize eventually.

Do not promise live CRUD from fixture evidence. Physical/cloud acceptance, final current iOS tests, installation, route publication and fresh-client discovery each retain their own status. See ../SESSION-CRUD.md and INSTALL-ROLLBACK.md for the maintained contract and release boundary.
