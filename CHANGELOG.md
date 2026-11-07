# Changelog

All notable changes to SolidGroundUX Framework are documented in this file.

The format is inspired by *Keep a Changelog* while remaining focused on practical framework development.

## Unreleased

Changes prepared for SolidGroundUX 2.2 R2.

### Added
- Added a unified **Install / Update products** workflow with multi-product selection and a single installation confirmation.
- Added package selection from the latest GitHub release, a specific GitHub release, the latest local package, an archived release ZIP, or a ZIP at an alternate filesystem location.
- Added a paginated selector for archived releases. Alternate-location selection accepts a directory or a specific ZIP, with the canonical releases directory as the default.
- Added multi-product selection for **Remove products**, with one confirmation and Framework removal ordered last.
- Added an optional prompt to copy a standalone `sgnd-setup.sh` into its canonical location; the same copy routine is used automatically by first install and creates missing directories.

### Changed
- Simplified the Setup main menu to **Install / Update products**, **Remove products**, and **Configure GitHub repositories**.
- Made installed-version reporting read the installed product definitions rather than infer the version from the newest archived release.
- Extended local release discovery to include pending and archived release ZIPs.
- Consolidated GitHub repository configuration around packaged defaults and one optional local override, instead of per-project repository URL files or saved-state overrides.
- Improved GitHub release discovery, product-specific ZIP matching and error reporting; highlight newer GitHub versions in the product overview.

### Fixed
- Prevented Setup from saving or loading machine-specific `release-manager.state` inside an implicit development target-root; explicit `--state-root` and live installations retain state persistence.

### Preserved
- Kept the existing First Install packaging, bootstrap, ZIP/TAR extraction, checksum verification, installation engine and manifest-based removal behavior.

## Pre Release 2.2.2630700
[CHANGELOG-History](CHANGELOG-History.md)
