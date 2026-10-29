# SolidGroundUX Framework — Backlog

Last reviewed: 2026-10-29

This file tracks **outstanding work**, not completed changes. See [CHANGELOG.md](CHANGELOG.md) for delivered functionality. The 2.1 implementation work is complete; final review and regression testing remain.

## Before the 2.1 release

- [ ] **Source documentation audit:** review function comments (`# fn:` and template conventions), file headers, prefaces and epilogues against the current implementations; correct inaccuracies without functional changes.
- [ ] **Consolidated regression:** test fresh setup, first installation, local/GitHub updates where available, product removal and rollback; confirm the external `sgnd-setup.cfg` catalog and first-install defaults work without a preinstalled Framework.
- [ ] **Framework integration checks:** confirm `SGND_SHARE_DIR` resolution in installed and staged roots, permissions repair, DataTable colors for every theme and explicit per-table overrides, and integration with the current MCM and SDK.

## Deferred

- [ ] **Universal Esc cancellation:** review cancellation propagation and status reporting through nested workflows when revisiting menu UX. Not a 2.1 release blocker.
