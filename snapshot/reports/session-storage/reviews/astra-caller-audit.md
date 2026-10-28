# Remaining caller audit (pre-final freeze)

Source audit, not screen execution. Initial failures remain in astra-01.md and astra-02-fractional-date.md.

## Further concrete failure path

Settings appearance can reschedule notifications after a failed initial load. `BackupRestoreViewRedesigned.swift:383` calls loadNotificationTime on appearance; changing its initial Date state reaches the onChange handler at393–394, which calls viewModel.updateNotifications. The legacy settings view has the equivalent path at126–131/139. `ContentView.swift:1312` initially guarded only effectsEnabled. `scheduleDailyNotifications` at1214 removes the existing daily-deadline-reminder before scheduling from current arrays, even when no snapshot ever loaded successfully. Thus merely opening Settings after a corrupt/unavailable startup can replace the previous reminder with “No upcoming deadlines.” This violates the promised failure-effect boundary. Owner notified; no real notification API was invoked to reproduce it.

## Other callers reviewed

- Both clipboard restore actions set all candidate arrays/settings, call saveAll once, show failure and return before success. iCloudBackupManager.restoreFromBackup throws when saveAll fails; iCloudBackupRestoreView catches and keeps its view open, dismissing only on successful await. No hidden success branch found.
- Project add, standalone add and main project edit group recurrence changes in performChanges, and dismiss only on the resulting Bool. Template add/update/update-and-sync similarly guard dismissal. Trigger-date picker originally missed that guard; owner repaired the specific path.
- Template manager delete, completed project delete, trigger activate/deactivate/delete, and all-deadline row removals do not dismiss a saved editor or announce completion after the call. Their visible data follows the model, which restores committed values on failed save. The apparent placeholder template editor Save path is inside a block comment and is not executable.
- Multi-selection deletion loops remain separate commits and can partially complete if the store changes between iterations; this is existing behavior and is not claimed as an atomic bulk-operation API by this slice. Do not describe it as such.
- Color and notification-format bindings write through updateColorSettings/updateNotificationFormatSettings; published model rollback preserves the last committed values on failure. Legacy notification timing/frequency/count are separate UserDefaults preferences, not fields in the shared AppSettings format. Their effect call still needs the committed-load guard described above.
- Explicit test-notification and manual backup creation are user-triggered separate operations; this review did not invoke them or reinterpret them as automatic successful shared saves.

Final runtime verification will cover the corrected actual app model and CLI, using only isolated storage and disabled/injected effects. That execution does not constitute visual acceptance or real iCloud validation.
