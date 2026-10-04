# Changelog

All notable changes to SolidGroundUX are documented in this file.

The format is inspired by *Keep a Changelog* while remaining focused on
practical framework development.

## Unreleased

## Release 2.1.2627700 

### Added
- Added standalone `sgnd-setup` as the product lifecycle entry point for first installation, local/GitHub updates, rollback, removal, and package management; `sgnd-release-manager` remains available as a compatibility alias.
- Added a product-centric Setup dashboard showing installed, newest local, and newest GitHub releases per known product, with newer availability highlighted.
- Added local package discovery beside the running Setup script and in the canonical releases directory, plus action-scoped selection of another package directory.
- Added canonical `Shortname` support to comment-header metadata. `sgnd_module_init_metadata` now uses the header Shortname when present and falls back to the normalized source filename when it is absent.
- Added metadata-driven current-script aliases so executable metadata such as Title, Description, Version and Build can be derived from canonical parsed header metadata instead of being repeated as hard-coded runtime literals.
- Added configurable `SGND_MENU_Q_EXIT` behavior to the reusable menu layer so applications can disable `Q/q` exit handling while preserving the historical default for other menu consumers.
- Added `sgnd-setup --nuke <yield>` maintenance modes: `1kt` clears generated state/logs while preserving code and configuration, `1mt` removes the SolidGroundUX code installation while preserving configuration/state/logs, and `tsar` removes all SolidGroundUX-owned code, configuration, state, and logs.

### Changed
- Standardized product ZIPs as the release unit: acquisition may come from GitHub, the canonical local package store, or another directory, but all selected packages enter the same validation/install pipeline.
- Replaced the former bundled-release concept with a first-install transport package containing `sgnd-setup.sh` and normal product release ZIPs; the package Version follows Setup while its Build reflects the highest build contained in the bootstrap package.
- Rebalanced the Setup dashboard columns so full product names fit more naturally and Installed/Local/GitHub values display compact Version.Build identities instead of long release basenames.
- First install now discovers adjacent product ZIPs, admits them to the canonical package store, lets the operator select one or more products, installs through the normal package pipeline, and cleans temporary bootstrap files afterward.
- Successful product installs archive the original ZIP beneath the canonical releases archive while retaining extracted internal release history for rollback/removal.
- Package source paths are transient operation input and are no longer restored or persisted as product/repository state.
- Consolidated runtime metadata initialization around the existing comment-header parser and `sgnd_module_init_metadata`, retaining structural `SGND_SCRIPT_FILE`, `SGND_SCRIPT_DIR`, `SGND_SCRIPT_BASE`, and `SGND_SCRIPT_NAME` as executable-context identity while removing redundant duplicated metadata literals.
- Kept early bootstrap metadata initialization explicit for bootstrap/header-parser/definitions/environment files, while later framework libraries continue to self-initialize metadata once the parser is available.
- Changed first-install completion to offer **Setup**, **Management Console**, or **Exit**, with Exit as the default and `Esc` treated as Exit.
- Kept the first-install completion selector framework-independent so bootstrap/recovery operation does not depend on SolidGroundUX UI helpers before the framework is available.
- Management Console applications can now treat `Esc` as the canonical return/exit control while leaving reusable framework menu behavior configurable for other consumers.
- Destructive Setup cleanup now derives its scope using the same physical-path root semantics as the framework locator, so a staged/development `target-root` can be cleaned without touching the host installation. Setup remains framework-independent for these rescue/removal paths.
- Setup removal operations remove SolidGroundUX-owned files and persistent data according to the selected yield but do not attempt to undo operating-system configuration previously applied by SolidGroundUX.

### Fixed
- Fixed comment-header parsing variable shadowing that could prevent parsed banner Product/Title values from propagating correctly into module metadata.
- Fixed non-interactive execution paths that could hang while rendering a title bar through `/dev/tty`; receiver-side execution can now suppress title rendering explicitly with `--no-title`.
- Fixed terminal-width detection fallbacks so framework UI code remains usable when no controlling terminal is available.
- Fixed repeated/non-interactive bootstrap behavior used by deployment receivers so framework startup no longer depends on terminal-only rendering paths.


## Release 2.1.2626712

### Added
- Added configurable warning and error message delays to the Framework globals, with `saywarning` and `sayfail` consuming the configured defaults while allowing an explicit `--delay` override.

### Changed
- Standardized the warning/error delay policy at 0.5 seconds by default; `--delay 0` remains immediate and `--delay -1` waits for a keypress.

### Fixed
- Restored the canonical `sgnd-smoketest` implementation and completed Framework ownership of the public smoke-test command after the product split.

## Release 2.1.2626612

### Added
- Restored the canonical framework locator and library-guard templates lost during the product split.
- Updated the canonical framework locator so development executables can bootstrap `sgnd-exe-common.sh` from the installed Framework when it is not present in the active product overlay.
- Restored the comment-header parser required for module metadata and menu descriptions.
- Moved canonical normalization ownership into the Framework alongside the structures it maintains.
- Added the framework-owned `sgnd-smoketest` public command and standalone smoke-test implementation. The Framework owns framework installation validation and smoke tests; Management Console registration and module validation remain Management Console Modules concerns.
- Added `sgnd_framework_resolve_path` as the common resolver for Framework-owned resources used from Framework, SDK and Management Console development roots. Local Framework resources are preferred only when the contextual root actually contains a Framework; otherwise resolution falls back to the installed Framework.

### Changed

- Completed the product split: the Framework now owns runtime/bootstrap services, reusable APIs, canonical Framework resources and framework smoke testing. The Management Console host/modules are owned by Management Console Modules, while workspace, documentation and release tooling is owned by the SolidGroundUX SDK.
- Kept `SGND_FRAMEWORK_ROOT` as the contextual execution/development root; Framework resource fallback no longer mutates that context or reintroduces the removed application-root model.
- Canonical module metadata now uses the comment header as the source of truth for Version, Build and Description, removing duplicate runtime metadata.
- Framework-owned canonical templates and resources can now be consumed correctly by SDK/MCM tools running from separate non-root development trees.

### Removed

- Removed Framework ownership of `management-console.sh`, `sgnd-console`, Management Console modules, and SDK development/release/documentation commands. Their history remains in earlier releases, but ongoing ownership is now recorded in their respective product changelogs.

### Fixed

- Fixed bootstrap/UI resource resolution after the repository split, including style/palette and license lookup from non-Framework development roots.
- Added the missing bootstrap failure path used by early UI/bootstrap errors.
- Fixed canonical Framework resource fallback so an empty Framework-shaped directory in another product's staged tree is not mistaken for a local Framework installation.
- Fixed module metadata discovery so Management Console modules can remain lazily loaded while their canonical header metadata is still displayed and validated.

## Release 2.1.2626021

### Added

- Added multi-product documentation collections to `doc-generator.sh`. Documentation runs can discover products beneath a development root, select one or more products, and designate a primary product as the lead product for ordering, defaults, and deterministic first-wins behavior.
- Added per-product documentation exclusions through `<product>.docignore`. User configuration takes precedence over system configuration; when neither exists, an example user ignore file can be created without overwriting existing configuration and without writing during dry-run.
- Added duplicate documentation-module detection across selected products. Duplicate module basenames are reported and later occurrences are skipped so combined collections remain deterministic.
- Added per-product documentation asset collection from each selected product's canonical `usr/local/assets` directory. Assets are merged into the generated site's `assets/images` directory, with duplicate filenames retaining the first selected product's asset and producing a warning.
- Added an explicit documentation collection/output model: collection name and output root can be persisted, while the final output directory is derived from a normalized lowercase collection slug and remains overridable per run.
- Added `. Table` / `. EndTable` as an explicit documentation table construct. Table cells are separated with `::`; the first row is rendered semantically as the table header and subsequent rows as table body rows. Documentation style hints remain applicable to table rows and are passed through to renderer styling where implemented. Blank-line table termination remains supported for backward compatibility.
- Added table syntax documentation to the Documentation Generator preface and expanded `doc-template.sh` with a compact documentation-dialect reference covering section indicators, documentation item/header indicators, style hints, image blocks, and table blocks.
- Added multi-product release preparation to `prepare-release.sh`. A release run can select multiple development products, choose a primary product, create individual product packages, and create a combined bundle from the same preparation workflow.
- Added per-product release metadata handling in `prepare-release.sh`: each selected product carries its own product identity, version, and Version/Build update policy. Version is entered per product; Build continues to use the standard day-of-year plus hour build number.
- Added product ownership collision detection while assembling bundles. Conflicting paths owned by different selected products now stop preparation with the primary product, companion product, and conflicting file reported explicitly.
- Added package discovery to `release-manager.sh`, allowing the Release Manager to select between bundled and individual product packages and to maintain project-specific release/archive state.
- Added GitHub release discovery for project packages using each project's configured repository.

- Added development-context indicators to `management-console`, showing the console host and console application as `DEV` when running from non-production roots while remaining hidden during normal production use.
- Added console application context detection to `management-console`.
  - Introduced `SGND_CONSOLE_APP_ROOT`, derived from the active `--appcfg` path.
  - Added application-local executable resolution so development console modules can use executables from the same staged project tree while continuing to use the installed SolidGroundUX framework runtime.
  - Added development-context indicators to the console index when either the console host or console application is running from a non-production root; indicators remain hidden in normal production use.

### Changed

- Reworked the interactive documentation-generator workflow around product discovery, product selection, primary-product selection, generation mode, source selection, collection metadata, output location, and behavioral flags.
- Documentation source directories are now derived from the selected products rather than entered independently. The primary product is processed first and supplies the lead collection defaults while companion products retain their own identities.
- Documentation generation now distinguishes creating a Full collection from updating one: a new Full collection starts clean, while a Full update loads the existing cache and refreshes the selected products without clearing the collection. Selected and Changed modes update only affected cached modules; Render mode bypasses source parsing.
- Changed-mode documentation generation now uses Git changes relative to `HEAD`, including untracked matching files.
- Documentation image captions are being standardized as descriptive, unnumbered captions rather than manually maintained figure numbers.
- Updated the SDK Documentation Generator, SolidGroundUX framework, Deployment, and Management Console Modules prefaces for the current 2.1 architecture, including product-aware documentation/release workflows, framework ROOT/NON-ROOT behavior, and clearer Management Console module/action structure.
- Documentation assets are no longer assumed to live beneath a SolidGroundUX-specific library path; each selected product contributes assets from its own canonical `usr/local/assets` directory.
- `prepare-release.sh` now derives bundle Version and Build from the primary product; bundle identity is never prompted or maintained separately.
- Product names used in generated release filenames are normalized to filesystem-safe names, including replacement of spaces with hyphens, while the human-readable Product value remains unchanged in package metadata and UI.
- Release Manager package selection uses package metadata rather than asking the operator to enter Version or Build values.
- Release Manager repository values are retained as project/package state and reused when that package is selected again.
- Release Manager project handling now supports both the SolidGroundUX framework and separately released SolidGroundUX applications such as Management Console Modules through the same lifecycle engine.

- Changed comment-header section parsing to terminate at the first empty comment line, preventing subsequent header sections from being included in multiline metadata such as `Description`.
- Changed `management-console` executable resolution to prefer the active console application's executable directories before falling back to framework-owned executable locations.
- Changed `create-workspace` to mark canonical templates copied into a new workspace with a caveat identifying them as workspace-local canonical starter templates that should only be changed deliberately.
- Kept the installed canonical template sources unchanged; the caveat is added only to the copies placed in the newly created workspace.

# Build 2.1.2625621

### Changed
- Executable rights granted on release-manager and motd

# Build 2.1.2624123

## SolidGround Framework

### Added
- Added canonical bootstrap source normalization for release preparation. Executable `_framework_locator` functions and reusable-library guard sections can now be materialized from canonical source fragments instead of being maintained independently across the tree.
- Added argument-parser support for extracting recognized framework built-ins while preserving script-specific options and positional arguments in their original order for the later script-level parse.

### Changed
- Simplified executable bootstrap root discovery for the 2.1 architecture. `SGND_FRAMEWORK_ROOT` is now derived directly from the physical script path using the last canonical top-level `usr`, `etc`, or `var` component, allowing the same bootstrap code to resolve both installed `/` and staged/development trees.
- Reworked bootstrap argument processing so framework built-ins and script-specific arguments may be freely intermixed; callers no longer need to place framework options before application options.
- Script argument parsing now continues across positional values, allowing valid options to occur later on the command line. The standard `--` marker remains the hard end-of-options boundary and everything following it is treated as positional data.
- Script command-line values are applied after configuration/state loading so explicit CLI values take precedence without a later parser pass resetting previously parsed framework flags.
- Updated bootstrap and argument-parser documentation to describe argument extraction, ordering independence, precedence, preservation behavior, and `--` semantics.
- Framework smoke-test utility actions now continue the numbered menu sequence instead of using `L`, `V`, and `A`, avoiding collisions with framework/console shortcut keys; the timed smoke-test reader now accepts multi-digit selections.

### Repaired
- Repaired project-specific GitHub release checks for separately packaged products after validating repository visibility and repository-specific release endpoints.
- Repaired project package identity so Version and Build are obtained from prepared package metadata rather than being treated as Release Manager input.

- Repaired canonical library-guard normalization so the next top-level source section is detected whether or not whitespace exists before its separator run, preventing sections such as `Minimal UI` from being consumed during normalization.
- Repaired canonical library guards for early bootstrap libraries by making metadata initialization conditional until `sgnd_module_init_metadata` is available.
- Repaired repeated argument parsing that could reset a previously recognized script flag such as `--auto` during bootstrap, causing unattended tools to fall back into interactive behavior.

## Development Tools

### Added
- Added optional canonical-source normalization to `prepare-release.sh`, executed before release metadata processing so generated bootstrap/guard fragments are normalized before checksums and release artifacts are produced.

### Changed
- Canonical normalization skips the canonical fragment directory itself, validates modified shell files with `bash -n`, and reports changes through checksum comparison.
- `prepare-release.sh` invokes canonical normalization in unattended mode and propagates dry-run behavior when release preparation is running as a dry run.

## Release Management

### Added
- Added project-aware release packages. Every release ZIP now carries a `release-package.info` shipping label containing package format, project slug, product, version, build, and release identity.
- Added generic project package support to `release-manager.sh`. Additional projects keep independent release and archive state beneath `/var/lib/solidgroundux/projects/<project>/`, while SolidGroundUX retains its existing release-state layout.
- Added standalone, stateful Release Manager parameters for target root, project, package source, release selector, repository, and state root. Accepted interactive values are reused as defaults on later runs.
- Added a standalone Release Manager UI fallback based on the SolidGroundUX default theme for bootstrap and recovery scenarios where the framework is not available.
- Added opportunistic use of the normal SolidGroundUX UI primitives and active theme when a healthy framework is available at the selected target root.
- Added project selection to the interactive Release Manager while retaining command-line actions for check, download, update, install, rollback, and removal.
- Added package-source installation support so a ZIP file or URL can be admitted and installed directly through the same release engine.

### Changed
- `prepare-release.sh` now resolves project identity from the project definitions file, updates version/build identity in the appropriate definitions file, and packages generic projects without bundling `release-manager.sh`.
- SolidGroundUX release ZIPs continue to include `release-manager.sh` as the first-install bootstrap entry point; generic project ZIPs rely on an already installed Release Manager.
- The ZIP-root Release Manager is now treated as a bootstrap runner rather than the authoritative installed copy. Installing the SolidGroundUX tar establishes `/var/lib/solidgroundux/release-manager.sh`.
- Release Manager startup no longer copies the currently executing script over the canonical installed manager merely because it is running from another path.
- Interactive Release Manager operation is parameter-driven and menu-based; non-interactive arguments select the same underlying menu actions rather than maintaining a separate workflow.
- The SolidGroundUX Management Console now delegates release lifecycle operations to a single **Release manager** menu item instead of duplicating check, download, update, install, rollback, and remove actions.
- Release preparation keeps build output in the workspace release directory instead of duplicating release artifacts into `target-root/var/lib/solidgroundux/releases`; the Release Manager admits package artifacts into managed release state when they are actually acquired or installed.
- Release Manager root handling now distinguishes the running bootstrap copy from the selected installation target. A bootstrap copy defaults the target root to `/` and asks explicitly in interactive mode; an installed canonical manager can derive the default target root from its location.
- The Release Manager remains usable when the framework is absent or damaged: standalone primitives are always available, and framework UI integration is strictly optional.

### Repaired
- Repaired Release Manager self-install behavior that could attempt to copy a development or bootstrap copy over `/var/lib/solidgroundux/release-manager.sh` and fail with permission errors.
- Repaired project-aware package admission so release artifacts are moved only after ZIP extraction into temporary staging, not as an unconditional startup side effect.
- Repaired Release Manager project-menu presentation and product-specific remove labeling after the project-aware refactor.


# Build 2.0.2623817

## Added
- Added root-only **Module metadata** (`M`) to the Management Console index. It shows metadata for modules that have actually been lazy-loaded in the current console session.
- Added reusable `--again` support to `ask_dlg_autocontinue`, allowing **A** to immediately repeat a workflow instead of waiting for the timeout.
- Added Samba share subdirectory management:
  - Create subdirectories beneath selected shares.
  - Accept relative paths such as `Files/Mark` and create intermediate directories.
  - List subdirectories beneath selected shares.
  - Remove selected subdirectories without allowing the share root itself to be removed.
  - Reuse the current share selection; prompt for a share only when none is selected.
- Added Web Server site-management and publishing support:
  - Create, enable, disable, remove, and list Nginx sites.
  - Remove site content independently from site configuration.
  - Publish content from a local directory or a remote machine.
  - Persist publish-source answers as state.
  - Configure a web address (`server_name`) separately from the site name/document-root directory.
  - Publish generated SolidGroundUX documentation through the Web Server module.
  - Register site hostnames in Active Directory DNS when requested.
- Added SQL Server configuration actions for storage, TCP network, memory, service management, firewall, tools, validation, and detailed status reporting.

## Changed
- Improved Management Console numbering so single- and multi-digit selections remain aligned on both module pages and the top-level console index.
- Improved Management Console state-file handling so switching **STANDARD → ROOT → STANDARD** keeps console state owned by the invoking user and prevents root-owned `0600` state files from blocking later writes.
- Main-console and **Manage visibility** `Select option :` prompts now use the active theme label color; typed selections continue to use the active theme value color.
- Web Server management is organized around separate site configuration, site content publishing, and SolidGroundUX documentation publishing concerns.
- Web Server site creation now defaults the web address from the local hostname/FQDN rather than from the site name.
- Web Server publishing no longer treats removed site definitions as publishable targets; publish selections are rebuilt from the current live Nginx site configuration.
- Remote Web Server publishing now supports explicit source host, source user, and source directory values and uses SSH key-based non-interactive access.
- SQL Server storage configuration now shows the directory-selection menu correctly, identifies the actual directory in create confirmations, and asks once whether SQL Server should be restarted after applying all storage changes.
- SQL Server status now reads the persisted `/var/opt/mssql/mssql.conf` settings so configured data, log, backup, and memory values can be shown instead of generic defaults.
- Samba subdirectory creation now inherits the selected share's existing ownership/permission/ACL model instead of assigning ownership based on the directory name.
- Active Directory Management repeat workflows now support **A = another** in addition to the existing timeout repeat behavior.
- Renamed MOTD file to `95-solidgroundux`; `update-motd.d` filenames must be lowercase-compatible with `run-parts --lsbsysinit`, and the SolidGroundUX block is intentionally displayed near the end.
- Added option to create directories, allowing a name, a path, or a comma-separated list as input to the storage module. *DONE*
    - `www` → create under the configured storage root, e.g. `/srv/storage/www`
    - `/srv/storage/www` → use exactly that path
    - `www,logs,backup` → create all three under the configured storage root
    - `/srv/www,/srv/logs` → create the explicit paths as given
    - Mixed input should work too
    - Use `ask_selection` to list existing directories; allow manual entry, and offer to create the directory when the entered value does not exist
- Adapted the filters in `prepare-release.sh` to exclude state, configuration, logging, and archive data.
- Release Manager bootstrap/configuration writing now uses explicit `printf` output instead of a heredoc.

## Repaired
- Repaired SQL Server storage selection where the selection menu was being swallowed by command substitution and only a bare `Selection` prompt remained visible.
- Repaired SQL Server status reporting for configured storage paths and memory values under both ROOT and STANDARD console sessions.
- Repaired Web Server site creation where the site name was incorrectly reused as the default web address.
- Repaired Web Server publishing state so removed sites no longer remain in the publish-site selection.
- Repaired remote Web Server publishing diagnostics around SSH host verification, key authentication, source user, and source-directory availability.
- Repaired Samba subdirectory creation so an already selected share is used directly instead of unnecessarily returning to share selection.
- Repaired console action/module state ownership across privilege switching.

## Verified
- Re-ran end-to-end provisioning from clean clones for `td-pdc`, `td-nas`, `td-sql`, and `td-web`; all four roles were configured successfully in approximately 34 minutes including unattended time, with the active work itself fitting within a sub-30-minute run.
- Verified generated SolidGroundUX documentation can be published through Nginx and reached through an Active Directory DNS hostname.
- Verified SQL Server 2025 installation and runtime status on Ubuntu 24.04, including active service, TCP 1433, configured memory limit, and configured data/log/backup paths.


# Build 2.0.2623404

## Verified
- SolidGroundUX was developed on Ubunto 26.04, Ubuntu 24.04 LTS compatibility verified — SolidGroundUX 2.0 installed and ran successfully.
- SQL Server 2025 module verified end-to-end on Ubuntu 24.04 — repository configuration, engine installation/configuration, tools, validation and status all working; SQL Server active and listening on TCP 1433.
- nginx module verified end-to-end on Ubuntu 26.04 — installation, configuration, validation and HTTP serving working; site-management and publishing capabilities remain limited.

## Changed
- Improved Samba File Server and share-management usability:
  - Removed printer-share validation from the Samba file-server validation path.
  - Added repeat-operation flows for creating and removing Samba shares.
  - Added share selection when removing managed shares.
  - Updated the Samba share manager to use `ask_selection` for share and Active Directory group selection.
  - Active Directory groups are now discovered directly from the directory through LDAP instead of relying on NSS group enumeration.
  - LDAP group discovery uses Kerberos/GSSAPI authentication and disables SASL hostname canonicalization so the registered domain-controller LDAP service principal is used correctly.
  - Active Directory realm names are normalized to uppercase for Kerberos authentication while NSS group identities retain their resolvable `group@domain` form.
  - The share manager now detects a missing Kerberos ticket and interactively authenticates an Active Directory user before querying directory groups.

- Added `R Reset` to the management console, allowing last-run result markers to be cleared for the current module page without affecting results on other pages.

- Moved manual console redraw from `R` to `Ctrl+R`; redraw continues to re-measure the terminal and invalidate layout-dependent caches.

- Updated the console key legend to show `R Reset` and `Ctrl+R Redraw`.

- Added a `--legend` argument to `ask_dlg_autocontinue`, allowing callers to replace the generic key legend with workflow-specific instructions.

- Improved Active Directory Management usability:
  - Added consistent `Q` / Quit handling to framework-owned prompts.
  - Added `--back` support to `ask` so free-text prompts can return cleanly without assigning or validating the entered value.
  - Removed redundant confirmation prompts from user and group creation/deletion flows where choosing the action and selecting/entering the object already expresses intent.
  - Added optional “password never expires” handling during user creation.
  - Added a dedicated “Set password never expires” user action.
  - Added repeat-operation loops for:
    - Create user
    - Delete user
    - Remove user from groups
    - Create group
    - Add users to group
    - Remove group members
    - Delete group
  - Repeat-operation dialogs now use custom legends so timeout and Enter behavior are described accurately.
  - Disabled the normal menu post-action wait for actions that now manage their own repeat/return flow.

- Improved console width handling:
  - Terminal width is re-measured on redraw.
  - Rendering no longer relies on a separately cached menu width.
  - Layout caches are invalidated on redraw so resized terminals are recalculated correctly.
  - Non-interactive processes no longer fail when `/dev/tty` is unavailable.

## Repaired
- Repaired Storage provisioning confirmation handling:
  - Fixed remaining Yes/No comparisons that expected mixed-case values instead of the canonical `YES` / `NO` responses returned by `ask_decision`.
  - Verified storage provisioning now completes partitioning, filesystem creation, persistent `/etc/fstab` configuration, mounting, and creation of `/srv/storage/shares`.
  - Verified storage status correctly reports the configured source, filesystem, UUID, mount state, persistence, read/write state, capacity, and available space.

- Repaired Samba File Server provisioning and validation:
  - Removed validation of Samba printer shares, which are not part of the managed SolidGroundUX file-server configuration.
  - Verified the Samba preparation sequence completes successfully against provisioned SolidGroundUX storage.
  - Repaired managed share creation and removal workflows.

- Repaired Active Directory group handling in the Samba share manager:
  - Fixed AD group discovery on realmd/SSSD domain members where `getent group` cannot enumerate directory groups even though direct qualified-name lookups work.
  - Replaced unsuitable `samba-tool group list` discovery, which expects a local Active Directory database when run on a member server.
  - Avoided `net ads group`, which requires Samba ADS membership configuration not present on the realmd/SSSD client.
  - Added authenticated LDAP group discovery using the domain controller advertised through the Active Directory LDAP SRV record.
  - Fixed Kerberos authentication failures caused by using a lowercase realm; authentication now uses the canonical uppercase realm such as `TESTADURA.HQ`.
  - Fixed LDAP/GSSAPI service-ticket lookup by disabling SASL hostname canonicalization with `ldapsearch -N`.
  - Verified LDAP group enumeration against the domain controller and NSS resolution of selected qualified AD groups.

- Repaired Computer Setup validation:
  - Corrected the sudoers file path used for SolidGroundUX receiver access.
  - Centralized the sudoers filename in `SGND_COMPUTER_SUDOERS_FILE`.
  - Verified setup, status, and validation all reference the same sudoers policy file.

- Fully tested and repaired the Computer Setup workflow, including the automated preparation sequence.

- Fully tested and repaired Active Directory provisioning:
  - Fixed `ask_decision` case handling where canonical responses are returned in uppercase.
  - Restored the automated provisioning sequence so it continues beyond preflight validation.
  - Verified the remaining provisioning steps can complete successfully.

- Repaired Active Directory Management confirmation handling:
  - Fixed Yes/No comparisons so canonical `YES` / `NO` values are handled correctly.
  - Fixed Quit handling so `Q` actually exits the current action instead of falling through.
  - Fixed timeout handling in repeat-operation dialogs so timeout repeats the action instead of returning to the menu.

- Repaired terminal-width detection for non-interactive receiver execution:
  - Fixed `/dev/tty` probing so receiver-side operations no longer emit `No such device or address`.


# Release 2.0.2623316

## SolidGround Management Console

### Changed

- Reordered automated Computer Setup to generate SSH host keys before enabling and starting SSH.
- Changed Yes/No prompts in console modules from `YES/NO` to `Yes/No`.
- Corrected heading levels in the changelog.
- Corrected `sgnd_print_sectionheader` width calculation to use visible render width consistently.
- Added consistent visual separation before `ask_dlg_continue` prompts.
- Added automatic label-column sizing to console menu pages and the management-console index.

### Added

- Added `ask_selection`, a reusable single- and multi-selection ask primitive.
- Migrated selection workflows in `prepare-release.sh` and `untar-it.sh` to `ask_selection`.
- Added `manage-samba-shares.sh` for assigning Active Directory group access to Samba shares.
- Added `27-active-directory-management.sh` for managing Active Directory users, groups, memberships, and computer accounts.
- Added `50-web-server.sh` for preparing, validating, and inspecting an Nginx web-server role.
- Added `60-sqlserver.sh` for preparing, validating, and inspecting a Microsoft SQL Server role.
- Added `50-SolidGroundUX` to display SolidGroundUX version, license, documentation, and management information in the system MOTD.

# Release 2.0.2623211

## SolidGround Framework

### Changed
- `sgnd_style_samples` is now the canonical runtime showcase for the active
  theme, combining semantic theme colors with examples of the framework's
  rendering primitives.
- Theme message samples now use `sgnd_print` directly with the corresponding
  `LBL_*` and `MSG_CLR_*` values instead of invoking the `say*` message
  functions.
- The General UI Elements specimen now explicitly demonstrates
  `sgnd_print`, `sgnd_print_single`, `sgnd_print_labeledvalue`,
  `sgnd_print_labeledmultivalue`, `sgnd_print_fill`,
  `sgnd_print_sectionheader`, and `sgnd_print_titlebar`.
- The theme showcase now includes a non-interactive `ask` simulation using the
  active prompt and input colors without waiting for user input.
- The existing run-mode, state, validation, and progress specimens are retained
  as part of the consolidated theme showcase.
- The theme-color specimen now lists Message, Progress, and UI semantic color
  variables together with their resolved palette color name, RGB hex value, or
  indexed-color value.

## SolidGround Management Console

### Changed
- The Management Console host script was renamed to `management-console.sh`
  while retaining `sgnd-console` as the public command.
- The Management Console index now uses the same standard bottom control bar as
  normal console pages, accurately reflecting that the direct keyboard controls
  remain active on the index.
- Console selection handling is now more forgiving: invalid selections are
  reported and input is cleared before waiting for a new selection rather than
  allowing invalid input to terminate or disrupt the console flow.
- Manage Visibility selection now reports invalid entries explicitly instead of
  silently restarting the selection cycle.

### Repaired
- Numeric menu selections are interpreted explicitly as base-10 values,
  preventing Bash octal interpretation from affecting selections such as `08`.
- Console dispatch no longer treats an empty or invalid user selection as a
  shell-level missing-argument error.
- Post-action wait state is cleared before a new selection is dispatched so an
  invalid selection cannot inherit the wait interval from a previous action.

## Development Tools

### Added
- Added `sync-repository.sh` for synchronizing the development repository from
  the development server to a configured backup or workstation over SSH/SCP.
- Repository synchronization settings for destination machine, user, and
  directory are persisted through SolidGroundUX state for reuse on subsequent
  runs.

### Changed
- Repository synchronization now stages the incoming copy in a temporary
  destination and replaces the existing repository only after a successful
  transfer, so files removed from the source are also removed from the
  synchronized copy without deleting the last good copy first.
- `sync-repository.sh` now records a lightweight source-tree signature and the
  last successful synchronization time, allowing unchanged repositories to be
  skipped while still detecting additions, changes, renames, and removals.
- Added a force option to repository synchronization for explicitly refreshing
  the destination even when the stored source-tree signature is unchanged.

# Release 2.0.2623201

## SolidGround Framework

### Added
- `sync-repository.sh` was added to facilitate cloning reporsitories to (backup) machines
- `doc-generator` now supports comma-separated source masks, with the default
  expanded to `*.sh,*.py` so Bash and Python modules can participate in the
  same documentation generation workflow.

- Added an optional documentation `Subgroup` level beneath Group. Modules
  without a subgroup remain direct children of their Group, while subgroup
  prefaces and epilogues render around the subgroup's modules.

- Added persistent renderer export data beneath the documentation output so
  HTML can be regenerated without reparsing the full source tree.

- Added **Render existing data** as generation mode 4 and CLI mode
  `--mode render`. This mode validates the persisted renderer cache, skips
  source scanning/parsing, and reruns only the HTML renderer.

- Added generated-site branding support to the Python renderer, including
  SolidGroundUX documentation branding on content pages and Testadura
  publisher branding above the navigation index.

- Added functional documentation branding asset names:
  `doc-index-logo.png`, `doc-header-logo.png`, and `doc-index-hero.png`,
  decoupling renderer placement from a specific brand filename.

- Added generated semantic theme specimens for documented SolidGroundUX style
  modules. Theme previews are derived from the actual style and palette
  assignments rather than maintained as static screenshots.

- Added `cls:` as a first-class documentation item marker for Python classes.
  Python methods continue to use the existing language-neutral `fn:` marker.

### Changed
- Added public `sgnd_menu_dispatch` support so standalone framework tools can
  execute registered menu actions through the reusable menu API instead of
  maintaining their own dispatch logic.

- Added optional menu chrome control so consumers such as
  `framework-smoketest.sh` can use the public menu renderer without the
  Management Console togglebar and navigation legend.

- `framework-smoketest.sh` now builds, renders, reads, and dispatches its test
  menu through the public `sgnd-menu.sh` API while retaining its 30-second
  inactivity timeout.

- The framework smoke-test progress demo now uses genuinely nested stacked
  progress levels so lower-level work completes repeatedly while parent levels
  advance independently.

- Shared console-internal helpers used by more than one module or framework
  library now live in `lib/common/console-helpers.sh`, avoiding dependencies on
  another lazy-loaded console module having been opened first.

- `doc-generator` now derives clean-output behavior from the selected generation
  mode: Full generation always cleans the output directory, while Selected and
  Changed generation preserve existing output for incremental updates.

- Documentation file matching now uses one comma-separated mask contract across
  Full, Selected, and Changed generation modes.

- The documentation hierarchy now supports Group → optional Subgroup → Module,
  with navigation depth derived from the module's actual hierarchy level.

- `sgnd_doc_renderer.py` is now documented as part of the
  **SDK → Documentation Generator** subgroup alongside the Bash generator,
  processor, and renderer wrapper.

- Renderer exports are no longer purely temporary: successful parse modes
  persist the normalized PSV dataset for fast renderer-only iteration.

- Documentation branding assets are copied into the generated site so the HTML
  output remains self-contained.

- The documentation dialect is now shared between Bash and Python: both use
  `#`-prefixed `fn:`, `var:`, `doc:`, and `cls:` markers and feed the same
  normalized renderer data model.

- Documentation page branding now acts as a sticky page header and remains
  visible while scrolling generated content.

- Documentation diagrams are being moved from ASCII-only prose toward
  dedicated visual figures while retaining the source-authored technical
  content and hierarchy.

- The default UI palette now uses explicit 24-bit truecolor values instead of
  terminal-defined ANSI colors, providing consistent SolidGroundUX colors
  independently of the terminal's configured color palette.

- Width-aware UI primitives now delegate their default width policy to
  `sgnd_render_width`; when `--maxwidth` is omitted they use the current
  terminal width, while explicit widths remain honored.

- `SGND_MAX_RENDER_WIDTH` is now an optional global render cap: when unset or
  set to `0`, UI primitives may use the full terminal width; positive values
  continue to enforce an explicit maximum.

- `sgnd_print_titlebar`, `sgnd_print_sectionheader`, `sgnd_print_fill`,
  `sgnd_print`, `sgnd_print_single`, `sgnd_print_labeledvalue`, and
  `sgnd_print_labeledmultivalue` now follow the same dynamic-width behavior.

- `sgnd_print_sectionheader` now extends full-width or trailing borders to the
  current console width by default unless an explicit `--maxwidth` is supplied.

### Repaired
- Fixed documentation navigation depth for modules inside a subgroup so module
  sections and items render one level deeper than direct Group modules.

- Corrected the SolidGround Management Console preface grouping so its
  architecture/lifecycle documentation renders under the
  **SolidGround Console** group instead of **Common Core**.

- Renderer-only generation now fails explicitly when no valid persisted render
  dataset is available instead of silently falling back to a full parse.

- `deploy-workspace.sh` could fail when the remote receiver required `sudo`
  authentication. It now creates a narrowly scoped remote `sudoers` rule for
  `receive-files.sh`, allowing remote deployments to run non-interactively after
  the initial setup.

## SolidGround Management Console

### Added
- Added a lightweight main index page that discovers available console pages
  without sourcing their implementation modules.

- Added lazy page loading: a console module is sourced only when its page is
  opened for the first time, then remains loaded for the rest of the console
  session.

- Added root-only **Manage visibility** (`V`) on the main index page. Module
  visibility is persisted through the existing console-module state file and
  the index is refreshed immediately after changes.

- Added a dedicated **SolidGroundUX** page containing framework information,
  configuration, state, logging, diagnostics, the interactive Release Manager,
  and direct release-manager actions for check, download, update, install,
  rollback, and removal.

- Added **Storage** and **Storage Access** as dedicated Management Console
  functionality, including provisioning, mount/unmount, expansion, validation,
  status, ownership, group, and permission management.

### Changed
- Management Console startup now loads only lightweight page metadata. Detailed
  groups, menu items, and implementation functions are registered when the
  selected page is first opened.

- Previously loaded pages remain resident for the lifetime of the console
  process instead of being unloaded when leaving a page.

- `Esc` now returns from a loaded page to the main index, allowing direct page
  navigation without traversing intermediate modules.

- The main index now follows the standard console title and menu-row visual
  conventions, including hostname display, aligned descriptions, and a
  dedicated section for console-management actions.

- Removed the separate Console Settings page in favor of the existing direct
  quick-access controls for mode, access, logging, theme, redraw, page length,
  and shell access.

- Normal menu actions now restore the interruptible post-action auto-continue
  window with a minimum wait of 15 seconds, while immediate toggle actions can
  still redraw without delay.

- Shared helpers required by multiple lazy-loaded console modules are now
  provided by `lib/common/console-helpers.sh` rather than being owned by one
  module and implicitly depended on by another.

- The Management Console preface was rewritten for the current index-based,
  lazy-loading architecture and renamed
  `solidground-management-console_preface.sh`.

- Moved the paging indicator from the bottom-right corner to a centered position above
  the menu, making additional pages more obvious. The indicator is hidden when only
  one page is available.

- The `Q` legend is now context-aware: `Quit` is shown in the root console and `Back`
  in submenus.

- Removed the experimental role-aware menu filtering/toggle from the current
  console architecture; page visibility is now controlled explicitly through
  the persistent root-only **Manage visibility** action.

### Repaired
- Fixed cross-module helper dependencies exposed by lazy loading, including DNS
  configuration helpers used by both Active Directory Server and Active
  Directory Client pages.

- Fixed the lazy-page event loop no longer honoring registered post-action wait
  times.

- Fixed smoke-test menu selections being lost because the timed input helper
  shadowed the caller's output variable.

- Fixed standalone public-menu consumers failing on `_sgnd_flag_is_on` because
  the helper was defined only by the Management Console host.

- Fixed the Storage Access group visibility value being accidentally changed
  from enabled (`1`) to `15`.

- The Samba Active Directory package installation now explicitly includes
  `samba-common-bin`, ensuring the required `samba-tool` command is installed
  as a direct dependency of the SolidGroundUX AD-server role.

# Build 1.9.2622402 - 2026-08-12
## SolidGround Framework

### Added

-   Added `sgnd_clear` to the shared UI layer as the canonical screen-clear
    primitive for SolidGroundUX console applications. It clears the visible
    display and returns the cursor to the home position without attempting to
    erase terminal scrollback.
-   `sgnd_exe_start` now supports `--no-title`, allowing executable scripts such
    as `sgnd-console.sh` to suppress the standard startup title bar when they
    provide their own full-screen rendering.
-   Generic executable title bars now include the executing script's own
    canonical metadata Version and Build number when available, making
    the active script revision immediately visible at runtime.

-   Added `sgnd-definitions.sh` as the canonical source for
    SolidGroundUX framework identity, version/build information, default
    settings, framework registries, and core-library declarations.
-   Added `sgnd_print_labeledmultivalue`, a multiline variant of
    `sgnd_print_labeledvalue` that keeps the label on the first line
    while allowing values to span multiple lines.
-   `sgnd_print_labeledmultivalue` accepts either:
    -   A single string, optionally wrapped to a configurable value
        width.
    -   An array of values, with each item rendered on a separate
        aligned line.
-   Added `ask_datetime`, a datetime-aware variant of `ask` that accepts
    both absolute dates and SolidGroundUX relative date/time
    expressions.
-   Added the following datetime shortcuts:
    -   `N` -- Current date and time.
    -   `D` -- Today at the start of the day.
    -   `s` -- Seconds.
    -   `m` -- Minutes.
    -   `h` -- Hours.
    -   `d` -- Days.
    -   `M` -- Months.
    -   `y` -- Years.
    -   Relative expressions such as `-2m`, `-2h`, `+30m`, `-1d`, `-3M`,
        and `-1y`.
-   Relative datetime expressions are resolved immediately and returned
    as absolute ISO-8601 timestamps.
-   `ask_datetime` now displays the resolved absolute timestamp when a
    shorthand expression is entered.
-   Added an interactive `ask_datetime` test to the framework smoke
    test.

### Changed

-   `sgnd_print` and `sgnd_print_single` now calculate alignment and automatic
    wrapping from visible text width rather than raw string length, so embedded
    ANSI styling no longer distorts centering and right/left justification.
-   `sgnd_print` wrapping behavior is now explicit and consistent: long text
    wraps automatically, `--wrap 1` forces wrapping, and `--wrap 0` disables it.
-   The standard clear-screen sequence was deliberately reduced to cursor-home
    plus visible-display erase (`ESC[H ESC[2J]`). Scrollback clearing is no
    longer attempted because terminal emulators handle saved-line history and
    resize reflow differently.

## SolidGround Management Console

### Added

-   Added persistent console-module visibility state, with module
    identifiers derived conventionally from module filenames.
-   Added **Manage modules** to **Console Session**, allowing console
    modules to be enabled or disabled without editing configuration
    files manually.
-   Added role-aware console visibility so Active Directory server,
    Active Directory client, DNS, user/group, and Samba file-server
    functionality is only exposed when the corresponding role packages
    are installed.
-   Added the executing machine hostname to the Management Console title
    bar, making machine identity immediately visible across local and
    remote sessions.
-   Added transient console initialization/progress feedback while
    paths, configuration, built-in menu items, and console modules are
    loaded.
-   Added `Shift+S` as an immediate shortcut for opening an interactive child
    shell and returning to the Management Console on `exit`.
-   Added `Ctrl+R` as an immediate console restart shortcut. Restart uses `exec`
    so the current process is replaced rather than nested and preserves the
    original console arguments and current dry-run/commit state.
-   Added an on-screen shortcut legend for shell, restart, quit, and page
    navigation controls.

### Changed

-   Consolidated all package-related actions into a dedicated **Package
    Management** module, including base packages, Active Directory
    server/client packages, Samba File Server, XRDP, and Docker.
-   Console module load control now follows SolidGroundUX
    convention-over-configuration: module IDs are derived from filenames
    rather than duplicated as explicit module declarations.
-   Disabled console modules are no longer sourced; modules without an
    explicit visibility-state entry remain enabled by default for
    backward compatibility.
-   Console screen clearing now uses an explicit ANSI
    erase-display/cursor-home sequence instead of the host `clear`
    implementation, producing consistent rendering across SSH/PowerShell
    and VS Code terminals.
-   Increased the console menu label-width allowance to improve
    readability of longer package-management actions.
-   Management Console startup now suppresses the generic executable title bar
    and immediately takes ownership of screen rendering through its own title
    and menu renderer.
-   The Management Console title now shows the executing script Version and
    Build alongside the console title.
-   The footer layout now separates runtime state from direct actions and page
    navigation, with the shortcut legend rendered as a centered secondary line
    and page state kept visually distinct.
-   Console legend/page text now uses the same value/italic visual treatment as
    the hostname in the title bar.

### Fixed

-   Fixed the duplicate top separator line that could appear in the
    Management Console when running through SSH from PowerShell.
-   Fixed hidden console groups still allowing their menu items to
    participate in pagination/rendering.
-   Fixed console redraw width calculations so ANSI-styled text is measured by
    visible width rather than escape-sequence byte length.
-   Removed scrollback erase (`ESC[3J]`) from the shared clear-screen behavior
    after confirming it can produce terminal-dependent stale/reflowed lines and
    duplicate-looking top rows during redraws and resizes.

### Changed

-   `sgnd-bootstrap-env.sh` now consumes canonical definitions from
    `sgnd-definitions.sh` while retaining responsibility for
    runtime-derived paths, rebasing, user resolution, and directory
    construction.
-   `prepare-release.sh` now updates framework version/build identity in
    `sgnd-definitions.sh` instead of `sgnd-bootstrap-env.sh`.

## Machine and Network Configuration

### Added

-   Added DNS search-domain support to `set-identity.sh`.
-   Added an interactive **DNS search domain** prompt alongside the DNS
    server setting.
-   Added `--DNS-search` support for non-interactive and DNS-only
    network updates.
-   DNS search-domain values now participate in persistent script state.
-   Netplan generation now writes the configured DNS search domain
    beneath `nameservers.search`.

### Changed

-   DNS configuration now treats the DNS server and DNS search domain as
    a single network identity concern.
-   Active Directory provisioning and domain join now use the generic
    DNS-setting path instead of maintaining separate Netplan
    search-domain logic.
-   Management console now has a state variable SGND_CONSOLE_ROLE_AWARE
    indicating if only role appropriate menus are displayed
    
## Active Directory

### Added

-   Added an **Active Directory DNS** console group.
-   Added DNS-zone listing and host-record query actions.
-   Added actions to create and delete IPv4 host records in Samba Active
    Directory DNS.
-   Added an action to rerun DNS registration for the local domain
    controller.
-   Added client-side actions to manually add or remove the current
    machine's Active Directory DNS record.
-   Domain join now registers the joining machine's IPv4 host record in
    Active Directory DNS.
-   Domain join now configures the Active Directory DNS server and
    domain search suffix as part of client network configuration.

### Changed

-   **Show membership** now provides a consolidated client-domain status
    overview, including:
    -   Machine FQDN.
    -   Machine IPv4 address.
    -   Joined realm.
    -   Domain membership state.
    -   Active Directory DNS server.
    -   DNS host-record registration state.
    -   Registered DNS A-record address.
    -   Kerberos SRV availability.
    -   LDAP SRV availability.
-   Domain join now explicitly configures and validates the machine FQDN
    before joining the realm.
-   Active Directory DNS registration checks now query the authoritative
    AD DNS server directly rather than relying on the local resolver.
-   DNS host-record creation and deletion use shared non-interactive
    helpers so the same implementation is available to both console
    actions and domain join.

### Fixed

-   Fixed joined clients retaining only a short hostname instead of the
    expected fully qualified domain name.
-   Fixed DNS-registration status reporting false positives caused by
    local `/etc/hosts` resolution.
-   Fixed DNS helper variable scoping that could reduce a host FQDN to a
    malformed value such as `td-nas.`.
-   Fixed domain-joined Linux clients being unable to resolve short AD
    hostnames because no DNS search domain was configured.
-   Fixed the domain-join chain so a successful join results in a
    resolvable AD DNS A record for the client.

## Storage

### Added

-   Added storage provisioning for an unused disk, including:
    -   GPT partition creation.
    -   EXT4 or XFS filesystem creation.
    -   Persistent `/etc/fstab` configuration.
    -   Mounting at `/srv/storage`.
    -   Creation of the standard `/srv/storage/shares` directory.
-   Added actions to mount, unmount, and expand configured storage.
-   Added **Validate storage provisioning**, which verifies:
    -   The storage filesystem is mounted.
    -   The filesystem is mounted read/write.
    -   The configured source matches the active mount source.
    -   The persistent `/etc/fstab` entry is valid.
    -   The expected filesystem label is present.
    -   `/srv/storage` exists.
    -   `/srv/storage/shares` exists.
-   Added a separate **Storage Access** menu group for managing the
    ownership and permissions of:
    -   `/srv/storage`
    -   `/srv/storage/shares`
-   Added actions to:
    -   Show storage ownership and permissions.
    -   Set the storage owner.
    -   Set the storage group.
    -   Set storage permissions.
    -   Restore canonical storage permissions.
-   Canonical storage permissions can now be restored to:
    -   `/srv/storage` -- `root:root`, mode `0755`.
    -   `/srv/storage/shares` -- `root:root`, mode `0770`.

### Changed

-   **Show storage status** now reports:
    -   Mount source.
    -   Filesystem.
    -   Filesystem label.
    -   UUID.
    -   Mounted state.
    -   Persistent configuration state.
    -   `/etc/fstab` validity.
    -   Whether the active mount source matches the configured source.
    -   Whether the filesystem is mounted read/write.
    -   Storage-root and shares-root availability.
    -   Capacity and available space.
-   Replaced the misleading **Storage root writable** status with
    **Mounted read/write**.
-   Storage configuration now performs `systemctl daemon-reload` after
    updating `/etc/fstab`.

### Fixed

-   Fixed storage mount detection incorrectly treating `/srv/storage` as
    mounted when it was only an ordinary directory on the root
    filesystem.
-   Fixed storage status showing the capacity of the system root instead
    of the configured storage volume.
-   Fixed storage provisioning stopping after filesystem creation
    without completing persistent mounting.

## Samba File Server

### Added

-   Added Samba file-server package installation.
-   Added managed Samba share creation beneath `/srv/storage/shares`.
-   Added actions to list and remove managed Samba shares.
-   Share creation now:
    -   Creates the backing directory.
    -   Adds a managed section to `smb.conf`.
    -   Validates the configuration with `testparm`.
    -   Reloads Samba.
    -   Restores the previous configuration if validation fails.
-   Added file-server validation for:
    -   Samba tooling.
    -   Samba configuration.
    -   `smbd` service state.
    -   Mounted storage.
    -   The managed share root.
    -   Configured share backing directories.
-   Added a dedicated `manage-samba-shares.sh` executable for
    interactive share management.
-   The share manager supports:
    -   Listing all managed shares.
    -   Selecting one or more shares by number.
    -   Comma-separated selections.
    -   Numeric ranges.
    -   Selecting all shares.
    -   Keeping the selected collection active while applying multiple
        actions.
-   Added share-management actions to:
    -   Show share details.
    -   Set owner.
    -   Set group.
    -   Set Unix permissions.
    -   Restore default permissions.
    -   Validate selected shares.

### Changed

-   Replaced the separate share-permission menu actions with a single
    **Manage shares** action.
-   Share ownership and permission management is now handled by the
    dedicated share-management executable rather than repeated prompts
    in the console module.
-   The Samba module now delegates detailed share-management workflows
    while retaining installation, creation, removal, validation, and
    status actions.

## Installation and Release Management

### Added

-   Added the standalone `release-manager.sh` as the canonical
    SolidGroundUX installation and release-lifecycle tool, replacing the
    separate install, update, and uninstall workflow.
-   Added filesystem-based release state:
    -   `/var/lib/solidgroundux/releases` contains releases available
        for installation.
    -   `/var/lib/solidgroundux/archive/<release>` contains installed
        release history.
    -   The highest archived version represents the currently installed
        release.
-   Added interactive archived-release selection for reinstallation and
    rollback, with the current release identified and **Remove
    SolidGroundUX** available as the final action.
-   Added GitHub latest-release discovery and download support.
-   Added release acquisition through temporary staging, extraction,
    checksum validation, release-identity validation, and path-safety
    validation before a release is admitted into `releases/`.
-   Added bootstrap installation from a GitHub release ZIP containing
    `release-manager.sh` and the complete prepared release set.
-   Added automatic creation of the SolidGroundUX release-management
    directories during first installation.
-   Added automatic installation of a valid release set found beside the
    bootstrap copy of `release-manager.sh`.
-   Added automatic installation of the release manager itself at
    `/var/lib/solidgroundux/release-manager.sh`.
-   Added safe cleanup of known bootstrap files after a successful
    installation from a temporary directory.
-   Added command-line operations for checking, downloading, installing,
    updating, rolling back, reinstalling, and removing releases,
    including unattended and dry-run operation.

### Changed

-   Release-manager identity now follows the same canonical per-script
    metadata Version/Build mechanism as other SolidGroundUX executables;
    framework identity remains independently defined by
    `sgnd-definitions.sh`.
-   First-install extraction and copy handling now accounts for target
    directories that do not yet exist while preserving metadata of target
    directories that already exist.
-   First-time installation no longer requires manually creating the
    releases directory, copying release files into it, or extracting the
    framework archive directly into `/`.
-   Release bundles now act as self-contained bootstrap packages: they
    can be downloaded and extracted into a temporary directory and
    installed by running the bundled `release-manager.sh`.
-   Updates now install complete release archives and process the
    incoming `.removed` manifest for files that no longer belong to the
    new release.
-   Rollback now reinstalls a complete archived release and returns
    newer archived releases to `releases/`, preserving the
    filesystem-based current-version rule.
-   Removal now uses release manifests to remove framework-owned files
    while retaining release artifacts for later reinstallation.
-   Release-manager UI is self-contained and framework-independent while
    following the SolidGroundUX default visual conventions for titles,
    separators, labels, values, prompts, and status colors.
-   Updated deployment and installation documentation to describe the
    new `prepare-release.sh` → release artifacts → `release-manager.sh`
    workflow and distinguish it from direct development deployment
    through `deploy-workspace.sh`.

### Fixed

-   Fixed the fresh-machine bootstrap path so running `release-manager.sh` from
    an extracted release package does not stop after installing the manager
    itself: the bundled prepared release is admitted to the canonical
    `releases/` location and installation continues from there.
-   Fixed bootstrap handling so the release manager can relocate itself to
    `/var/lib/solidgroundux/release-manager.sh` without losing access to the
    release artifacts that accompanied the temporary bootstrap copy.
-   Tightened first-run release discovery and staging so a release extracted in
    a temporary directory follows the same validation and installation path as
    later downloaded or archived releases.

### Removed

-   The separate installer/updater/uninstaller architecture is
    superseded by `release-manager.sh`.
-   Removed the requirement for installation metadata or a separate
    current-version marker; release and archive directories now provide
    the required state.

## Development Tools

### Added

-   Added `create-wrappers.sh`, an interactive development utility for
    generating SolidGroundUX public command wrappers from executable scripts.
-   Wrapper generation supports source directory, filename or shell-style
    mask selection, configurable `bin` or `sbin` targets, and optional
    overwrite of existing wrappers.
-   Generated wrapper names conventionally use `sgnd-<scriptname>` without
    the `.sh` extension, while preserving names that already begin with
    `sgnd-`.
-   Generated wrappers resolve user-specific and system-wide SolidGroundUX
    configuration so they remain root-aware across development workspaces
    and installed systems.
-   Wrapper script targets are variable rather than tied to
    `usr/local/libexec/solidgroundux`, allowing wrappers for executables
    located elsewhere, including release-management tools.
-   Added **Create wrappers** to the Management Console Development Tools
    module.

-   `prepare-release.sh` now verifies that executable scripts directly
    beneath `usr/local/libexec/solidgroundux` have corresponding public
    command wrappers in `usr/local/bin`.
-   Added optional automatic creation of missing public command wrappers
    during release preparation.
-   `create-workspace.sh` now copies the canonical SolidGroundUX
    template set into the workspace under
    `target-root/usr/local/lib/solidgroundux/templates` and instantiates
    selected starter files from those workspace-local templates.

### Changed

-   `prepare-release.sh` now supports selecting a historical release
    manifest as the comparison baseline for generating the `.removed`
    manifest, allowing removals to be based on a chosen prior release.
-   Release preparation now writes the complete prepared release artifact
    set to the release output directory, including the archive, manifest,
    checksum files, removed manifest, and bundled `release-manager.sh`.
-   Missing canonical source headers encountered during release preparation
    are reported as warnings rather than aborting the release.
-   Consolidated release metadata maintenance into `prepare-release.sh`,
    superseding the separate metadata-editor workflow.

-   Version and Build metadata policies in `prepare-release.sh` now
    support `A` (all files), `C` (changed files only), and `N` (no
    update) independently.

-   Changed-file detection for release metadata uses the canonical
    header checksum mechanism, allowing source changes to be
    distinguished from Version, Build, and Checksum metadata changes.

-   Checksums are refreshed automatically for changed files and whenever
    release metadata changes a file.

-   Version and Build policy prompts now use constrained SolidGroundUX
    decision input with `C` as the default.

-   Corrected the `prepare-release.sh` argument specifications so `C` is
    stored as the default for Version and Build policies and `A,C,N`
    remains the choice list.

-   Workspace creation now follows the repository-shaped `target-root`
    layout more explicitly and uses its local template copy as the
    source for newly selected executable, library, and module starter
    files.

-   `sgnd_doc_renderer.py` now renders \$ marked entries only for
    template packages, : is rendered always

-   `deploy-workspace.sh` now ends with a redo/continue prompt: Continue
    exits cleanly, while `R` restarts the deployment from the beginning
    with the original arguments.

-   `deploy-workspace.sh` now uses `ask_datetime` for the **Changed
    after** prompt.

-   The deployment filter now accepts SolidGroundUX relative date/time
    expressions, such as `N`, `D`, `-2h`, and `-1d`, in addition to
    absolute dates and timestamps.

-   `deploy-workspace.sh` now displays a deployment summary after a
    successful transfer.

-   The deployment summary reports:

    -   Result.
    -   Transport.
    -   Source root.
    -   Destination.
    -   Receiver.
    -   Start and finish timestamps.
    -   Every transferred file.

-   The deployment summary now uses `sgnd_print_labeledmultivalue`,
    displaying transferred files on separate aligned lines instead of as
    a truncated comma-separated string.

-   `prepare-release.sh` now ensures that every regular file directly
    beneath `usr/local/libexec/solidgroundux` has its executable bit set
    before staging and archive creation.

-   Dry-run mode reports which executable permissions would be corrected
    without modifying the source tree.


# Version 1.8 (Build 1.8.2621804)

## Changed

### Active Directory

-   Active Directory provisioning now automatically configures the
    domain controller to use itself as the primary DNS server after
    successful domain creation.
-   Refined the provisioning workflow with a clearer separation between
    network configuration and Active Directory provisioning
    responsibilities.
-   Active Directory provisioning now prompts for the Administrator
    account password as part of the provisioning process.
-   Completed and fully validated the end-to-end Active Directory
    provisioning workflow, including DNS, Kerberos, and domain
    verification.

### Development Tools

-   `deploy-workspace.sh` now supports comma-separated filenames and
    shell-style file masks.
-   Deployment settings are now persisted automatically between
    sessions.
-   Added support for incremental deployments based on the last
    successful deployment timestamp.
-   `deploy-workspace.sh` now offers an interactive **Since last
    deployment** option.
-   When **Since last deployment** is selected, the stored deployment
    timestamp is displayed and the **Changed after** prompt is skipped.
-   When **Since last deployment** is not selected, the **Changed
    after** date defaults to `1900-01-01`.
-   Streamlined deployment prompts and selection workflow for a faster
    incremental deployment experience.
-   Significantly improved incremental documentation generation by
    supporting selective regeneration of changed source files, greatly
    reducing documentation build times during development.

## Resolved

### Active Directory

-   Fixed domain provisioning to correctly configure the required Fully
    Qualified Domain Name (FQDN) before provisioning.
-   Fixed DNS listener detection during Active Directory verification.
-   Fixed Kerberos configuration and verification workflow.
-   Fixed Active Directory verification to correctly validate DNS,
    directory services, and Kerberos authentication.
-   Fixed Administrator account configuration to support non-expiring
    passwords.

### Development Tools

-   Fixed deployment state persistence in `deploy-workspace.sh`.
-   Fixed deployment selection to correctly process multiple filename
    filters during a single deployment operation.

# Version 1.8 (Build 2621612)

## SolidGround Management Console

### Added

#### Computer Setup

-   Machine status overview.
-   Machine identity and network configuration.
-   Machine ID generation.
-   SSH service configuration.
-   SSH host key generation.
-   VM template preparation.
-   Ubuntu package management.
-   Ubuntu base package installation.

#### Active Directory

-   Samba Active Directory package installation.
-   Active Directory domain provisioning.
-   Active Directory status overview.
-   Active Directory user management.
-   Active Directory group management.
-   Active Directory client installation.
-   Domain join and leave support.

#### Samba File Server

-   Samba File Server installation.

#### Optional Roles

-   Docker installation.
-   XRDP installation.
-   Framework for future optional server roles.

#### SolidGroundUX

-   Framework configuration management.
-   Framework state management.
-   Framework logging tools.
-   Framework diagnostics.
-   SolidGroundUX installation, update, and removal.

#### Development Tools

-   Workspace creation.
-   Workspace deployment through `deploy-workspace.sh`.
-   Workspace archiving.
-   Workspace restoration.
-   Release preparation.
-   Metadata editor.
-   Documentation generator.
-   `receive-files.sh` for receiving streamed deployments.
-   `tar-it.sh` for archive creation.
-   `untar-it.sh` for archive restoration.

### Changed

-   Reorganized the SolidGround Management Console into dedicated
    functional modules.
-   Simplified the overall console navigation.
-   Console actions that invoke external scripts now resolve those
    scripts from `SGND_COMMON_EXE` or `SGND_COMMON_LIB`.
-   Completely redesigned `deploy-workspace.sh`.
-   Added support for local and remote workspace deployment over SSH.
-   Added support for deploying complete workspaces or filtered file
    selections.
-   `deploy-workspace.sh` now creates a tar stream that is processed by
    `receive-files.sh`.
-   Simplified deployment selection by combining directory, filename or
    mask, and modification-date filters.

### Removed

-   Replaced the previous console modules with the new functional module
    structure:
    -   `10-sgnd-config.sh`
    -   `20-machine-config.sh`
    -   `30-role-provisioning.sh`

## SolidGround Framework

### Added

-   Global variable SGND_COMMON_EXE this is weher Solidground's
    executables can be found

# Version 1.8 (Build 1.8.2621804)

## Changed

### Active Directory

-   Active Directory provisioning now automatically configures the
    domain controller to use itself as the primary DNS server after
    successful domain creation.
-   Refined the provisioning workflow with a clearer separation between
    network configuration and Active Directory provisioning
    responsibilities.
-   Active Directory provisioning now prompts for the Administrator
    account password as part of the provisioning process.
-   Completed and fully validated the end-to-end Active Directory
    provisioning workflow, including DNS, Kerberos, and domain
    verification.

### Development Tools

-   `deploy-workspace.sh` now supports comma-separated filenames and
    shell-style file masks.
-   Deployment settings are now persisted automatically between
    sessions.
-   Added support for incremental deployments based on the last
    successful deployment timestamp.
-   `deploy-workspace.sh` now offers an interactive **Since last
    deployment** option.
-   When **Since last deployment** is selected, the stored deployment
    timestamp is displayed and the **Changed after** prompt is skipped.
-   When **Since last deployment** is not selected, the **Changed
    after** date defaults to `1900-01-01`.
-   Streamlined deployment prompts and selection workflow for a faster
    incremental deployment experience.
-   Significantly improved incremental documentation generation by
    supporting selective regeneration of changed source files, greatly
    reducing documentation build times during development.

## Resolved

### Active Directory

-   Fixed domain provisioning to correctly configure the required Fully
    Qualified Domain Name (FQDN) before provisioning.
-   Fixed DNS listener detection during Active Directory verification.
-   Fixed Kerberos configuration and verification workflow.
-   Fixed Active Directory verification to correctly validate DNS,
    directory services, and Kerberos authentication.
-   Fixed Administrator account configuration to support non-expiring
    passwords.

### Development Tools

-   Fixed deployment state persistence in `deploy-workspace.sh`.
-   Fixed deployment selection to correctly process multiple filename
    filters during a single deployment operation.

# Version 1.8 (Build 2621612)

## SolidGround Management Console

### Added

#### Computer Setup

-   Machine status overview.
-   Machine identity and network configuration.
-   Machine ID generation.
-   SSH service configuration.
-   SSH host key generation.
-   VM template preparation.
-   Ubuntu package management.
-   Ubuntu base package installation.

#### Active Directory

-   Samba Active Directory package installation.
-   Active Directory domain provisioning.
-   Active Directory status overview.
-   Active Directory user management.
-   Active Directory group management.
-   Active Directory client installation.
-   Domain join and leave support.

#### Samba File Server

-   Samba File Server installation.

#### Optional Roles

-   Docker installation.
-   XRDP installation.
-   Framework for future optional server roles.

#### SolidGroundUX

-   Framework configuration management.
-   Framework state management.
-   Framework logging tools.
-   Framework diagnostics.
-   SolidGroundUX installation, update, and removal.

#### Development Tools

-   Workspace creation.
-   Workspace deployment through `deploy-workspace.sh`.
-   Workspace archiving.
-   Workspace restoration.
-   Release preparation.
-   Metadata editor.
-   Documentation generator.
-   `receive-files.sh` for receiving streamed deployments.
-   `tar-it.sh` for archive creation.
-   `untar-it.sh` for archive restoration.

### Changed

-   Reorganized the SolidGround Management Console into dedicated
    functional modules.
-   Simplified the overall console navigation.
-   Console actions that invoke external scripts now resolve those
    scripts from `SGND_COMMON_EXE` or `SGND_COMMON_LIB`.
-   Completely redesigned `deploy-workspace.sh`.
-   Added support for local and remote workspace deployment over SSH.
-   Added support for deploying complete workspaces or filtered file
    selections.
-   `deploy-workspace.sh` now creates a tar stream that is processed by
    `receive-files.sh`.
-   Simplified deployment selection by combining directory, filename or
    mask, and modification-date filters.

### Removed

-   Replaced the previous console modules with the new functional module
    structure:
    -   `10-sgnd-config.sh`
    -   `20-machine-config.sh`
    -   `30-role-provisioning.sh`

## SolidGround Framework

### Added

-   Global variable SGND_COMMON_EXE this is weher Solidground's
    executables can be found

# Version 1.8 (Build 2621300)

## SolidGroundUX Framework

### Resolved

-   All print primitives in ui.sh now respect SGND_CONSOLE_WIDTH

### Added

-   Themed color constants SGND_UI_BOLD, SGND_UI_FAINT, SGND_UI_ITALIC
-   Incremental update options for doc-generator
-   Added Appendix 0 to documentation (Both for Dev's as well as AI)

## SolidGroundUX Management Studio

### Added

-   Added sshd verification to 20-machine-config.sh
-   Added new module 30-role-provisioning.sh with samba ad provisoning
    functions

### Changed

-   Warning when opening shell nows displays regardless of loglevel

# Version 1.8 (Build 2621022)

## SolidGroundUX Management Studio

### Added

-   Added a Machine Configuration action to enable or disable the SSH
    service.
-   Added a Console Session action to open a child shell.

### Changed

-   Updated `set-identity.sh` to use the current machine configuration
    as the default prompt values.
-   Added automatic availability checks for static IPv4 addresses before
    applying network configuration, with user confirmation when a
    potential address conflict is detected.

## SolidGroundUX Framework

### Added

-   Added dedicated style variables for title and section rendering,
    allowing title text, subtitle text, border colours, and border
    characters to be customized independently of the base UI palette.

# Version 1.8 (Build 2620810)

## Resolved

-   Fixed various machine configuration issues in the Management
    Console.
-   Fixed an issue where state variables were not being saved by
    `prepare-release.sh`.
-   Fixed documentation grouping issues caused by inconsistent script
    title prefixes.

## Added

-   Added framework global `SGND_CONSOLE_WIDTH` to define the preferred
    console rendering width.
-   Added framework global `SGND_MAX_RENDER_WIDTH` to define the maximum
    console rendering width.
-   Added documentation summary sections (`var:` blocks) to the
    framework style files.

## Changed

-   Updated all UI rendering primitives to respect the framework console
    width settings.
-   Changed HTML documentation rendering so consecutive non-empty lines
    are treated as paragraphs.
-   Updated `prepare-release.sh` to synchronize the selected version
    with changed script headers.
-   Improved documentation generation for style configuration variables.

# Version 1.8 (Build 2620423)

## Resolved

-   Fixed an issue where `sgnd-install.sh` could overwrite ownership and
    permissions of existing system directories (such as `/`, `/etc`, and
    `/usr`) during installation.

## Changed

-   Updated `sgnd-install.sh` to preserve metadata of existing target
    directories.
-   Updated `prepare-release.sh` to package repository directories with
    `root:root` ownership.

# Version 1.8 (Build 2620413)

## Added

-   Introduced the **SolidGroundUX Management Console**, a module-driven
    administration application built on the generic `sgnd-console`
    engine.
-   Added ordered console-module loading through numeric filename
    prefixes, allowing the first module to define the console title and
    description.
-   Added the `10-sgnd-config.sh` module for:
    -   Developer tools
    -   SolidGroundUX installation and maintenance
    -   Framework configuration
    -   Framework state
    -   Framework logging
    -   Framework diagnostics
-   Added the `20-machine-config.sh` module for machine identity,
    package maintenance, template preparation, and optional server
    roles.
-   Added direct bottom-bar controls for:
    -   Dry-run or commit mode
    -   Console log level
    -   File log level
    -   Active theme
    -   Screen clearing
-   Added reverse cycling for console log level, file log level, and
    theme using `Shift+C`, `Shift+F`, and `Shift+T`.
-   Added framework configuration actions for viewing effective settings
    and editing system-wide and user-specific configuration files.
-   Added framework logging actions for viewing, following, filtering,
    and rotating the active logfile.
-   Added `sgnd-update.sh` to download the latest SolidGroundUX release
    from GitHub.
-   Added public command wrappers for install, uninstall, and update
    operations.
-   Added cached console menu models and cached page layouts to make
    redraws effectively immediate.

## Changed

-   Redesigned `sgnd-console` as a reusable console engine rather than a
    SolidGroundUX-specific application.
-   Moved the visible console identity from the host into the first
    successfully loaded module.
-   Replaced implicit module discovery order with deterministic filename
    sorting.
-   Reworked the console module contract around:
    -   `SGND_MODULE_ID`
    -   `SGND_MODULE_NAME`
    -   `SGND_MODULE_VERSION`
    -   `SGND_MODULE_DESC`
-   Separated public commands from module-private helper scripts.
-   Merged the former Developer Tools and Framework State modules into
    `10-sgnd-config.sh`.
-   Moved SolidGroundUX installation actions into the SolidGroundUX
    configuration module.
-   Renamed the `vm-config` module and helper directory to
    `machine-config`.
-   Replaced the individual framework smoke-test menu entries with a
    single framework smoke-test command.
-   Reused `framework-smoketest.sh --show env` as the effective
    framework configuration and environment overview.
-   Updated console rendering to reuse cached datatable data instead of
    repeatedly querying and rebuilding menu structures.
-   Updated console and module documentation for the new Management
    Console architecture.
-   Made style sequence fixed so forward and back actually work

## Removed

-   Removed the old `console-devtools.sh` module.
-   Removed the old `console-framework-state.sh` module.
-   Removed the old `vm-config.sh` module name and `vm-config/` helper
    directory.
-   Removed the prompt-based console and file log-level selectors from
    the Console Session menu.
-   Removed the prompt-based theme selector from the Console Session
    menu.
-   Removed the individual in-process framework smoke-test menu actions.

------------------------------------------------------------------------

# Version 1.7 (Build 2620012) 2026-07-19

## Removed

-   Removed motd file, but archaic and cumbersome, and doesn't really
    add any functionality

## Added

-   Added images to documentation, do-generator now supports image tag
    in comments

  ---------------------
  \# Version 1.7 (Build
  2619600) - 2026-07-14

  \## Fixed -
  sgnd-console didn't
  handle --appcfg well,
  corrected so it works
  as intended - updated
  style files with
  SGND_UI_ON and
  SGND_UI_OFF

  \# Version 1.7 (Build
  2619513) - 2026-07-14

  \## Added

  \- Added Appendix F
  to the generated
  documentation
  containing the
  framework license. -
  Introduced persistent
  framework settings
  between sessions. -
  Added persistent
  console session
  settings. - Added
  interactive console
  customization for: -
  Theme selection -
  File log level - Menu
  lines per page

  \## Changed

  \- Reorganized
  `sgnd-console` and
  `sgnd-console-menu`
  into logical sections
  for improved
  maintainability.

  \## Fixed

  \- Framework settings
  are now correctly
  restored when scripts
  are started outside
  the console. -
  Restored menu page
  height is now applied
  before the first
  console render.
  ---------------------

# Version 1.6 (Build 2618912) - 2026-07-02

## Added

-   Introduced configurable console log levels, including the new
    default **Silent** mode.
-   Added extensive smoke tests for logging and progress bars.
-   Added a framework styled MOTD.
-   Introduced progress update intervals to improve performance.

## Changed

-   Refactored executable bootstrap architecture by introducing
    `sgnd-exe-common.sh`.
-   Redesigned the first-time installation process.
-   Updated the installation guide and generated documentation.

## Fixed

-   Prevented recursive backup of `/var` during installation.
-   Corrected progress bar cursor positioning.
-   Fixed multi-level progress bar rendering.
-   Improved progress bar performance for large jobs.
-   Corrected framework license acceptance recording.
-   Fixed precedence of command-line log level over configuration.
-   Corrected clean installation defaults and startup sequence.
