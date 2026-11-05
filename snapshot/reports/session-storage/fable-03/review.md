**Verdict: PASS (source-only; iOS acceptance not inferred)**

I read the full final source for SnapshotFile, DataStore, DeadlineCLI, SharedDataStore, the ViewModel and the caller diffs. No blocking correctness, data-loss, approval or integration fault found. Material findings and limits below.

**Confirmed against boundaries**
- Transaction: `SnapshotFile.update` compares `expected` bytes inside the coordinated/flocked write; no-op returns `current` without rewriting (fractional/legacy bytes preserved on unchanged save, incl. `saveSnapshot`'s decoded-equality short-circuit); `nil` transform result throws `.missing` so storage can never delete. Lock released via `defer` on all paths.
- Read classification: ENOENT → nil/absent; `SF_DATALESS`/not-downloaded → `.unavailable`; non-regular → `.unsafePath`; unresolved versions → `.conflict`; decode failure propagates as corrupt. `DataStore` explicit-file mode never reaches iCloud/backups; `mutate` never promotes a backup.
- App: `loadSnapshot` resets `hasLoaded` before reading; failed load leaves `hasLoaded=false`, so `saveSnapshot` throws — corrupt/unavailable never authorizes write or empty initialization. `localSnapshot` throws on non-Data/undecodable/conflicting legacy caches, never removes keys, preserves `SavedProjects`, legacy templates without `templateTriggers`, and fails present-but-malformed `templateTriggers`. Trigger-date migration staged before one commit.
- Ordering: `saveAll` succeeds in store before `cacheCommitted` (defaults, commit observer, widgets, notifications); failure restores `committedSnapshot`, retains `pendingSnapshot`, sets `currentLoadAvailable=false`. `updateNotifications` gates on `currentLoadAvailable && committedSnapshot != nil && batchDepth == 0`. `loadInitialData` schedules notifications/backup only after successful reload. External change keeps baseline, flags `newerDataAvailable`; reload rotates `editorGeneration` and `.id()` tears down editors.
- Callers: AddProject/ProjectEditor/Standalone/TemplateEditor/CompletedProjects/BackupRestore(×2)/iCloudBackupManager gate dismissal/success on Bool result; nested trigger date picker (`saveTriggerDate`) propagates. Batching via `performChanges` nests correctly (inner returns true, outermost saves once).
- CLI approvals: `add` requires `--approved` + idempotent by `--id` (identical → success, divergent → refusal); `delete` requires preview revision, `--approved`, checks revision under the lock, reports already-absent without touching others. Title convenience fails on ambiguity; all resolution happens inside `mutate`.

**Material non-blocking findings**
1. `SnapshotFile.update` creates `DeadlineCalendar.json.lock` as a sibling — in default mode that is inside the synced iCloud `Documents` folder, so a stray `.lock` file will sync to the user's iCloud and be visible in Files; it is opened without `O_NONBLOCK`/dataless check. Functionally safe but contradicts "local advisory lock" intent; recommend placing the lock in Application Support/tmp keyed by canonical path.
2. `AddProjectView.saveProject` / `ProjectEditorView.saveProjectChanges`: the early `return` inside the `performChanges` closure (empty title / missing original) makes the no-op save return `true` and the sheet dismisses silently. Button disabling masks the first; the second is a latent silent dismissal.
3. `AddCommand` creates the standalone project with `finalDeadlineDate = due`, whereas the app uses `.distantFuture`; cosmetic divergence in list ordering.
4. `JSONDecoder.dateDecodingStrategy = .iso8601` rejects fractional-second timestamps; fine for files produced by this encoder, but any externally produced fractional date would read as corrupt (no test in this package exercises this).
5. `DeadlineViewModel` is not `@MainActor`; tests run on main, but `SharedDataStore` monitoring callbacks are posted to main — acceptable, noted.

**Scope limits**
- `deadline-cli/Tests/DataStoreTests.swift` and `SnapshotFileTests.swift` are empty in this package; CLI/helper tests are unverified here.
- pbxproj diff does not show the app test file registration (test target pre-exists); assumed present.
- No tests run; iOS/host acceptance remains pending per the brief. No live iCloud/distributed behaviour verified.
