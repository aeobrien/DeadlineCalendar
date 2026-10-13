# Install and recover DeadlineCalendar safely

This is a proposed rollout, not a completed installation. Candidate03 has two source reviews; final actual iOS tests, commit and completion gates are pending. Do not install this candidate as accepted software yet. Root owns integration and shared session instructions.

## What exists

The source produces the iPhone/iPad app `AOTondra.Deadline-Calendar`, version 1.0 (build 1), and a separate macOS 13+ Swift CLI. The checked Mac Applications folders and normal CLI locations contain neither installed product. The simulator artifact is also 1.0 (1), but does not establish the version on a physical device. No physical device was queried.

The app resolves its signed iCloud container through Foundation. Entitlements retain `iCloud.$(CFBundleIdentifier)` and app group `group.com.yourapp.deadlines`. Do not silently rename these: that can select different existing data. The Mac CLI's default is `/Users/aidan/Library/Mobile Documents/iCloud~AOTondra~Deadline-Calendar/Documents/DeadlineCalendar.json`; backup reads use the adjacent DeadlineCalendarBackups folder only when the shared file is genuinely absent. The current file is a dataless placeholder (metadata inspection only). Missing download availability is not an empty registry.

## Release sequence

1. Complete final native acceptance and existing build gates; record the final source commit and candidate hashes. Root integrates that exact reviewed commit into the maintained repository, preserving other work. Recheck any integration delta before packaging.
2. Build one CLI artifact from that commit when host load permits. The following is a future release command, not executed by this plan:

   `swift build --package-path /Users/aidan/Dev/DeadlineCalendar/deadline-cli --configuration release`

   Record its SHA256 and exact compiler/platform in the release receipt. The release binary is `deadline-cli/.build/release/deadline-cli`. Use that binary directly from any working directory; do not use `swift run` for normal session operations.
3. Install into a versioned, user-owned directory such as `/Users/aidan/.local/lib/deadline-cli/REVIEWED_COMMIT/deadline-cli` with mode0755. Keep its instruction copy, source commit and binary digest beside it. Create `/Users/aidan/.local/bin/deadline-cli` as an atomic symlink replacement to that exact artifact; first record any existing target and refuse to overwrite an unrelated regular file. Use an absolute path in both client instructions so shell PATH differences cannot select an old executable. This introduces no daemon, gateway or network service.
4. Verify the installed artifact with `--help` and a disposable explicit-file fixture before accessing user data. Verify the same binary digest and that list/export work outside the source checkout. Do not run default-mode smoke tests while its real JSON is unavailable.
5. Build/archive the iOS app from the same integrated commit through the project's existing signing and deployment setup after final tests. A future archive command is `xcodebuild -project DeadlineCalendar.xcodeproj -scheme 'Deadline Calendar' -configuration Release -destination 'generic/platform=iOS' -archivePath /private/tmp/DeadlineCalendar-REVIEWED_COMMIT.xcarchive archive`. It requires the existing signing identity/provisioning; do not change entitlements or enable automatic provisioning changes to force it through. Simulator output cannot be installed as the phone app. Record the actual signed version and device/distribution target before a separately authorized device update. Existing source version1.0/build1 is not a new distributable build number: determine the installed/distributed version and choose the next build number at release time.
6. Update the app in place using its existing distribution channel. Do not uninstall it to install this build: uninstalling may discard local caches. The exact physical device and existing distribution channel remain unverified and must be identified before an install command is issued. No device ID, signing approval or distribution mechanism is invented here.
7. Only after installation and acceptance should root publish the verified guide to the shared manual for Claude and Codex. The candidate guide can be explicitly read now, but that is not evidence of ordinary installed discovery.

## Real-data preflight and permissions

A later authorized real-use session must confirm the correct account/container, current app version, availability and unresolved file conflicts before inspecting records. The metadata-only probe here did not request hydration or cloud permission. If a file is unavailable, let the user make it available through the normal system flow; do not create an empty replacement, restore a backup automatically, or broaden permissions. A normal read request does not authorize adding/removing deadlines. The agent must obtain approval for each real addition or the complete exact removal preview; ordinary edits have no extra approval rule.

Before a physical rollout, arrange a verified recovery copy through the existing supported backup/export workflow once data is available and permission covers that access. It contains private records and belongs in a user-approved private location, never these source/evidence reports. A metadata-only size is not backup proof. Never copy a dataless placeholder and call it a verified backup.

## Rollback

Record the previous CLI link and signed app artifact before replacing either. Restore the previous CLI symlink atomically if packaging/startup fails; if that previous release lacks stale-write protections, disable session mutations and allow only verified read-only use until the corrected release is restored. Do not advertise a return to unsafe writers as a safe rollback.

For an app problem, stop new edits, retain the attempted edit via the supported copy notice where available, and restore the prior signed application through the existing distribution channel without deleting its container. An older app may lack conflict protection, so do not mix its writes with the new CLI. Code rollback never restores old JSON over newer deadlines. Data recovery is a separate explicit action: inspect current data and the selected verified backup, explain what would change, obtain approval for any additions/removals, and use the supported restore path. Preserve newer data and unresolved versions; never automatically delete conflict versions, lock files or caches.

## Limits

Local cooperating writers are protected; disconnected devices are not a distributed transaction system. Physical device behavior, actual iCloud synchronization, visible editor interaction and ordinary fresh-client discovery remain separate acceptance steps. Existing multi-selection deletion can partially succeed across separate saves. The stale backup-only description in deadline-cli/NOTES.md is not the current operation contract; use docs/SESSION-CRUD.md and the reviewed maintained source. A narrow documentation correction can be integrated by root without inventing a new transport.

## Exact future CLI cutover commands

After root supplies the accepted commit and verifies the release binary, use the following from the integrated primary checkout. This block is a plan, not an executed installation. Replace REVIEWED_COMMIT with its full accepted hash; stop if HEAD differs. The script refuses an existing unrelated regular command file and preserves the former symlink in a receipt.

```sh
python3 - REVIEWED_COMMIT <<'PYINSTALL'
import hashlib, json, os, pathlib, shutil, subprocess, sys
commit = sys.argv[1]
repo = pathlib.Path('/Users/aidan/Dev/DeadlineCalendar')
assert subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip() == commit
source = repo / 'deadline-cli/.build/release/deadline-cli'
release = pathlib.Path('/Users/aidan/.local/lib/deadline-cli') / commit
link = pathlib.Path('/Users/aidan/.local/bin/deadline-cli')
if os.path.lexists(link) and not link.is_symlink():
    raise SystemExit('Existing command is not a symlink; preserve it for an explicit migration.')
previous = os.readlink(link) if link.is_symlink() else None
release.mkdir(parents=True, exist_ok=False)
artifact = release / 'deadline-cli'
shutil.copy2(source, artifact)
artifact.chmod(0o755)
shutil.copy2(repo / 'docs/client-access/SESSION-GUIDE.md', release / 'SESSION-GUIDE.md')
(release / 'install-receipt.json').write_text(json.dumps({'commit': commit, 'sha256': hashlib.sha256(artifact.read_bytes()).hexdigest(), 'previous_link': previous}, indent=2))
link.parent.mkdir(parents=True, exist_ok=True)
pending = link.with_name('deadline-cli.next-' + commit)
pending.symlink_to(artifact)
os.replace(pending, link)
PYINSTALL
```

If the copy/check fails before replacement, the old command remains selected. Preserve the incomplete version directory for diagnosis; do not reuse its name silently. A subsequent user-scope rollback reads that receipt, verifies the saved previous artifact still exists, creates a new temporary symlink to it and atomically replaces only the command link. If no previous link existed, withdraw the new command rather than selecting an unverified old build. Rollback changes command selection only; it must not touch the shared JSON or local caches.
