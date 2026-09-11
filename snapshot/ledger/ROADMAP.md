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
