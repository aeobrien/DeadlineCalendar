# Independent Astra review — candidate 01: BLOCK

This reviews actual app storage, CLI, model save paths and editor/restore callers against BUILD-SESSION-STORAGE.md. It does not claim screen acceptance, real iCloud availability or deployment. The owner has accepted the first two defects and is repairing them; this initial finding record remains unchanged.

1. **First initialization fails when the container exists but Documents does not.** `DeadlineCalendar/SharedDataStore.swift:48` resolves Documents without creating it (correct for reads), but `SnapshotFile.update` opens its sibling lock before a write-only initialization path creates that directory. An actual compiled SharedDataStore probe reads absence successfully, then save fails ENOENT. Default first launch needs a controlled initialization branch; explicit arbitrary paths and unavailable/corrupt stores must continue refusing unsafe initialization.
2. **An unchanged app save changes metadata and invalidates another window.** `DeadlineCalendar/SharedDataStore.swift:165` stamps Date/app and re-encodes unchanged content. The actual probe loads the same document in two stores, saves unchanged contents in one, verifies bytes change, then observes conflict from the other unchanged writer. This violates the plan's no-op promise and introduces avoidable conflicts.
3. **Trigger date editor closes and logs success after a failed save.** `DeadlineCalendar/ProjectEditorView.swift:362` calls saveTriggerDate and unconditionally hides the sheet at line364. The helper ignores updateTrigger's Bool at line386 and logs Updated at line387. A stale or unavailable store returns false, but the caller follows the success path. This must propagate the result like the repaired project/template editors. This finding is source-traced; no UI execution claimed.

## Executed independent evidence

`astra-probes/StoreEdges.swift` compiles the actual maintained Models, SnapshotFile and SharedDataStore. `astra-store-edges-02/cli-run-result.json` records native temporary-file execution: 7.581 seconds, exit1, no timeout/truncation. It reproduces missing-parent failure, unchanged-byte replacement and resulting second-window conflict. The initial sandboxed run `astra-store-edges-01` failed native file coordination and is retained separately; it is not product-defect evidence.

The explicit-URL missing-parent case diagnoses the shared mechanism; final positive default initialization needs injection of an actual default container resolver, so arbitrary explicit paths do not silently start creating folders. The owner is adding that distinction.

## Reviewed paths and remaining verification

Reviewed entire SnapshotFile, SharedDataStore, DataStore, CLI; initial/current load and saveAll/performChanges; direct add/project/template/restore Bool chains; trigger/recurrence save grouping; both clipboard restore views and iCloud restore result check. Legacy malformed/conflicting caches now stop without deleting originals; this is conservative rather than choosing an ambiguous winner. The final app compile/unit test must run after fixes and include the fresh per-window store constructor. Broader independent CLI checks and final source-bound verdict follow candidate freeze. Root's supplied leads are credited for first-launch and no-op hypotheses; the compiled reproductions are independent.
