# Reliable DeadlineCalendar app and session CRUD

Deliver full local app/CLI deadline management using the existing shared JSON format and default iCloud location, plus an explicit selected-file option for isolated verification and supported alternate stores. This is not a new service/database or a fixture-only replacement. Base4857669; isolated branch deadline-session-storage preserves primary .DS_Store and all existing real data. Never hydrate the historical dataless placeholder, create real records, invite calendars, open screens or change cloud permissions during implementation/tests. Add/remove actions require user approval; reads/edits do not acquire an additional approval rule.

Ownership: deadline-cli/Sources/DataStore.swift and DeadlineCLI.swift; new shared Foundation-only SnapshotFile.swift in deadline-cli/Sources reused by the app through a minimal Xcode file registration; deadline-cli/Package.swift plus focused tests; DeadlineCalendar/SharedDataStore.swift; persistence and load/error handling in ContentView.swift; necessary add/edit/delete/settings/restore caller result handling; focused app tests and minimal project test/source registrations; docs and reports/session-storage. Preserve model wire format and unrelated view design, signing and deployment settings. Root retains catalogue/publication/integration.

## Step 1: Shared transaction primitive and availability

Keep existing Codable envelope (projects/templates/triggers/appSettings/lastModified/lastModifiedBy). Track the exact bytes loaded as a snapshot token, not lastModified timestamps. A shared Foundation helper binds read/replace under NSFileCoordinator and stable local advisory locking for participating CLI processes; compare expected prior bytes under that same write coordination before replacing. Atomic replacement remains. App stale candidate throws an explicit conflict rather than overwriting; no automatic last-writer-wins merge. CLI operations read the latest snapshot and resolve IDs inside one transaction. Unchanged operations do not rewrite metadata. Ensure all failure paths release locks and preserve bytes.

Reads distinguish absent, unavailable/dataless, corrupt and valid; path lookup must not create directories or download data. Explicit selected-file mode never falls back to real iCloud or backups. Default reads retain explicit legacy-backup provenance; normal mutations must not silently promote a fallback over unavailable shared state. Genuine absent-first-launch migration is a distinct compare-missing operation, based on successfully decoded prior local data; unavailable/corrupt is never absence or permission to initialize an empty registry.

Retain existing two-writer lost-update red. Add actual helper/store tests with temporary URLs for serial concurrent mutations, stale snapshots, missing/corrupt/dataless simulation, failed write, no-op byte stability, symlink/path errors and lock recovery. No test opens the real default path.

- The file `reports/session-storage/concurrency-red-01/cli-run-result.json` exists.
- The command `swift test --package-path deadline-cli` exits 0.

## Step 2: Complete transactional CLI operations

Expose --data-file consistently for read and mutation commands, defaulting to existing location. Keep title convenience only when uniquely resolved; exact project/deadline UUID selection and machine-readable output allow sessions to reliably read back and edit. Complete/adjust/trigger use fresh IDs within transaction, never preloaded indices or force unwrap. Invalid dates/missing/ambiguous/duplicate IDs return nonzero with no write or misleading success. Export stdout contains only its data contract; diagnostics go to stderr.

Add exact-ID update of title/date/completion and delete of one deadline with nested subtasks identified in a read-only removal preview. Apply deletion only with exact target and content revision matching the approved preview; preserve recurrence siblings/projects/triggers/templates. Add/remove acknowledgement flags require the session to have actual user approval, not treat flag presence as autonomous consent. Existing direct app gestures remain direct user actions. Use optional caller-provided UUID for add to make retry readback safe: identical ID/content is already-applied success, conflicting content refuses without another record. Repeated delete reports already absent without touching other records; stale approval cannot delete a changed/reused target.

Exercise actual built CLI with temporary JSON: read/add/readback/update/complete/delete, approval refusals, wrong target, repeats, dates, ambiguous titles, simultaneous writers and untouched unrelated data. Fixtures never hydrate or overwrite live data.

- The file `reports/session-storage/CLI-VALIDATION.md` exists.

## Step 3: App stale-write conflict and commit ordering

SharedDataStore uses the same helper and retains a successful-load byte token. Missing/unavailable/corrupt cannot silently authorize write. Replace Bool-only hidden errors with typed success/conflict/unavailability results and an injectable explicit URL for tests. Preserve current JSON fields.

ViewModel retains its last committed snapshot separately from editable published arrays. All save paths first attempt coordinated shared persistence; only after success update local UserDefaults, widget/notification state and success messages. On failure preserve the attempted edit for recovery, restore committed displayed state as appropriate, and publish an actionable error; never log successful save or close an editor as if saved. A stale conflict offers reload/discard/reapply through a new current snapshot, never force overwrite. External-change notification must not silently replace an open editing baseline: mark newer data available and keep its old expected token until explicit reload. Reload invalidates active editor generation so a pre-reload form cannot subsequently commit against a new token. Add/edit sheets check save result before dismissal; chained recurrence/restore operations stop on failure and do not announce completion. No notification/backup/legacy-key deletion from an uncommitted or failed load/migration.

Tests inject temporary store/UserDefaults and effect counters; no iCloud container, notifications, widgets, backups or screen access. Prove app loads A, CLI commits B, app attempts C: conflict preserves B and makes no side effects. Prove explicit reload allows a new edit with B retained. Prove unavailable/corrupt load preserves local backup and does not initialize shared empty data; failed save retains recoverable edit and emits no success/dismissal signal. Test editor-generation invalidation and grouped add/repetition failure handling. Compile actual app callers; run iOS unit tests through Understudy on a supported headless destination, preserving any runtime/host gap explicitly. Storage helper passing alone does not satisfy app acceptance.

- The file `reports/session-storage/APP-VALIDATION.md` exists.

## Step 4: Cross-surface acceptance and delivery

Run full relevant CLI/store and actual app tests/compile after final changes. Independent Astra and Fable source reviews, committed judge and canonical gate. Document operation commands, inputs/outputs, approval boundaries, conflict recovery, unavailable placeholder behavior and installed/fresh-client gaps. Stage commits may be separate, but do not advertise full safe management until app and CLI integration acceptance is delivered. No installed route/deployment or real record acceptance is implied.

NSFileCoordinator/local locks protect cooperating local access and stale local snapshots. They do not provide distributed linearizability or promise conflict-free iCloud eventual synchronization across offline devices. If iCloud reports unresolved versions, surface conflict rather than claiming authoritative health; do not resolve/delete remote versions in this slice. Actual device/cloud availability remains separate from temporary-file acceptance.

- The file `reports/session-storage/DELIVERY.md` exists.
