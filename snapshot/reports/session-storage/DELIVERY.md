# DeadlineCalendar storage and session commands

The app and command-line tool now share coordinated local storage. A stale app save refuses to overwrite newer work and retains the attempted edit for recovery. The command-line tool supports exact-target deadline reads, additions, updates and removals with approval and retry checks. This is the isolated implementation; it has not been installed or integrated into the primary checkout.

## Original promises and evidence

| Original step | Delivery and evidence |
|---|---|
| Shared transaction and availability | SnapshotFile.swift is used by both clients. Reads distinguish absent/unavailable/unsafe/corrupt state; changes compare prior bytes under coordination, and no-ops preserve bytes. The retained baseline two-writer failure and nine Swift tests cover stale writes, failed mutations, lock recovery, selected files and unsafe paths. |
| Complete transactional CLI | Exact-ID read/add/update/delete, approved revision-bound removal preview, idempotent addition and repeated deletion. Ten actual CLI fixture tests cover CRUD/readback, consent refusal, wrong/ambiguous IDs, corrupt/missing documents and eight concurrent writers. See CLI-VALIDATION.md and docs/SESSION-CRUD.md. |
| App conflict and ordering | SharedDataStore/ViewModel save shared state before cache/effects. Failure preserves pending edits, reload invalidates old editor generations, caller dismissal follows successful persistence. Final14actual iOS tests and compiled callers passed; separate native app/CLI and whole-ViewModel independent probes supplement them. See APP-VALIDATION.md. |
| Cross-surface acceptance | Independent Astra candidate03 and Fable03 source reviews passed with documented nonblocking limits. Final iOS run bound all21reviewed hashes; retained nine Swift and ten CLI tests use unchanged candidate01 CLI/helper source. Committed review and the original gates must pass before final closure; receipts are recorded separately after the source commit. |

## What remains outside this build

No real deadline, iCloud account or historical dataless file was read or changed. No installed CLI, published route, fresh Codex/Claude invocation, physical-device test, offline iCloud synchronization or visible editor walkthrough is claimed. The lock/coordination protects cooperating local writers, not a globally instantaneous database across offline devices. User review and deployment remain with the parent. Add/remove command flags acknowledge actual user approval; they do not grant it.

Other documented limits: attempted edits remain in memory rather than a durable recovery queue; multi-selection app deletion can partially complete before a later failure; the lock file may be visible in synced Documents; arbitrary external fractional timestamp formats are unsupported; CLI/app standalone-project ordering can differ. These nonblocking findings were retained in REVIEW-DISPOSITIONS.md rather than changing reviewed scope.

## Build identity

Original plan docs/BUILD-SESSION-STORAGE.md; manifest build-BUILD-SESSION-STORAGE-4d4889c6; build0ce3c0c89cab1aeb1740; session01a0fcb2-7788-7d21-9627-c24c34f60149-deadline-storage. No plan rewrite, reseal, replacement manifest or scope reduction was used. No slice-specific saved procedure could be located during resumption; the broad SessionManual audit procedure was left untouched.

## Source completion

Reviewed source is committed as73e3814; evidence-only header/declaration correction is dfa9a8d633ec4afe80dd65af5a4d67f5b482a99a. Committed Understudy review diffjudge-dfa9a8d6 reports Informational/all checks pass ($0.0692). The original checkpoint advanced through every promise, and original canonical run run-1791310820-36645 passed with lifecycle complete and ALLOW_COMPLETE at this exact source commit. The initial committed-review Block and restricted-permission Swift checkpoint failure remain preserved. No reviewed runtime/test bytes changed. These results complete the isolated build, not the broad catalogue capability or deployment.
