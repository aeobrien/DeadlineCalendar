# Proposed remaining low-load CLI checks — not launched

Source hash03 remains frozen. The actual CLI already passed nine Swift helper/store tests, ten maintained CLI fixtures and four additional independent CLI cases; final app corrections do not change the CLI/helper sources. Repeating all existing checks now adds little evidence and consumes host capacity.

The useful untested packaging boundary is running the existing binary outside its checkout. With root's serial test clearance, use a private temporary directory, copy the exact existing binary (verify SHA256), create a synthetic valid JSON fixture and invoke the copied binary from that directory with --help, list --json, export and one exact-ID CRUD sequence including unapproved add/delete refusals. Always pass --data-file; no default iCloud call, compiler, simulator, native client or provider is involved. Confirm the original fixture's unchanged fields, exact created ID and removal revision; verify only the disposable fixture and its lock change. This is relocation/readback evidence for this artifact, not release-build or installed-route proof.

Expected runtime is a few seconds based on existing actual CLI10cases2.836s. No test or copy has run yet under this proposal. After final integration/release build, repeat only the packaging smoke on that release artifact, since the current debug-binary check cannot prove a not-yet-built release.

Root should allocate the short Understudy slot before execution. Current final actual iOS14 acceptance stays pending independently; this check cannot satisfy it.
