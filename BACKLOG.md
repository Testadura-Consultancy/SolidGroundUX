# SolidGroundUX Framework — Backlog

Last reviewed: 2026-11-02

This file tracks **outstanding work**, not completed changes. See [CHANGELOG.md](CHANGELOG.md) for delivered functionality. The Framework source-documentation and illustration reviews are complete; release integration and regression testing remain.

## Before the 2.1 release

- [ ] **Integrate the canonical guard fix:** apply the prepared section-marker correction to `common/ui-dlg.sh` and `common/ui.sh`, rerun canonical normalization across the complete Framework and then repeat SDK release preparation. Isolated normalizer and syntax checks passed; a successful full release run has not yet been verified.
- [ ] **Consolidated Setup regression:** test fresh setup, first installation, local/GitHub updates where available, product removal and rollback; confirm the external `sgnd-setup.cfg` catalog and first-install defaults without a preinstalled Framework.
- [ ] **Framework integration checks:** confirm `SGND_SHARE_DIR` in installed and staged roots, permissions repair, DataTable colors across themes and explicit per-table overrides, and integration with the current MCM and SDK.

## Deferred

- [ ] **Universal Esc cancellation:** review cancellation propagation and status reporting through nested workflows when revisiting menu UX. Not a 2.1 release blocker.
