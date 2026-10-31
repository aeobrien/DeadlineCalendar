# Roadmap

## Next Up

| Task | Milestone | Phase | Status | Effort |
|------|-----------|-------|--------|--------|
| (Phase 3 complete — back to maintenance) | | | | |

---

## Phase 1: Core Implementation
**Status:** Done
**Definition of Done:** App is usable for managing recurring monthly delivery deadlines

### 1.1 — Deadline Engine
**Status:** Done
**Priority:** High
**Definition of Done:** Enter one date, get all sub-deadlines calculated

| # | Task | Status | Effort | Deadline | Notes |
|---|------|--------|--------|----------|-------|
| 1.1.1 | Delivery date entry and sub-deadline calculation | Done | Deep Focus | | |
| 1.1.2 | Widget extension | Done | Deep Focus | | |
| 1.1.3 | Backup management | Done | Quick Win | | |

---

## Phase 2: Maintenance
**Status:** In Progress
**Definition of Done:** Ongoing — fix bugs and improvements as needed

### 2.1 — Bug Fixes and Improvements
**Status:** In Progress
**Priority:** Normal
**Definition of Done:** Ongoing

| # | Task | Status | Effort | Deadline | Notes |
|---|------|--------|--------|----------|-------|
| 2.1.1 | Address issues as they arise | In Progress | Quick Win | | Maintenance mode |
| 2.1.2 | October 2026 session-storage hardening (builds 6–7): reliable iCloud hydration, declared container, stale-write protection, save-before-effects ordering, Admin month-end rolling, restore recurrence preservation and replacement confirmation | Done | Deep Focus | 2026-10-30 | Builds 6–7; see `docs/BUILD-SESSION-STORAGE.md` and `reports/session-storage/` |
| 2.1.3 | Persist an attempted edit after a failed save so it survives quitting | Todo | Normal | | Gap 4: the in-memory pending snapshot is lost on quit |
| 2.1.4 | Make multi-select deletion all-or-nothing | Todo | High | | Gap 7: individual deletes can leave a partial selection removed |
| 2.1.5 | Clarify or remove the CLI delete preview recurrence-siblings field | Todo | Low | | Gap 8: exact-ID delete always reports `removesRecurrenceSiblings: false` |
| 2.1.6 | Verify real iCloud/device sync and current installed-app behaviour | Todo | High | | Gap 9: cross-device sync, remote-version handling, synced lock visibility and current device interaction remain unverified |

---

## Phase 3: CLI & Integration
**Status:** Done
**Definition of Done:** CLI tool and shared iCloud data layer enable two-way sync between app and command line.

### 3.1 — Shared Data Layer & CLI
**Status:** Done
**Priority:** High
**Definition of Done:** CLI can read/write app data; changes sync via iCloud.

| # | Task | Status | Effort | Deadline | Notes |
|---|------|--------|--------|----------|-------|
| 3.1.1 | Build deadline-cli (list, status, complete, trigger, adjust, export) | Done | Deep Focus | | Swift Package with ArgumentParser |
| 3.1.2 | Add shared iCloud JSON data layer (SharedDataStore.swift) | Done | Deep Focus | | Replaces UserDefaults as primary store; UDs kept for widget |
| 3.1.3 | Add SharedDataStore.swift to Xcode project | Done | Quick Win | | pbxproj manual edit |
| 3.1.4 | Add `add` command to CLI for standalone deadlines | Done | Quick Win | | |
| 3.1.5 | Add .gitignore to CLI | Done | Quick Win | | |
| 3.1.6 | Harden CLI shared-file session commands (`--data-file`, idempotent add, revision-locked delete) | Done | Deep Focus | 2026-10-30 | Landed in build 7 |

---

## Reference

### Status Values
| Status | Meaning |
|--------|---------|
| Todo | Not yet started |
| In Progress | Actively being worked on |
| Blocked: [reason] | Cannot proceed — reason is one of: poorly-defined, too-large, missing-info, missing-resource, decision-required |
| Waiting | User's part done, waiting on external input |
| Done | Complete |
| Dropped | Deliberately abandoned |

### Effort Types
| Type | Description |
|------|-------------|
| Deep Focus | Sustained concentration, problem-solving, design work |
| Creative | Open-ended, generative, exploratory |
| Administrative | Organising, documenting, updating, filing |
| Communication | Discussions, reviews, feedback |
| Physical | Hands-on work, building, soldering |
| Quick Win | Small, low-effort, momentum-building |

### Priority
High / Normal / Low — milestones only. Tasks inherit from their milestone unless overridden.
