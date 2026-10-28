# Rolling Admin result

Revision: `e5607e2` on `feat/admin-rolling`.

The conversion preview against the supplied copied backup listed 24 Admin projects for removal
and two replacements: October and November 2026. The confirmed apply was made only to a second
copy of that backup. It left 19 non-Admin projects and exactly two Admin projects, ending on 31
October and 30 November.

The app keeps the current Admin plus one editable next Admin. Completing the current project
promotes that next project and creates one more. New occurrences use the calendar month, so the
final deadline stays on the last day and the sub-deadlines retain their 23rd, 27th and 28th days.
`deadline-cli complete Admin <deadline>` targets the visible source Admin and performs the same
roll-forward after its final deadline completes.

Evidence: `swift test --package-path deadline-cli` passed 16 tests; Xcode result
`/private/tmp/claude-501/deadline-admin-recur-final.xcresult` passed 16 tests; Understudy's
`cli-rollover-run/cli-run-result.json` completed all three current Admin deadlines through the
real CLI and asserted the resulting 31 December occurrence. The Fable focused recheck passed.

Follow-up: the app-side promotion does not currently reconcile any notification triggers owned by
the retired current Admin. No trigger was present in the supplied Admin conversion fixture, so it
does not affect the demonstrated migration; review it before adding Admin-specific reminders.
