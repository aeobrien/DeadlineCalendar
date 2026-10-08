# CLI relocation acceptance: artifact PASS; final app acceptance pending

The copied existing binary passed 6 meaningful cases through 24 actual CLI invocations from a private directory outside the checkout. Understudy run-02 completed in 3.265 seconds, exit0, no timeout/truncation. Every invocation selected a synthetic --data-file. Cases exercised add approval refusal, exact-ID create/read/edit/delete, identical add retry, stale removal approval, wrong targets/invalid dates, corrupt/missing stores, unapproved deletion, recurrence sibling preservation and repeated deletion.

The source subset matches both candidate01 and current frozen candidate03. The binary SHA256 is 2f8288f58fb2f183d5c7256b858883bd6007a6f3b6535edb53c27b25c12193ea, checked before copying against the earlier rollout metadata and again after copying. Earlier compile evidence did not record a binary digest, so this proves the retained artifact works after relocation; it does not cryptographically certify which source produced that artifact. Current source hashes and that limitation are retained in observations-02/provenance.json. A later release build must capture its own source/binary receipt and packaging smoke.

First run-01 failed five writes because coordinated temporary-file writes were refused under the outer sandbox; its receipt and observer limitation remain in INITIAL-FAILURE.md. One normal require_escalated retry was accepted. No sandbox flags or permission settings inside the product changed. No recompilation, simulator, app/native-client launch, real data, default iCloud path, provider or service was used.

This is not overall completion. Final14 actual iOS tests, final commit/gates, installation and ordinary client discovery remain separate pending work.
