# CLI evidence

Baseline4857669's isolated two-process probe returned success for both updates but retained only one (`concurrency-red-01`, FAIL14.402s). Its original DataStore source is now explicitly loaded from that commit, so later runs cannot accidentally test the repair as baseline.

Final actual CLI fixture suite (`cli-final-01`) passed10 tests2.836s. It launches the built maintained command with an explicit temporary JSON file on every call. Cases cover full exact-ID CRUD/readback, idempotent additions, approval refusal, stale deletion approval, wrong IDs/dates, ambiguous/duplicate targets, preserved recurrence siblings, repeat deletion, absent/corrupt files, human/machine read formats, and eight simultaneous independent writers retaining all eight changes.

`cli-expanded-red-01` retained the valid empty-document addition failure. The repaired default addition creates the Standalone Deadlines container within that same approved transaction; `cli-expanded-green-01` and `cli-final-01` pass. No missing file is initialized by the CLI.

`cli-final-build-01` passed9 Swift store/helper tests14.836s. They cover compare-before-replace, no-op byte/mtime stability, throwing mutation/lock recovery, explicit-file isolation, unavailable metadata, redirected data/lock refusal and target preservation.

`cli-green-01` was an actual sandbox file-write refusal, not a production PASS. The unchanged suite passed through normal outer host permission (`cli-green-02`). Earlier SwiftPM sandbox/compile failures remain under storage-red/green and datastore-red directories. Child compiler sandbox settings were not disabled.

No real iCloud placeholder was opened, hydrated or written. No installed route/fresh-client/live CRUD claim follows from this evidence.
