# SolidGroundUX 2.1 Release Notes

**Version 2.1**

![SolidGroundUX 2.1](https://raw.githubusercontent.com/Testadura-Consultancy/SolidGroundUX/main/target-root/usr/local/assets/sux-readmelogo.png)


SolidGroundUX 2.1 is an architectural consolidation release with significant functional consequences.

Version 2.0 established the framework, modular Management Console, administration modules, documentation pipeline, development tooling, and formal release lifecycle as one coherent platform. Version 2.1 consolidates the contracts underneath that platform: where the framework lives, how projects identify themselves, how canonical bootstrap code is maintained, how products are assembled into releases, and how source documentation becomes published documentation.

The central architectural change is the removal of an unnecessary distinction between framework and application roots. SolidGroundUX now derives one `SGND_FRAMEWORK_ROOT` directly from the physical location of the executing component. Around that simpler bootstrap model, 2.1 introduces canonical source normalization, project definitions and workspace scaffolding, product-aware release preparation, self-describing release packages, and the standalone `sgnd-setup` lifecycle and recovery tool.

The consolidation ultimately exposed a larger architectural boundary that had previously been implicit: SolidGroundUX is no longer treated as one monolithic product repository. The platform is now separated into three independently maintained products: **SolidGroundUX** for the framework/runtime, **SolidGroundUX Management Console Modules** for the administration application and its modules, and **SolidGroundUX SDK** for development, documentation, workspace, and release tooling. MCM and SDK depend on the Framework, but not on each other.

That physical separation also made framework-resource resolution explicit. A component running from a non-Framework development workspace keeps its own contextual `SGND_FRAMEWORK_ROOT`, while Framework-owned resources are resolved from a local Framework when present and otherwise fall back to the installed Framework. This preserves staged-development semantics without recreating the removed application-root concept.

Those architectural changes also enabled visible improvements to everyday development and operation. Framework arguments are order-independent, workspaces can establish new projects from canonical conventions, release preparation can prepare multiple products without confusing their identities, setup and recovery operations share one interface, and the documentation pipeline has grown into a substantially richer publishing system while keeping source comments as its authoritative input.

The result is not merely less configuration and duplicated bootstrap logic. SolidGroundUX 2.1 provides a clearer and more capable path from source tree to development workspace, from documented code to published
documentation, and from prepared products to installed and recoverable systems.

## Highlights

### One framework root

SolidGroundUX no longer requires `SGND_APPLICATION_ROOT` or the former `solidgroundux.cfg` bootstrap configuration.

Executables derive `SGND_FRAMEWORK_ROOT` from their physical path by locating the last `usr`, `etc`, or `var` component. This gives production and development trees the same filesystem contract:

``` text
/usr/local/bin/...                                      -> /
/etc/solidgroundux/...                                  -> /
/srv/storage/development/SolidGroundUX/target-root/usr/... -> /srv/storage/development/SolidGroundUX/target-root
```

A development `target-root` therefore behaves like a staged installation root without requiring a separate application-root configuration.

This removes first-run root questions from normal framework bootstrap and eliminates a substantial amount of path-specific configuration.

### Three product architecture

SolidGroundUX 2.1 formalizes three product boundaries that were previously combined in one development tree:

- **SolidGroundUX** owns the framework runtime, bootstrap, shared libraries, UI primitives, generic APIs, framework smoke tests, and core archive helpers.
- **SolidGroundUX Management Console Modules** owns the Management Console host, console-specific behavior, module discovery and registration, administration modules, and console validation.
- **SolidGroundUX SDK** owns workspace creation and deployment, canonical preparation, documentation generation, release preparation, release preparation tooling, and other development/release utilities.

MCM and SDK both consume SolidGroundUX Framework services. Neither product depends on the other. Each product has its own repository, definitions, release identity, documentation collection, and lifecycle.

The split deliberately tests architectural ownership: code that only worked because another component happened to be adjacent in the old repository must now resolve its dependency through an explicit product contract.

### Framework resource resolution

`SGND_FRAMEWORK_ROOT` remains the contextual root derived from the executing component. It is not rewritten merely because an SDK or MCM development tree does not contain the Framework.

Framework-owned resources are instead resolved through the framework resolver. A real local Framework is preferred when present; otherwise the installed Framework beneath `/` is used. If a local Framework exists but a requested Framework resource is absent, the installed copy is the fallback.

This allows development executables in independently checked-out SDK and MCM workspaces to use an installed Framework while preserving their own development-root semantics for product configuration, state, and project paths.

### Canonical bootstrap generation

The small pieces of code that necessarily exist before the framework can load itself are now treated as generated canonical fragments rather than dozens of independently maintained copies.

`normalize-canon.sh` normalizes the framework locator in executables and the library guard in sourced libraries and modules. It skips the canonical source fragments themselves, validates modified shell files with `bash -n`, and uses checksum comparison to determine whether a file actually changed.

`prepare-release.sh` invokes canonical normalization before release metadata and artifacts are produced, ensuring released bootstrap code comes from the canonical definitions.

The library guard also now avoids early metadata initialization until the comment-header parser is available, removing a bootstrap dependency cycle exposed during the 2.1 conversion.

### Order-independent argument handling

Framework built-in arguments can now be mixed naturally with
script-specific options.

Bootstrap extracts recognized framework arguments while preserving
unknown arguments, their order, and positional data for the script's own
parser. The standard `--` marker remains an absolute end-of-options
boundary.

Built-ins such as execution mode, automatic operation, state reset, and
title control can therefore be supplied without requiring callers to
know which parser runs first.

This also fixes early bootstrap values such as `--auto` being lost when
arguments were parsed again later in the executable lifecycle.

### Project-aware workspaces

`create-workspace.sh` has evolved from a SolidGroundUX-specific helper
into project scaffolding for software built around the framework
conventions.

A workspace can establish the canonical `target-root` structure, create
project definitions under:

``` text
/usr/local/lib/solidgroundux/globals/
```

and optionally create starter executables, libraries, modules,
templates, project MOTD integration, a local Git repository, and a
GitHub repository.

Project identity uses namespaced definition variables rather than
overloading SolidGroundUX framework identity.

The workspace creator can initialize `main`, create the initial commit,
create a public or private GitHub repository through the authenticated
GitHub CLI account, and push the initial branch.

### Project definitions

Project identity is now deployable runtime information rather than
repository-only metadata.

SolidGroundUX retains its canonical `sgnd-definitions.sh`, while
additional projects can provide:

``` text
<project>-definitions.sh
```

beneath the shared globals directory.

These files carry project-specific product, version, and build identity.
Bootstrap loads the foundational SolidGroundUX definitions and
additional project definition files from the globals directory.

Release preparation uses the appropriate definitions file as the
authoritative project release identity.

### Product release packages

Prepared releases now have an explicit product-package contract.

Every distributable product release ZIP contains a `release-package.info`
shipping label identifying package format 3, package type `product`, project,
product, version, build, and exact release identity.

A product release ZIP contains the canonical release artifacts:

``` text
release-package.info
<Product>-<release>.tar.gz
<Product>-<release>.tar.gz.sha256
<Product>-<release>.manifest
<Product>-<release>.manifest.sha256
<Product>-<release>.removed
<Product>-<release>.removed.sha256
```

The ZIP is the distributable unit. The tar archive, manifest and removal
metadata are package-internal installation artifacts rather than additional
standalone release outputs.

First installation is transported separately through a first-install ZIP that
contains `sgnd-setup.sh` beside one or more normal product release ZIPs. Product
packages therefore remain identical whether they are installed during first
setup, from a local package store, or after acquisition from GitHub.

The deployed definitions file remains the runtime authority after installation;
`release-package.info` is the transport-level identity used to validate and
admit the package.

### Product-aware release preparation

Release preparation treats products as peers rather than assuming that one
global version/build policy describes everything being packaged.

Every selected product is emitted as its own release ZIP and retains its own
identity and release metadata. Multi-product bundled release ZIPs are no longer
produced, and there is no primary product whose identity is borrowed by other
products.

`prepare-release.sh` can prepare several selected products in one run, clean up
intermediate loose tar/manifests/checksums after successful packaging, and place
only the final product ZIPs and optional first-install transport ZIP in the
chosen release-output directory.

The first-install transport replaces the former bundle role: it contains
`sgnd-setup.sh` and the selected normal product ZIPs without changing those
products' identities or package contracts.

This makes multi-product preparation deterministic while preserving a simpler
rule: each product owns its own release identity and every installation path
consumes the same product package.

### Documentation as a publishing system

The documentation pipeline remains source-driven, but 2.1 substantially
expands what can be expressed and published from those source comments.

Documentation generation supports richer style hints, image groups, semantic
tables using `::` cell separators, explicit `. Table` / `. EndTable` blocks,
and proportional-font alignment columns using `<>`. Alignment is a presentation
construct rather than a semantic table, allowing ordinary documentation text to
line up without forcing monospace output.

The generator is also product-aware. Documentation collections can parse all
sources, selected sources, changed sources, or reuse existing normalized data.
Those modes now control the **source parsing phase only**: after parsing, the
renderer always rebuilds the complete site. This prevents renamed or removed
sources from leaving stale generated pages behind.

Persistent parser and renderer caches are kept outside the publishable site
beneath:

``` text
/usr/local/share/doc-sources/.cache/<site-slug>/parser
/usr/local/share/doc-sources/.cache/<site-slug>/renderer
```

The active framework root is applied to those paths in staged/development
trees. Local rendering is staged into a fresh `<site>.new` tree and replaces the
previous site only after a successful complete render. Git publication follows
the same complete-site staging principle.

Per-product `.docignore` rules can exclude product-specific source material,
and multi-product asset collection handles duplicate names deterministically
with warnings rather than silent replacement. The normalized documentation
contract remains the boundary between processing and rendering, keeping the
publishing features independent of the source-language parser.

### Setup, installation and recovery

`sgnd-setup` is the standalone lifecycle entry point for first installation,
local or GitHub installation/update, rollback, removal, package management, and
recovery. It deliberately remains usable before the SolidGroundUX framework is
installed or when the installed framework is damaged.

A clean-machine workflow begins with the first-install transport:

``` bash
unzip SolidGroundUX-first-install-<release>.zip
sudo ./sgnd-setup.sh
```

The transport contains `sgnd-setup.sh` plus normal product release ZIPs. Setup
discovers adjacent product packages, admits them to the canonical package
store, allows one or more products to be selected, and installs them through the
same package pipeline used later for local or GitHub packages.

After installation, the canonical setup copy lives beneath:

``` text
/var/lib/solidgroundux/sgnd-setup.sh
```

The Setup dashboard presents installed, newest local and newest GitHub versions
per known product. Product source directories are transient operation input;
successfully installed original product ZIPs are archived while extracted
release history remains available for rollback and removal.

Setup also includes deliberately destructive recovery cleanup levels:
`1kt` removes generated state/logs, `1mt` removes installed SolidGroundUX code,
and `tsar` removes code, configuration, state and logs. Their scope is derived
from the same framework-root location rules rather than an arbitrary caller
path.

### One lifecycle interface

Lifecycle operations are no longer duplicated across the Management Console.
The SolidGroundUX console page exposes a single **Setup** entry that delegates to
the canonical standalone setup tool. Interactive and command-line operation use
the same underlying product/package model.

After a first installation, Setup can offer **Setup**, **Management Console**, or
**Exit**, while remaining framework-independent during bootstrap and recovery.

### Declarative filesystem permissions

SolidGroundUX 2.1 introduces `SGND_SHARE_DIR` as the rebased framework path for
shared product data:

``` text
/usr/local/share/solidgroundux
```

In a staged development tree the same variable resolves beneath the active
`SGND_FRAMEWORK_ROOT`.

The framework also provides `sgnd-repair-permissions.sh`, backed by the
`permissions.dta` policy in `SGND_SHARE_DIR`. The policy can declare ownership
and modes for exact files/directories, direct-child masks, recursive `**`
selection and ordinary glob masks. The symbolic `operator` owner resolves to the
invoking administrative user while framework executables and public wrappers
can be restored to their expected root ownership and executable modes.

The initial policy covers SolidGroundUX `libexec` executables, public `sgnd*`
wrappers and the operator-writable documentation cache. The repair engine does
not follow symlinks during recursive traversal.

### Administration workflows and Management Console

The Management Console now treats `Esc` as the canonical return/exit control,
uses transactional lazy module loading, and exposes loaded-module metadata for
runtime diagnostics. Compound workflows propagate child-action completion into
the console so preparation/provisioning steps remain visible after the action
returns.

The 2.1 administration pass also completed and validated the major server
workflows: Active Directory server/client/management, Storage, Samba File
Server in both standalone and Active Directory modes, Web Server/publishing,
SQL Server, and Docker. Samba transitions between standalone and AD-backed
authentication were verified in both directions, and AD client leave-domain was
verified to complete in a single operation.

## What's New in 2.1

### Bootstrap and framework location

-   Removed the `SGND_APPLICATION_ROOT` runtime concept.
-   Formalized independent Framework, Management Console Modules, and SDK product/repository boundaries.
-   Added Framework-resource resolution so SDK and MCM development workspaces can consume an installed Framework without changing their contextual `SGND_FRAMEWORK_ROOT`.
-   Local Framework resources take precedence when a real Framework is present; installed Framework resources provide the fallback.
-   Removed the former `solidgroundux.cfg` bootstrap/root-discovery
    workflow.
-   Added deterministic `SGND_FRAMEWORK_ROOT` derivation from the
    physical script path.
-   Production paths resolve naturally to `/`; staged development
    `target-root` trees resolve to their containing root.
-   Framework location no longer requires interactive first-run
    configuration.
-   Framework and application code now share one root contract.
-   Bootstrap environment rebasing follows `SGND_FRAMEWORK_ROOT`.
-   The globals directory is exposed through `SGND_GLOBALS_FOLDER`.
-   Added canonical `SGND_SHARE_DIR`, rebased as
    `$SGND_FRAMEWORK_ROOT/usr/local/share/<product>`, for shared product data.

### Canonical source normalization

-   Added canonical `_framework_locator` normalization for executables.
-   Added canonical `_sgnd_lib_guard` normalization for libraries and
    modules.
-   Canonical source fragments are excluded from normalization.
-   Existing Bootstrap sections are preserved when only the locator
    function is replaced.
-   Library-guard sections can be replaced as a complete canonical unit.
-   Modified shell files are checked with `bash -n`.
-   Checksum comparison prevents unchanged normalized files from being
    treated as modifications.
-   Release preparation runs canonical normalization before packaging.
-   Library metadata initialization is deferred until the header parser
    required by metadata processing is available.

### Arguments and executable lifecycle

-   Framework built-ins are extracted independently of their position
    before `--`.
-   Non-framework arguments remain available to script-specific parsing
    in their original order.
-   Positional arguments after `--` are preserved untouched.
-   Added preservation of unknown arguments during the bootstrap parsing
    pass.
-   Fixed framework defaults being reinitialized by a later parsing
    pass.
-   `--auto` now survives the complete bootstrap/script argument
    lifecycle.
-   Built-in execution controls include dry-run/commit, automatic
    operation, state reset, and title handling.

### Workspace and project creation

-   `create-workspace.sh` now creates project-aware target-root
    workspaces.
-   Added project definitions under
    `usr/local/lib/solidgroundux/globals`.
-   Added namespaced product, version, and build variables for
    non-framework projects.
-   Added optional project MOTD generation using `95-<project>`.
-   Workspace templates are copied as deployable template files while
    canonical normalization sources remain framework-owned.
-   `templates_preface.sh` is excluded from normal workspace template
    copying.
-   Module projects use a project-specific
    `usr/local/libexec/solidgroundux/<project>/` location.
-   Removed the former module application-configuration scaffolding.
-   Added optional local Git initialization.
-   Added optional GitHub repository creation through `gh`.
-   GitHub creation displays the authenticated account, repository,
    visibility, and branch before confirmation.
-   Newly created repositories use `main` and are pushed explicitly
    after creation.
-   Interactive workspace creation provides a short auto-continue
    completion window.

### Project identity and globals

-   Introduced `SGND_GLOBALS_FOLDER`.
-   Moved project identity toward the shared globals directory.
-   SolidGroundUX continues to use `sgnd-definitions.sh` for framework
    identity.
-   Additional projects use `<project>-definitions.sh`.
-   Bootstrap loads additional project definition files after the
    foundational framework definitions.
-   Project definitions are deployable runtime code and are not treated
    as ordinary `SGND_USING` dependencies.
-   Project MOTD scripts can obtain version/build identity from the
    corresponding project definitions.

### Release preparation

-   `prepare-release.sh` is project-aware and product-aware.
-   Project identity is resolved from the definitions files beneath the staged
    target root.
-   Version and build updates are applied to the appropriate authoritative
    project definitions.
-   Added package-format-3 `release-package.info` to every distributable product
    release ZIP, with `SGND_PACKAGE_TYPE=product`.
-   Every selected product is emitted as its own release ZIP; multi-product
    bundled release ZIPs and primary-product bundle identity have been removed.
-   Added a separate first-install transport ZIP containing `sgnd-setup.sh` and
    selected normal product release ZIPs.
-   Added a configurable release-output directory that is persisted for reuse.
-   Successful packaging cleans loose `tar.gz`, manifest, removed-manifest and
    checksum staging artifacts so the output directory contains only final ZIPs.
-   Package admission, rather than package preparation, populates managed
    release state.
-   Each product retains its own release identity and metadata regardless of
    whether it is installed alone or through the first-install transport.

### Setup

-   Replaced the former Release Manager lifecycle entry point with standalone
    `sgnd-setup`.
-   Added package-format-3 identity parsing through `release-package.info`.
-   Added a product-centric dashboard showing installed, newest local and
    newest GitHub release identities.
-   Added discovery of product ZIPs beside Setup, in the canonical local package
    store, and in an operator-selected directory.
-   First install discovers adjacent product ZIPs, admits them to the canonical
    package store, allows multi-product selection and installs through the same
    normal package pipeline.
-   SolidGroundUX retains its canonical release/archive state below
    `/var/lib/solidgroundux`; companion products retain independent project
    release history.
-   Successful installs archive the original product ZIP while preserving
    extracted release history for rollback/removal.
-   Package source paths are transient operation input rather than persisted
    product state.
-   Retained installation/update, rollback, reinstall and removal workflows.
-   Added deliberately destructive `--nuke` recovery yields: `1kt` for
    state/logs, `1mt` for installed code, and `tsar` for code/config/state/logs.
-   Installed Setup is kept at `/var/lib/solidgroundux/sgnd-setup.sh` for future
    lifecycle and recovery operations.
-   First-install completion offers **Setup**, **Management Console**, or
    **Exit** without requiring framework UI availability.

### Management Console

-   Renamed the lifecycle entry from **Release manager** to **Setup** and
    delegated it to the canonical `sgnd-setup` executable.
-   Changed Management Console navigation so `Esc` returns from module pages and
    confirms exit from the main index; `Q/q` is no longer the console exit key.
-   Added a loaded-module registry view under Framework Diagnostics with
    selectable canonical metadata including Description.
-   Made lazy module loading transactional so registrations created by a failed
    load are rolled back before retry.
-   Standardized action endings so workflows that redraw immediately do not add
    a redundant completion wait.
-   Compound AD, Storage, Samba, Web Server and SQL Server workflows now retain
    child-action completion state in the console.
-   Removed the obsolete repository-mirroring action from the Development
    module.
-   Development and release tooling remains owned by the separate SolidGroundUX
    SDK rather than the Management Console product.

### Wrapper generation

-   Wrapper creation can use an explicit `Wrapper` metadata field when a
    script's public command name differs from the source filename.
-   Existing filename-derived wrapper behavior remains the fallback.
-   Release preparation uses the same wrapper identity when validating
    required public commands.
-   Wrapper output is derived from the root belonging to the selected
    source tree rather than assuming the currently running framework
    root.

### Shared product data and permission repair

-   Added canonical `SGND_SHARE_DIR` for shared product data beneath
    `/usr/local/share/<product>` within the active framework root.
-   Added Framework-owned `sgnd-repair-permissions.sh`.
-   Added declarative `permissions.dta` as the default permission policy in
    `SGND_SHARE_DIR`.
-   Permission rules support files/directories, exact targets, direct-child
    `*`, recursive `**`, and ordinary glob file masks.
-   Added symbolic `operator` ownership for paths that must remain writable by
    the invoking administrative user.
-   The initial policy restores executable ownership/modes for SolidGroundUX
    `libexec` content and public `sgnd*` wrappers, and operator ownership for the
    documentation cache.
-   Recursive permission repair does not follow symlinks.

### Framework testing and UI

-   Framework Test menu actions that conflicted with global console
    shortcut keys were converted to numbered menu entries.
-   Smoke-test choice handling accepts multi-digit menu selections.
-   Canonical comments now distinguish full function contracts from
    concise headers for simple helpers.
-   Every documented function requires at least one concrete `. Usage`
    example.
-   Function documentation is expected to remain proportional to
    behavioral complexity rather than repeating boilerplate.

### Documentation and Canon

-   The documentation pipeline remains source-driven and preserves the
    normalized processor/renderer contract.
-   Added explicit documentation tables using `. Table` and
    `. EndTable`, with `::` separating cells.
-   The first table row is rendered semantically as the header;
    following rows form the table body.
-   Documentation style hints can be applied to table rows without
    changing table structure.
-   Blank-line table termination remains supported for compatibility.
-   Added proportional-font alignment columns using `<>` for visually
    aligned ordinary documentation without table semantics.
-   Added a literal/parser modifier `@` to the documentation dialect;
    complete suppression of later structural interpretation remains an
    implementation area for follow-up where newer constructs such as
    alignment are involved.
-   Expanded documentation syntax guidance and the documentation
    template quick reference.
-   Documentation generation supports Full, Selected, Changed and Render modes,
    with those modes controlling source parsing only; every render rebuilds the
    complete site.
-   Added per-product `.docignore` configuration so product-specific
    source files can be excluded from a documentation collection.
-   Documentation ignore configuration follows framework system/user
    configuration locations rather than repository-local ad-hoc files.
-   Multi-product documentation asset collection uses deterministic
    first-wins handling with warnings for duplicate asset names.
-   Parser and renderer caches are stored outside the publishable site under
    `usr/local/share/doc-sources/.cache/<site-slug>/`.
-   Local site output is staged into a fresh `<site>.new` tree and replaces the
    previous site only after a successful complete render.
-   Git publication also stages a complete fresh tree before replacement.
-   Documentation output defaults can be seeded from framework configuration
    while the renderer always receives the final resolved output directory.
-   Published collections can be separated beneath the shared documentation
    output location by site name.
-   Deployment documentation now describes product packages and Setup-managed release state.
-   First-install documentation reflects the `sgnd-setup` transport model.
-   Release documentation distinguishes workspace build output from installed Setup/release state.
-   The Canon now uses `SGND_FRAMEWORK_ROOT` consistently.
-   Obsolete application-root and bootstrap-configuration rules have
    been removed.
-   Canonical argument parsing documents order-independent framework
    built-ins and the `--` boundary.
-   Function documentation rules now explicitly allow concise contracts
    for simple helpers while requiring usage examples.
-   Installer rules now cover product package identity, first-install transport,
    standalone Setup/recovery behavior, and independent product lifecycle state.

### Administration modules and validation

-   Active Directory Server provisioning now reports tracked child actions and
    was validated end-to-end including DNS, Kerberos, LDAP and registration.
-   Active Directory Management supports multi-select user/group actions.
-   Active Directory Client join/leave and reconciliation include keytab
    validation/repair; leave-domain was verified to clear membership in a single
    operation.
-   Storage can reconcile restored/reattached managed volumes whose UUID no
    longer matches the SolidGroundUX-managed `fstab` entry.
-   Samba File Server detects AD membership to select ADS or standalone mode,
    supports richer share/directory/ACL management, multi-group rights
    assignment, standalone Samba user/group management, and validated
    standalone <-> AD transitions.
-   Web Server preparation/publishing reports child completion and supports
    document-root management; publishing was validated end-to-end.
-   SQL Server preparation reports persistent child-action progress.
-   Docker host/container management was completed and validated for image
    pulls, container creation, port publishing, environment variables and host
    storage mounts.

## Compatibility and Migration

### `SGND_APPLICATION_ROOT`

`SGND_APPLICATION_ROOT` is removed from the 2.1 architecture.

Code that previously used it to address files beneath the staged or
installed tree should use `SGND_FRAMEWORK_ROOT`.

### Bootstrap configuration

The former `solidgroundux.cfg` framework/application-root discovery file
is no longer part of normal bootstrap.

Executables locate the framework from their own physical path. Existing
deployment or development procedures that create this file solely for
root discovery should remove that step.

### Canonical bootstrap copies

Bootstrap locator and library-guard implementations should no longer be
maintained independently.

Run canonical normalization after changing the canonical fragments and
before preparing a release.

### Project definitions

Projects built around SolidGroundUX should keep their runtime identity
in the shared globals directory using a project definitions file.
Release preparation uses that identity when constructing packages.

### Release packages

2.1 packages include `release-package.info`. Tools that inspect or
transport release ZIPs should preserve this file at ZIP root.

The package label identifies the transport package; it does not replace
the deployed definitions file.

### Setup

Existing SolidGroundUX release/archive locations remain valid, but lifecycle
entry is now `sgnd-setup` rather than the former Release Manager.

The first-install ZIP contains `sgnd-setup.sh` and normal product ZIPs. After
installation the canonical copy is kept at:

``` text
/var/lib/solidgroundux/sgnd-setup.sh
```

Management Console users should use the single **Setup** entry for lifecycle
operations.

### Shared product data

Framework code that needs the canonical shared product-data location should use
`SGND_SHARE_DIR` rather than repeating `/usr/local/share/solidgroundux`.

`SGND_SHARE_DIR` is rebased with `SGND_FRAMEWORK_ROOT`, so the same contract
works in production and staged `target-root` trees. Migrating remaining
hard-coded usages is a follow-up cleanup rather than a requirement for existing
2.1 scripts.

### Repository synchronization

The former repository synchronization tool and Development-module
**Mirror repository** action are no longer part of the 2.1 development
workflow. GitHub is the canonical repository/backup path, while
`deploy-workspace.sh` remains the fast path for deploying development
changes to target systems.

## Release Workflow at a Glance

The 2.1 release path is deliberately small and product-oriented:

``` text
Development workspaces
        |
        v
normalize-canon.sh
        |
        v
prepare-release.sh
        |
        +--> SolidGroundUX-<release>-release.zip
        +--> SolidGroundUX-MCM-<release>-release.zip
        +--> SolidGroundUX-SDK-<release>-release.zip
        |
        +--> optional first-install transport
             - sgnd-setup.sh
             - selected product release ZIPs
        |
        v
GitHub / canonical local package store / another package directory
        |
        v
sgnd-setup
        |
        +--> validate and admit product package(s)
        +--> install / update / rollback / remove
        |
        v
Target root + per-product release history
```

Product release ZIPs have the same contract regardless of acquisition path.
The first-install ZIP is transport only; it does not create a different package
type for the contained products.

`deploy-workspace.sh` remains outside this formal lifecycle. It is the
development transfer path and does not create installed release history.

## Reliability and Fixes

The 2.1 work resolves several architectural problems that were difficult to
eliminate cleanly while retaining the older bootstrap and release models.

Notable fixes include framework-root ambiguity between production and
development trees, repeated maintenance of locator and guard fragments,
bootstrap metadata initialization before its parser dependency was available,
framework arguments being reset during later parsing, public wrapper generation
against the wrong staged root, non-interactive deployment receiver hangs,
stale documentation pages surviving incremental runs, parser/renderer cache
state being mixed with publishable documentation, Samba authentication and ACL
transition defects, and AD client leave-domain requiring more than one pass.

The release workflow now has a clearer ownership model: SDK tools create normal
product packages, packages describe themselves, `sgnd-setup` admits and installs
them, and installed per-product state records their lifecycle. Filesystem
ownership and executable modes can be reconciled independently through the
Framework permission-policy engine.

## SolidGroundUX 2.1

Version 2.1 is less about adding another layer to SolidGroundUX than making the
existing layers agree on their responsibilities.

The framework no longer needs a separate application-root concept to know where
it lives. Bootstrap fragments no longer need to drift independently across
dozens of files. Products no longer need to share one accidental release
identity or be assembled into a special combined bundle. The Management Console
no longer duplicates lifecycle operations, and first installation, updates,
rollback, removal and recovery now converge on `sgnd-setup`.

The same consolidation extends into documentation. Source comments remain the
authoritative documentation source, while the processor and renderer can
express richer presentation and maintain fast parser caches without allowing
incremental source work to leave stale published pages behind. Every render is a
fresh complete site replacement.

The runtime contract has also become more explicit. Shared product data has a
canonical `SGND_SHARE_DIR`, while declarative permission policy provides a
repeatable way to repair ownership and executable modes without embedding those
rules throughout setup and management code.

That combination makes SolidGroundUX easier to reason about as both a framework
and a development platform, while the completed administration pass validates
the same architecture against real server roles: Active Directory, storage,
Samba, web publishing, SQL Server and Docker.

The development tree mirrors the installed filesystem. Canonical fragments
define the unavoidable pre-framework bootstrap code. Project definitions
establish runtime identity. Documentation processing turns source comments into
normalized, publishable content. `prepare-release.sh` emits self-describing
product packages. `sgnd-setup` takes responsibility from there.

The result is a cleaner boundary between development, documentation, packaging,
installation and operation --- with fewer special cases between them and more
useful behavior built on top.

**One root. Explicit product identity. Predictable tooling. Self-describing
releases. One setup path. Documentation from the source.**

