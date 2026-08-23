# Changelog

## 1.0.1

- Hardened write-ahead recovery so incomplete operations roll back only
  journaled settings and committed operations survive stale journals.
- Preserved external changes across baseline restores, conflict resolution,
  preview cancellation, and preview timeout recovery.
- Blocked overlapping preview/conflict mutations and added conflict choices to
  the panel.
- Prevented multi-monitor IPC from applying one profile more than once.
- Added strict persisted-state, journal, profile, path, and adapter validation.

## 1.0.0

- Initial local-first Access Profiles plugin for Omarchy 4.x.
- Added four reversible profiles, a transactional backend, preview recovery,
  external-drift detection, and an anchored bar panel.
