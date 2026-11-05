# Candidate03 independent source review: PASS; final app acceptance PENDING

All hashes match `candidate-hashes-03.json`. No remaining source blocker found within the bounded shared-storage/save scope. This does **not** complete app acceptance: the final14 actual iOS tests and final caller compile remain held for host load. Earlier app runs do not cover every final correction.

The initial BLOCK findings are retained in astra-01, astra-02-fractional-date and astra-caller-audit. Corrections reviewed in actual code:

- SharedDataStore.saveSnapshot binds its loaded target, creates only the normal default Documents folder after successful missing read, and leaves arbitrary selected paths/unavailable stores alone. It canonicalizes serialized content before no-op comparison and preserves previous bytes/metadata.
- ContentView DeadlineViewModel installs successful serialized readback; unchanged saves do not emit cache/notification success effects. Failed saves preserve the attempted snapshot and restore committed display state.
- ProjectEditorView Save Trigger Date now returns the actual Bool, closes only on success, and retains a visible error notice.
- updateNotifications requires current valid loaded state, a committed snapshot and no active batch. Failed load/save or external-change notice invalidates notification readiness; injected observer executes before the disabled platform boundary for safe tests.
- Legacy templates accept an absent templateTriggers field, but present malformed values still fail. SavedProjects is read without deleting its key. Missing trigger dates are calculated before the single coordinated commit, retaining template-offset/default behavior. Existing bad/ambiguous caches do not become empty initialization.
- Other restore/template/settings/delete caller findings and limits remain recorded in astra-caller-audit. No new unconditional success/dismissal path found.

## Independent execution

`astra-model-final-01` PASS18.497seconds, no timeout/truncation, runs the entire actual ViewModel class extracted before the view declarations, with real maintained Models/SharedDataStore/SnapshotFile and only disabled-backup stub. Four new sequences verify present-malformed legacy metadata preservation/no effects; fractional-date no-op byte/cache/effect stability; restore-shaped stale write preserving remote bytes and pending draft; explicit reload retaining the failed attempt and invalidating editor generation, then notification suppression after external notice. It uses temporary files and a private UserDefaults suite, effects disabled and an injected scheduler counter. This is actual model logic execution, not a source-pattern test; it is still not full iOS/SwiftUI execution.

Earlier independent CLI edges pass4tests1.074seconds; default/explicit/unavailable store boundaries pass12.73seconds. Their original failure receipts remain. The owner's legacy red/green evidence was read, not relabelled as independently executed.

No production or owner test files changed by this reviewer. No real records, notifications, iCloud hydration, screen use, installation or provider requests. Source-only PASS must not be substituted for the outstanding final actual app run.

## Current source citations

- `DeadlineCalendar/SharedDataStore.swift:160` — `func saveSnapshot`
- `DeadlineCalendar/SharedDataStore.swift:171` — `let canonical =`
- `DeadlineCalendar/SharedDataStore.swift:189` — `private func prepareInitialDocumentsDirectory`
- `DeadlineCalendar/ContentView.swift:117` — `struct LegacyCompatibleTemplate`
- `DeadlineCalendar/ContentView.swift:145` — `private func migratingTriggerDates`
- `DeadlineCalendar/ContentView.swift:162` — `func reloadCurrentData`
- `DeadlineCalendar/ContentView.swift:221` — `func saveAll`
- `DeadlineCalendar/ContentView.swift:1366` — `func updateNotifications`
- `DeadlineCalendar/ProjectEditorView.swift:363` — `if saveTriggerDate()`
- `DeadlineCalendar/ProjectEditorView.swift:377` — `private func saveTriggerDate`
