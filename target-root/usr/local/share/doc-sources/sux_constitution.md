# Preamble

Every framework begins with code.

The best frameworks begin with principles.

SolidGroundUX was never intended to become merely another collection of Bash libraries. It was created to establish a common language for scripts; a language in which behaviour is consistent, interfaces are predictable, and every component respects both the operator and the maintainer.

This document records those principles.

They are not intended to prevent innovation. They exist to ensure that innovation strengthens the framework instead of fragmenting it.

Where implementation, documentation, historical practice, or personal preference disagree, these principles take precedence until they are consciously revised.

We hold these principles to be self-evident:

- *That software should be understandable, maintainable and predictable.*
- *That consistency outweighs novelty.*
- *That technology exists to serve its users.*
- *That every contribution should leave the framework stronger than it was found.*

These principles are not immutable.

They may be challenged, refined, or replaced as experience demands. But while they remain part of this canon, they define the standard by which SolidGroundUX is designed, implemented, and maintained.

Everything that follows is an expression of these principles.

---

# Declaration of Principles

Four score and many scripts ago, in an age of improvised shell fragments, duplicated checks, arbitrary colours, silent failures, unexplained side effects, and command lines known only to their authors, a simple idea emerged:

**A script should not demand attention merely because it exists.**

It should announce itself clearly, ask only what it must know, do precisely what it promised, report what matters, and then get out of the way.

SolidGroundUX was not created because Bash lacked commands. It was created because commands alone do not create a dependable system.

A collection of scripts becomes a system only when they speak the same language, obey the same rules, expose the same structure, and treat the operator with the same respect.

The operator should not have to rediscover how each script works.

The maintainer should not have to remember which function logs, which function prints, which variable contains state, which module invents its own colours, or which installer quietly changes ownership of an existing system directory.

The framework exists to remove those uncertainties.

SolidGroundUX therefore establishes a common ground:

- one lifecycle;
- one vocabulary;
- one approach to arguments and state;
- one visual language;
- one error model;
- one documentation standard;
- one release discipline;
- and one expectation of behaviour.

The canon is not a catalogue of stylistic preferences.

It is a declaration that predictable behaviour is a feature.

It is a declaration that clarity outranks cleverness.

It is a declaration that an interface must serve the operator rather than display the ingenuity of its author.

It is a declaration that automation must remain observable, reversible where practical, and honest about what it has changed.

It is a declaration that defaults are part of the design, not an excuse to avoid design.

It is a declaration that naming is architecture, comments are contracts, logs are evidence, and errors are control flow.

It is a declaration that consistency is not bureaucracy when it removes friction.

The framework shall be opinionated where inconsistency would impose a cost on every future script. It shall remain permissive where variation is useful and harmless.

It shall not force ceremony upon trivial work.

It shall not hide destructive actions behind convenience.

It shall not confuse silence with elegance.

It shall not mistake more options for a better interface.

It shall not claim success before the underlying operation has succeeded.

It shall not mutate the host merely because it can.

It shall not invent commands, states, files, or guarantees that do not exist.

It shall prefer explicit behaviour over inference, stable contracts over accidental compatibility, and readable code over compressed code.

And above all:

> **SolidGroundUX shall help the user complete the task, then get out of the way.**

Everything that follows is an implementation of that principle.

---

# 1. Canonical Vocabulary

## 1.1 Normative Terms

The key words **MUST**, **MUST NOT**, **REQUIRED**, **SHALL**, **SHALL NOT**, **SHOULD**, **SHOULD NOT**, **RECOMMENDED**, **MAY**, and **OPTIONAL** are to be interpreted as normative requirements.

- **MUST / SHALL** indicates a mandatory rule.
- **SHOULD** indicates the default rule. Deviations require a reason.
- **MAY** indicates an allowed option.
- **Canonical** means approved as the standard implementation or pattern.
- **Legacy** means retained for compatibility but no longer preferred.
- **Deprecated** means scheduled for removal or replacement.
- **Application** means a program built on the SolidGroundUX framework.
- **Framework** means the reusable runtime, libraries, UI primitives, and conventions.
- **Module** means a discoverable application component hosted by a SolidGroundUX application.
- **Operator** means the person running or administering the software.

## 1.2 Product Names

The following names are canonical:

- **SolidGroundUX** — the Bash framework and associated runtime.
- **SolidGroundUX Management Console Modules** — the modular administration application, console host, and administration modules built on SolidGroundUX.
- **SolidGroundUX SDK** — the development, documentation, workspace, and release tooling built on SolidGroundUX.
- **SolidGround Management Console** — the operator-facing name of the Management Console application.
- **Testadura Consultancy** — the legal or formal company identity.
- **Testadura** — the preferred public-facing brand name where the legal suffix is unnecessary.

The abbreviation `sgnd` is reserved for framework functions, variables, paths, and internal identifiers. It is not, by itself, a command and MUST NOT be presented as one unless such a command is explicitly implemented.

---

# 2. Governing Principles

## 2.1 Get Out of My Way

Every interaction MUST justify its existence.

A script SHOULD:

1. state what it is;
2. state what it is about to do when the action is material;
3. ask only for information it cannot safely determine;
4. provide useful defaults;
5. perform the requested work;
6. report the outcome;
7. terminate with an accurate exit status.

A script SHOULD NOT require confirmation for harmless and easily reversible actions.

A script MUST request confirmation before destructive, disruptive, security-sensitive, or difficult-to-reverse actions unless the operator explicitly selected a non-interactive mode that already constitutes informed consent.

## 2.2 Predictability Over Cleverness

Canonical code MUST favour behaviour that another maintainer can infer without tracing hidden side effects.

Do not compress control flow merely to reduce line count.

Do not use obscure shell constructs where a direct form is equally effective.

Do not dynamically construct names, commands, or variable references unless the abstraction provides a clear benefit and is documented.

## 2.3 Explicit Over Implicit

Important behaviour MUST be visible in one or more of the following:

- function name;
- function contract;
- argument;
- configuration;
- state declaration;
- log entry;
- confirmation prompt;
- documentation.

The framework MUST NOT depend on undocumented ambient state.

## 2.4 Consistency Is a Feature

Equivalent actions SHOULD look, read, log, and fail in equivalent ways.

A new primitive or convention SHOULD NOT be introduced when an existing canonical primitive already solves the problem adequately.

## 2.5 The Operator Remains in Control

Automation MUST NOT conceal meaningful decisions.

Where practical, the operator SHOULD be shown:

- current value;
- proposed value;
- effect of the change;
- whether a restart or reboot is required;
- whether the change is immediate or deferred.

## 2.6 Truthful Interfaces

A success message MUST only be emitted after success has been established.

A progress indicator MUST NOT imply completion before completion.

A dry run MUST NOT perform the action it claims to skip.

A status display MUST distinguish between:

- configured;
- available;
- active;
- successful;
- and merely attempted.

---

# 3. Repository and Filesystem Structure

## 3.1 Framework and Application Separation

The framework and the application MUST remain conceptually separate.

Canonical product relationship:

```text
SolidGroundUX Framework
├── SolidGroundUX Management Console Modules
│   └── Lazy-loaded console pages
└── SolidGroundUX SDK
    └── Development, documentation, workspace and release tooling
```

The Framework supplies reusable runtime behaviour, bootstrap, shared libraries, UI primitives, and generic APIs.

The Management Console product supplies the console host, purpose, menus, module discovery, registration, administration workflows, and console modules.

The SDK supplies development-time tooling. MCM and SDK MAY depend on the Framework but MUST NOT depend on each other merely to obtain shared functionality. Shared runtime functionality belongs in the Framework.

These products SHOULD remain independently maintainable and releasable. Physical repository separation MUST NOT be defeated by assumptions that sibling product source trees are present.

A module MUST NOT assume that it owns framework initialization.

## 3.2 Canonical Installed Paths

The canonical installation root is:

```text
/usr/local
```

Preferred paths include:

```text
/usr/local/lib/solidgroundux/
/usr/local/libexec/solidgroundux/
/usr/local/sbin/
/usr/local/bin/
/etc/solidgroundux/
/var/lib/solidgroundux/
/var/log/solidgroundux/
```

Console modules are discovered from:

```text
/usr/local/libexec/solidgroundux/console-modules/
```

During development, product-local installed paths MUST be derived from the contextual `SGND_FRAMEWORK_ROOT` rather than hard-coded throughout the codebase. The same installed-path contract therefore applies to `/` in production and to a staged `target-root` tree during development.

`SGND_FRAMEWORK_ROOT` MUST remain the contextual root established for the executing component. A non-Framework product MUST NOT rewrite it to `/` merely to reach an installed Framework. Framework-owned resources MUST instead be resolved through the canonical Framework resource resolver: use a real local Framework when present, otherwise use the installed Framework, with installed resources as fallback when a requested local Framework resource is absent. Runtime configuration, state, and project paths MUST retain their owning product's normal root semantics unless their own contract explicitly states otherwise.

## 3.3 Ownership

Installed framework and application trees under `/usr/local` MUST normally be owned by:

```text
root:root
```

Release archives MUST preserve intended ownership for installed files without overwriting metadata of existing parent system directories.

An installer MUST NOT change the ownership or mode of an existing system directory merely because the directory appears in an archive path.

## 3.4 Configuration Locations

Canonical configuration precedence is:

1. explicit command-line option;
2. user configuration;
3. system configuration;
4. framework default.

Framework configuration MUST use the current framework configuration files resolved by bootstrap. The former application-root bootstrap configuration and `solidgroundux.cfg` first-run creation workflow are obsolete and MUST NOT be reintroduced.

Configuration loading MUST be deterministic and documented. Executables MUST NOT require an application-root prompt merely to locate SolidGroundUX; `SGND_FRAMEWORK_ROOT` is derived from the executing path.

---

# 4. Script Anatomy

## 4.1 Canonical Section Order

Executable scripts SHOULD use the following order:

1. shebang;
2. file header;
3. shell options where applicable;
4. canonical framework locator;
5. script identity and framework-integration metadata;
6. local/global declarations;
7. function definitions;
8. main routine;
9. invocation of main.

Libraries SHOULD omit executable main flow unless designed to support direct execution.

## 4.2 Shebang

Canonical Bash scripts MUST begin with:

```bash
#!/usr/bin/env bash
```

An exception MAY be used where an absolute interpreter path is a deployment requirement.

## 4.3 Entry Point

Executable scripts SHOULD provide a single explicit main function.

Canonical pattern:

```bash
main() {
    _framework_locator || return $?
    sgnd_exe_start --state -- "$@" || return $?

    # Script logic.
}
```

The final invocation SHOULD preserve the exit status:

```bash
main "$@"
exit $?
```

Where framework initialization has stricter ordering requirements, that ordering is part of the contract.

For the SolidGround Management Console, canonical initialization may add console-specific path or host initialization after `sgnd_exe_start`.

`SGND_FRAMEWORK_ROOT` MUST be established by `_framework_locator` before framework libraries are loaded. The former separate application-root bootstrap contract is obsolete; `SGND_FRAMEWORK_ROOT` is the canonical location contract.

## 4.4 Functions

Functions MUST perform one coherent responsibility.

A function SHOULD be short enough that its control flow remains visible, but no arbitrary line limit is imposed.

Function names MUST communicate action and scope.

Function naming expresses three practical access levels:

- `sgnd_*` — public framework API intended for applications and tools.
- `_sgnd_*` — framework-internal or protected API shared by cooperating SolidGroundUX libraries and components.
- `_foo` — private implementation detail local to one script, library, or module.

Private script-local functions SHOULD begin with a single underscore:

```bash
_validate_input
_apply_network_config
```

Framework-internal helpers SHOULD retain the `sgnd` namespace while using a single leading underscore:

```bash
_sgnd_flag_is_on
_sgnd_console_render_togglebar
```

Framework-public functions MUST use the `sgnd_` prefix:

```bash
sgnd_print_labeledvalue
sgnd_check_license
```

Double underscores MUST NOT be used in canonical identifiers.

Historical `td_` prefixes MUST be replaced by `sgnd_` where the identifier belongs to SolidGroundUX.

## 4.5 Variable Scope

Function-local variables MUST be declared with `local`.

Global variables MUST use uppercase names.

Framework globals MUST use the `SGND_` prefix.

Flag variables SHOULD use the `FLAG_` prefix when they represent script execution options:

```bash
FLAG_DRYRUN=0
FLAG_SAVEPARMS=0
```

Boolean values MUST normally be represented as integers:

```bash
0  # false
1  # true
```

User-facing output SHOULD render these as meaningful text such as `Yes` and `No`.

---

# 5. Naming Conventions

## 5.1 Functions

Canonical function names:

```text
sgnd_<verb>_<object>     public framework API
_sgnd_<verb>_<object>   framework-internal / protected API
_<verb>_<object>        local/private implementation
```

Examples:

```bash
sgnd_print_labeledvalue
sgnd_terminal_width
_validate_ipv4_address
_generate_ssh_host_keys
```

Names SHOULD describe the observable operation, not the implementation detail.

Avoid names such as:

```bash
_do_it
_process
_handle
_helper
```

unless the surrounding scope makes their responsibility unambiguous.

## 5.2 Variables

Canonical examples:

```bash
SGND_VERSION
SGND_BUILD
SGND_FRAMEWORK_ROOT
SGND_CONSOLE_WIDTH
SGND_MAX_RENDER_WIDTH
```

Temporary variables SHOULD use descriptive lowercase names:

```bash
local hostname
local realm
local selected_option
```

Single-letter variables SHOULD be limited to conventional, tightly scoped usage.

## 5.3 Constants

Constants SHOULD be declared read-only where practical:

```bash
readonly SGND_COMPANY="Testadura Consultancy"
```

A value is not a constant merely because it is uppercase. Values intended to be modified by configuration MUST remain configurable.

## 5.4 Files

File names MUST use lowercase letters, digits, and hyphens unless an external convention requires otherwise.

Examples:

```text
sgnd-bootstrap-env.sh
sgnd-console-menu.sh
prepare-template.sh
set-identity.sh
```

Spaces in canonical script file names are prohibited.

---

# 6. Function Header Contracts

## 6.1 Requirement

Every documented function MUST have a canonical `fn:` or `fn$` marker and at least one `. Usage` example.

Public functions and non-trivial private functions SHOULD use the full canonical contract when their behavior warrants it. Simple private helpers SHOULD use a concise header rather than repeating boilerplate that adds no information.

Headers are contracts, not decoration. Comment size SHOULD be proportional to behavioral complexity.

## 6.2 Required Information

A full function header SHOULD document only the contract information that materially helps a caller or maintainer, including as applicable:

- purpose;
- parameters;
- output;
- return values;
- side effects;
- global variables read or modified;
- dependencies;
- notes or constraints.

A concise header MAY consist of the function marker, a short purpose, and `. Usage` when the function is self-explanatory and has no surprising contract.

Every function header, full or concise, MUST contain at least one `. Usage` example.

## 6.3 Usage Examples

Each function header MUST include exactly one or more concrete, informative `. Usage` examples; at least one is mandatory.

This is insufficient:

```bash
# sgnd_sgr "$value"
```

This is preferred:

```bash
# sgnd_sgr "Warning" "$FG_YELLOW" "$FX_BOLD"
```

Examples SHOULD demonstrate realistic values and the intended result.

## 6.4 Comment Accuracy

Comments MUST describe current behaviour.

When code changes, affected contracts and examples MUST be updated in the same change.

A stale comment is a defect.

---

# 7. Arguments and Command-Line Behaviour

## 7.1 Standard Arguments

Framework-supported built-ins MUST use their canonical semantics. Current built-ins include execution/state and presentation controls such as:

```text
--dryrun
--commit
--auto
--resetstate
--title
--no-title
```

Additional built-ins MAY be provided by bootstrap. Applications MAY add their own arguments but MUST NOT redefine framework argument semantics.

## 7.2 Root Requirements

Root requirements MUST be explicit.

A script requiring root SHOULD use the framework mechanism rather than duplicating an ad hoc UID check.

A script forbidden from running as root SHOULD declare that restriction explicitly.

## 7.3 Unknown Arguments

Unknown arguments MUST produce:

- a clear error;
- an accurate non-zero exit status;
- and, where useful, concise usage guidance.

Unknown arguments MUST NOT be silently ignored.

Framework built-ins and script-specific options MAY be freely intermixed before the standard `--` end-of-options marker. Recognized framework built-ins are extracted without reordering or discarding the remaining script arguments. Everything after `--` is positional data and MUST remain untouched.

## 7.4 Dry Run

A dry run MUST:

- show what would be done;
- avoid **all persistent changes**, including framework state/configuration writes and delegated actions;
- preserve validation where validation is safe;
- clearly identify skipped actions.

Dry-run output MUST NOT claim that changes were applied. A component that delegates work MUST propagate dry-run semantics to that work rather than relying only on its own top-level guard.

---

# 8. Return Values and Error Handling

## 8.1 Exit Status

Zero means success.

Non-zero means the requested operation did not complete successfully.

Scripts MUST return meaningful failure statuses and MUST NOT unconditionally exit with zero after a failed operation.

## 8.2 Error Propagation

Canonical propagation:

```bash
some_function || return $?
```

At the top level:

```bash
some_function || exit $?
```

Use grouped recovery only where the failure is intentionally handled.

## 8.3 Messages

The canonical failure primitive is:

```bash
sayfail
```

Do not invent or document non-existent primitives such as `sayerror`.

Message severity MUST reflect reality.

A warning is not a failure.

An informational message is not confirmation of success.

## 8.4 Partial Failure

When a multi-step operation partially succeeds, the script MUST state:

- what succeeded;
- what failed;
- whether the system is still usable;
- what remains to be done.

The final status MUST reflect the failure unless the failed step was explicitly optional.

## 8.5 Cleanup

Temporary resources SHOULD be cleaned with a controlled exit path or trap.

Cleanup MUST NOT remove user data or pre-existing resources unless ownership of those resources is certain.

---

# 9. Logging

## 9.1 Purpose

Console output serves the operator.

Logs serve diagnosis, audit, and evidence.

The two MAY overlap but are not interchangeable.

## 9.2 Canonical Levels

Supported logging levels MUST be taken from the current framework logging implementation and exposed consistently by framework tools.

Console and file logging are independent concerns and MAY use different active levels.

Documentation MUST NOT publish a hard-coded level inventory unless it is synchronized with the implementation. The semantics of a named level MUST remain stable across scripts.

## 9.3 Sensitive Data

Passwords, private keys, tokens, secrets, and confidential values MUST NOT be written to logs.

Commands containing sensitive arguments MUST be redacted or logged in a safe descriptive form.

## 9.4 Debug Logging

Debug logging SHOULD reveal:

- resolved paths;
- selected branches;
- detected configuration;
- commands about to run;
- return statuses;
- state decisions.

Debug logging MUST NOT materially alter behaviour.

---

# 10. State Management

## 10.1 Declared State

Persisted state MUST be deliberate.

Variables intended for state persistence SHOULD be declared through `SGND_STATE_VARIABLES` or the current canonical state mechanism. Standalone bootstrap/recovery tools that cannot depend on the framework MAY use a small explicit state file, provided its schema and precedence are deterministic.

A script MUST NOT persist every variable merely because persistence is available.

## 10.2 Persistence Policy

State persistence MUST follow the execution contract of the owning application or tool.

Framework-managed automatic state is appropriate for values explicitly declared as persistent and expected to survive between runs. Explicit save controls MAY be used where persistence itself is an operator decision.

Automatic state MUST NOT cause surprising behaviour on a subsequent run.

## 10.3 State Compatibility

Changes to stored state names, formats, or meanings MUST consider compatibility.

State migration SHOULD be explicit.

Invalid or obsolete state MUST fail safely and SHOULD produce actionable guidance.

---

# 11. User Interface

## 11.1 Visual Consistency

Framework UI primitives MUST use theme variables rather than hard-coded escape sequences.

A standalone bootstrap/recovery tool MAY carry a small design-time fallback palette based on the SolidGroundUX default theme when the framework is unavailable. When a healthy framework is available, it SHOULD prefer the normal framework UI primitives and active theme.

Canonical style globals include:

```bash
SGND_UI_BOLD
SGND_UI_FAINT
SGND_UI_ITALIC

SGND_TITLE_TEXTCLR
SGND_TITLE_BORDER
SGND_TITLE_SUBTEXTCLR
SGND_TITLE_RIGHTCLR

SGND_SECTION_TEXTCLR
SGND_SECTION_BORDER
SGND_SECTION_BORDERCLR
```

The former name `SGND_UI_MUTE` is deprecated in favour of `SGND_UI_FAINT`.

`$FAINT` is deprecated in favour of `$FX_FAINT` where the canonical effect constant is intended.

## 11.2 Width Governance

The preferred console width is controlled by:

```bash
SGND_CONSOLE_WIDTH
```

The upper render bound is controlled by:

```bash
SGND_MAX_RENDER_WIDTH
```

UI primitives MUST respect the effective terminal width and MUST avoid uncontrolled overflow.

Canonical width detection SHOULD be centralized in `sgnd_terminal_width`.

## 11.3 Colour

Colour supports hierarchy; it MUST NOT be the only carrier of meaning.

Interfaces MUST remain understandable in monochrome or when colour support is disabled.

## 11.4 Prompts

Prompts SHOULD:

- use a clear label;
- show a useful default;
- identify accepted input;
- validate before proceeding;
- preserve readline cursor behaviour when colour is used.

Prompt colourization MUST use readline-safe non-printing markers where required.

## 11.5 Yes/No Questions

Boolean questions MUST be explicit.

Preferred display:

```text
Use DHCP? [Yes]:
```

Internal values MAY remain `0` and `1`, but operator-facing output SHOULD use `Yes` and `No`.

## 11.6 Confirmations and Post-Action Pauses

Confirmation and post-action viewing are separate interactions and MUST use the dialog primitive intended for that purpose.

Before a material change, use an explicit decision/confirmation prompt that summarizes the proposed action and requires an operator decision.

`ask_dlg_autocontinue` is intended for interruptible countdowns and post-action viewing windows. It MUST NOT be used as a substitute for informed confirmation.

A confirmation SHOULD summarize the proposed action rather than merely asking “Continue?”

## 11.7 Menus

Menus MAY be large when the structure remains legible.

Quick keys MUST be unique within their active menu.

Navigation keys SHOULD be consistent, including support for left and right navigation where the host supports it.

Canonical direct controls are application-defined but MUST remain visible and unique within their active context.

The SolidGround Management Console currently provides direct controls for execution mode, access context, console logging, file logging, theme, lines per page, redraw, shell access, navigation, and exit.

The interface MUST make the meaning of each key visible.

---

# 12. Output Primitives

## 12.1 Labeled Values

Structured metadata SHOULD use `sgnd_print_labeledvalue`.

Canonical examples:

```bash
sgnd_print_labeledvalue --label "Version" \
    --value "$SGND_VERSION.$SGND_BUILD" \
    --labelwidth 20

sgnd_print_labeledvalue --label "Company" \
    --value "$SGND_COMPANY" \
    --labelwidth 20

sgnd_print_labeledvalue --label "Copyright" \
    --value "$SGND_COPYRIGHT" \
    --labelwidth 20

sgnd_print_labeledvalue --label "License" \
    --value "$SGND_LICENSE" \
    --labelwidth 20

sgnd_print_labeledvalue --label "License Accepted" \
    --value "$([[ ${SGND_LICENSE_ACCEPTED:-0} -eq 1 ]] && printf 'Yes' || printf 'No')" \
    --labelwidth 20
```

## 12.2 Progress

Progress reporting MUST be proportional to the work.

Canonical throttling guidance:

- more than 1000 items: update approximately every `total / 250`;
- more than 500 items: update approximately every `total / 100`;
- 100–500 items: update approximately every `total / 20`;
- fewer than 100 items: update approximately every `total / 5`;
- always make the first and last items visible where useful.

Progress MUST NOT flood the console.

## 12.3 Durations

Durations SHOULD be rendered as:

```text
HH:mm:ss
```

for consistent scanning and comparison.

---

# 13. Console and Module Architecture

## 13.1 Management Console Role

The console is the **SolidGround Management Console**.

It is a modular administration application built on the SolidGroundUX runtime and the public `sgnd-menu.sh` API. The menu framework is reusable infrastructure; the Management Console is one consumer of it.

## 13.2 Index and Lazy Page Loading

The Management Console MUST begin from a lightweight index that discovers available pages without sourcing every implementation module.

Page metadata required by the index SHOULD remain lightweight.

When a page is selected:

1. its implementation module is sourced if it has not already been loaded;
2. the module registers its detailed groups and items through the public menu API;
3. the selected page is rendered;
4. the loaded module remains resident for the lifetime of the console process.

Returning to the index MUST NOT require unloading the module.

This architecture exists to reduce initial load time without repeatedly paying the cost of loading functionality already used.

## 13.3 Module Discovery and Visibility

The canonical module directory is:

```text
/usr/local/libexec/solidgroundux/console-modules/
```

In Management Console development, the equivalent module path MUST derive from the Management Console product's contextual root. Framework libraries and other Framework-owned resources MUST be obtained through the canonical Framework resource resolver rather than by assuming the Framework is physically present in the Management Console workspace.

Page visibility MAY be persisted independently of module discovery. Root-only management controls MAY edit this state, but hidden modules MUST remain discoverable to the visibility manager so they can be re-enabled.

## 13.4 Module Contract

A console module MUST be source-only and MUST register itself through the public menu API expected by the host.

A module MUST NOT assume that another lazy-loaded page has already been opened.

Functionality genuinely shared by independent modules belongs in an appropriately scoped common library. Framework-generic functionality belongs in the Framework; console-specific shared functionality belongs in the Management Console product and MUST NOT create cross-module lazy-load dependencies.

Subject-specific implementation MAY remain in its owning module until reuse, size, or maintenance justifies extraction.

## 13.5 Console Settings

Frequently used runtime settings SHOULD be exposed through direct quick-access controls rather than a separate settings page when the direct interaction is clearer.

Persisted console state MAY still back those controls.

## 13.6 Child Shells

A Management Console option MAY open a child shell.

The interface MUST make clear that:

- the operator is leaving the menu temporarily;
- the shell inherits the current environment;
- exiting the shell returns to the Management Console.

---

# 14. System Configuration Workflows

## 14.1 Current Values as Defaults

Configuration workflows MUST display detected current values and SHOULD use them as defaults.

The operator SHOULD be able to accept the current value without retyping it.

## 14.2 Network Identity

The canonical network workflow asks explicitly:

```text
Use DHCP? Yes/No
```

When DHCP is enabled, static IPv4 fields SHOULD be omitted.

When DHCP is disabled, the workflow SHOULD request only relevant IPv4 values and validate address availability before applying where practical.

Before applying, the workflow MUST summarize the proposed configuration and request an explicit operator decision.

## 14.3 Host Identity

Setting host identity MUST be limited to identity-related changes.

It MUST NOT regenerate SSH host keys unless that action is explicitly part of the selected operation.

SSH host key generation belongs in a dedicated action.

## 14.4 SSH Host Keys

Canonical action:

```bash
ssh-keygen -A
systemctl restart ssh
```

The action MUST report failure if either required step fails.

## 14.5 Machine ID

Template preparation SHOULD truncate `/etc/machine-id`, remove the D-Bus machine ID where applicable, and ensure the canonical relationship to `/etc/machine-id`.

Clones SHOULD generate a new machine ID during boot or explicit initialization.

A management-console command to set the machine ID is unnecessary when the template lifecycle already guarantees regeneration.

## 14.6 Template Preparation

Template preparation is destructive to machine identity and runtime history.

It MUST require confirmation.

It SHOULD include:

- log cleanup;
- temporary-file cleanup;
- machine-ID reset;
- network reset to the template default;
- removal of SSH host keys where the deployment flow requires regeneration;
- explicit reporting of what the clone must do next.

First-boot services SHOULD NOT be retained when the SolidGround Management Console provides an explicit and reliable post-clone workflow.

---

# 15. Package Installation

## 15.1 Base Packages

The base package set MUST remain intentional and reviewed.

Canonical categories include:

- core shell and file utilities;
- networking and diagnostics;
- archive and transfer tools;
- editors and operator utilities;
- SSH;
- QEMU guest integration;
- certificate and package-management support.

Packages MUST NOT be added merely because they are convenient on one host.

Each package SHOULD have a defensible role in the baseline.

## 15.2 Package Commands

Package installation SHOULD be non-interactive only where defaults are safe.

Failures MUST propagate.

A package install routine MUST NOT report a complete baseline when one or more required packages failed to install.

## 15.3 Idempotence

Repeated package installation SHOULD be safe.

The script SHOULD distinguish between:

- already installed;
- newly installed;
- unavailable;
- failed.

---

# 16. Installer Behaviour

## 16.1 Canonical Release Manager

`release-manager.sh` is the canonical installation and release-lifecycle tool for SolidGroundUX packages.

Separate legacy installer, updater, and uninstaller commands MUST NOT be documented as current interfaces once their responsibilities have been absorbed by the Release Manager.

Prepared release packages are produced by `prepare-release.sh` and consumed by `release-manager.sh`.

The Release Manager MUST remain usable when SolidGroundUX is not yet installed or is damaged. Its release engine therefore MUST NOT depend on a working framework runtime.

## 16.2 Release Package Contract

Every distributable package MUST contain a `release-package.info` shipping label identifying at least:

```text
package format
project
product
version
build
release
```

A package MUST also contain the complete release archive, manifest, removed manifest, and their checksum sidecars. When multiple products are assembled into one bundle, path ownership collisions MUST be detected and reported rather than resolved by silent overwrite.

SolidGroundUX framework packages MAY additionally contain a ZIP-root `release-manager.sh` bootstrap copy. Generic project packages SHOULD rely on an already installed Release Manager.

The package identity file is transport metadata. The deployed project definitions file remains the authoritative runtime project identity.

## 16.3 Bootstrap and Canonical Manager

A ZIP-root Release Manager is a bootstrap runner, not the authoritative installed copy.

On first installation:

1. the bootstrap manager identifies and validates the adjacent package;
2. the target root is resolved or explicitly confirmed;
3. the package archive is installed;
4. the installed tar establishes the canonical manager under `var/lib/solidgroundux`;
5. the bootstrap copy MAY clean up its known temporary files.

The running bootstrap or development copy MUST NOT overwrite the canonical manager merely because its pathname differs.

## 16.4 Integrity

Releases MUST include checksum verification for the archive, manifest, and removed manifest.

Installation MUST stop when integrity or path-safety verification fails.

## 16.5 Existing Directories

Archive extraction MUST NOT overwrite ownership, mode, ACLs, or extended attributes of existing parent system directories unless the installer explicitly owns and manages those directories.

## 16.6 Operation Detection

The Release Manager SHOULD identify whether the selected action represents:

- first installation;
- repair or reinstall;
- update;
- downgrade or rollback;
- removal.

The operator SHOULD be informed when behavior differs by mode.

## 16.7 Project-Aware Filesystem State

Release state is filesystem-based and project-aware.

SolidGroundUX retains the canonical state locations:

```text
/var/lib/solidgroundux/releases/
/var/lib/solidgroundux/archive/
```

Additional projects use:

```text
/var/lib/solidgroundux/projects/<project>/releases/
/var/lib/solidgroundux/projects/<project>/archive/
```

The release lifecycle SHOULD remain inspectable with ordinary filesystem tools rather than depending on an opaque current-version database.

Build output produced by `prepare-release.sh` belongs to the workspace release-output directory. It MUST NOT be copied into the target-root managed release-state directories merely as a side effect of preparing a release. A package enters managed `releases/` state when the Release Manager acquires or admits it.

## 16.8 Interactive and Non-Interactive Operation

Interactive Release Manager operation SHOULD present stateful parameter values as questions and release actions through a menu.

Non-interactive action arguments such as check, download, update, install, rollback, and remove MUST dispatch the same underlying action functions used by the interactive menu.

Explicit command-line values take precedence over stored parameter state. `--auto` MAY suppress questions and confirmations where the selected action already expresses informed intent.

## 16.9 Standalone and Framework UI

The Release Manager MUST always have a minimal standalone UI and fallback theme available.

When a healthy SolidGroundUX framework exists at the selected target root, the manager MAY use the normal SolidGroundUX UI primitives and active theme. Failure to load the framework UI MUST fall back safely to the standalone implementation and MUST NOT prevent release recovery operations.


# 17. Security

## 17.1 Least Surprise

Security-sensitive defaults MUST be conservative and visible.

A framework convenience MUST NOT silently weaken host security.

## 17.2 Privilege

Operations SHOULD use the least privilege practical.

Root execution MUST be required only for actions that need it.

## 17.3 Credentials

Credentials MUST be requested through appropriate input primitives and MUST NOT be echoed or logged.

## 17.4 Firewall and Services

Enabling or disabling a network service MUST state:

- which service changes;
- whether it starts immediately;
- whether it starts at boot;
- whether firewall changes are included.

These are separate states and MUST NOT be conflated.

## 17.5 Remote Access

SSH enablement and SSH key generation are separate operations.

The SolidGround Management Console SHOULD expose them as separate actions.

---

# 18. Samba Active Directory Provisioning

## 18.1 Required Inputs

Before Kerberos or Samba AD configuration, the workflow MUST request:

- Kerberos realm;
- Kerberos server;
- administrative server.

The Kerberos and administrative server SHOULD default to:

```text
<hostname>.<realm>
```

with realm normalization applied consistently.

## 18.2 Realm

Realm handling MUST make case behaviour explicit.

Where the consuming component expects an uppercase Kerberos realm, the normalized value SHOULD be shown before application.

## 18.3 Confirmation

Before provisioning, an explicit confirmation dialog MUST present the resolved values and explain that domain provisioning is a material system change.

## 18.4 Administrator Password

The provisioning flow MUST explicitly collect or establish the domain Administrator password.

A provisioning workflow is incomplete if it omits this step.

## 18.5 DNS

The DNS forwarder MUST be configurable.

The resulting DNS design MUST distinguish:

- the AD DNS server used by clients;
- the upstream forwarder used by the AD DNS server.

## 18.6 Time

The workflow SHOULD verify time synchronization because Kerberos depends on acceptable clock alignment.

---

# 19. Documentation

## 19.1 Documentation Is Part of the Product

A feature is incomplete until its public behaviour is documented.

Generated documentation does not replace accurate source contracts.

## 19.2 Canonical Sources

Documentation SHOULD be generated from canonical headers and metadata where possible.

Generated output MUST not invent details absent from source contracts.

## 19.3 Documentation Dialect and Rendering

The documentation source dialect SHOULD remain readable as ordinary source comments while allowing explicit presentation constructs where whitespace alone is insufficient.

Canonical constructs include:

- style hints for presentation without changing the underlying documentation item;
- image groups for publishing source-associated images;
- `. Table` / `. EndTable` blocks, with `::` separating semantic table cells;
- `<>` alignment columns for visually aligned ordinary documentation in proportional fonts without table semantics;
- `@` as the literal/parser modifier: once recognized, subsequent content on that documentation line is intended to remain literal rather than being structurally reinterpreted.

The normalized processor/renderer contract MUST preserve the information required by these constructs without coupling source-language parsing to HTML rendering.

Consecutive non-empty ordinary documentation lines SHOULD be treated as coherent paragraphs in generated HTML. Formatting rules MUST preserve readable separation without turning every source line into a separate paragraph.

## 19.4 Documentation Collections

Documentation generation MAY operate on complete collections, selected content, changed content, or previously normalized content that is rendered again.

Multi-product documentation collections MUST remain deterministic. Product-specific exclusions SHOULD be expressed through `<product>.docignore` configuration resolved through the normal framework system/user configuration locations. Duplicate collected assets MUST NOT be silently overwritten; deterministic ownership and a visible warning are required.

Framework defaults MAY seed an output location, but the renderer MUST use the final resolved output directory selected for the generation run. Published collections MAY use a collection-specific subdirectory beneath a shared documentation root.

## 19.5 Appendices

Appendices MAY contain:

- reference material;
- compatibility notes;
- generated inventories;
- historical rationale;
- examples;
- migration guidance.

Appendix numbering MAY begin with Appendix 0 where the appendix establishes principles that precede the technical body.

## 19.6 Examples

Examples MUST be concrete, executable where practical, and consistent with current names and paths.

An example using a non-existent command is a documentation defect.

---

# 20. Versioning and Release Metadata

## 20.1 Version

Canonical framework display:

```text
SGND_VERSION.SGND_BUILD
```

Project-specific definitions MAY provide equivalent project-scoped Version and Build globals.

When a release contains multiple products, version/build update policy MUST be evaluated per product. A combined bundle MUST inherit the release identity of its primary product rather than maintaining an independent bundle version/build policy.

Build identifiers MAY embed date or time information according to the release process.

## 20.2 Script Headers

Release tooling SHOULD synchronize version metadata in changed script headers and MUST update the authoritative project definitions file for the release identity being produced.

An option MAY restrict per-script header updates to changed files.

Unchanged files SHOULD NOT receive meaningless version churn unless the release policy explicitly requires a global version update.

## 20.3 Canonical Metadata

```bash
SGND_COMPANY="Testadura Consultancy"
SGND_COPYRIGHT="© 2025 - 2026 Testadura Consultancy"
SGND_LICENSE="Testadura Non-Commercial License (TD-NC) v1.1."
SGND_RELEASE_URL="https://github.com/Testadura-Mark/SolidGroundUX/releases"
SGND_ONLINE_DOC="https://testadura-consultancy.github.io/SolidGroundUX/"
```

Public branding MAY use `Testadura` without `Consultancy`.

## 20.4 Release Notes

Release notes SHOULD describe operator-visible change.

Internal refactoring MAY be summarized, but release notes SHOULD prioritize:

- changed behaviour;
- compatibility impact;
- migration steps;
- fixed defects;
- known limitations.

---

# 21. Compatibility, Deprecation, and Removal

## 21.1 Deprecation

A deprecated feature SHOULD:

- remain functional for a defined transition period where practical;
- emit a clear warning when used;
- identify the replacement;
- be listed in release notes.

## 21.2 Renaming

Canonical renames include:

```text
SGND_UI_MUTE  → SGND_UI_FAINT
FAINT         → FX_FAINT
td_*          → sgnd_*
```

Compatibility aliases MAY be retained temporarily.

New code MUST use the canonical name.

## 21.3 Removal

Removal requires evidence that:

- the replacement is available;
- documentation has been updated;
- migration impact is understood;
- retained compatibility no longer justifies its cost.

---

# 22. Testing and Verification

## 22.1 Behavioural Verification

Testing MUST verify observable behaviour, not merely syntax.

Relevant checks include:

- successful path;
- failure path;
- invalid input;
- repeated execution;
- dry run;
- non-interactive mode;
- narrow terminal width;
- monochrome output;
- missing optional dependency;
- interrupted operation.

## 22.2 Clean-System Testing

Installers and system configuration workflows SHOULD be tested on a clean supported operating system image.

A developer workstation is not a substitute for clean-system verification.

## 22.3 Ownership and Permissions

Release tests MUST verify ownership and permissions after installation.

This includes existing parent directories as well as installed files.

## 22.4 Visual Verification

UI changes SHOULD be reviewed in multiple themes and at constrained widths.

A style is not complete merely because the default theme renders correctly.

---

# 23. Change Governance

## 23.1 Canon Changes

A change to canonical behaviour SHOULD include:

- the problem being solved;
- the proposed rule;
- compatibility impact;
- implementation impact;
- documentation impact;
- migration path where required.

## 23.2 Exceptions

An exception MUST be:

- deliberate;
- local;
- documented;
- justified by a real constraint.

An exception MUST NOT silently become a competing convention.

## 23.3 Evidence

When established behaviour is changed, the reason SHOULD be preserved in the commit, issue, release note, or this document.

The canon SHOULD record conclusions, not every intermediate debate.

---

# 24. Review Checklist

A script or module is canonically aligned when the reviewer can answer **yes** to the following.

## 24.1 Structure

- Does the file follow the canonical section order?
- Is framework initialization performed in the correct order?
- Are framework and application responsibilities separated?
- Are paths derived rather than scattered as hard-coded values?

## 24.2 Naming

- Are public functions prefixed with `sgnd_`?
- Are framework-internal/protected functions named `_sgnd_*` where appropriate?
- Are private/local functions prefixed with a single underscore?
- Are double underscores absent?
- Are obsolete `td_` prefixes removed?
- Are global and local variables named consistently?

## 24.3 Contracts

- Do public and non-trivial functions have accurate contracts?
- Do simple private helpers avoid unnecessary boilerplate?
- Does every documented function include at least one concrete `. Usage` example?
- Are parameters, return values, side effects, and globals documented where they materially affect the contract?

## 24.4 Behaviour

- Does the operation do exactly what its name promises?
- Are destructive actions confirmed?
- Are current values shown as defaults?
- Are success and failure reported truthfully?
- Are failures propagated?

## 24.5 Interface

- Does the UI use theme variables?
- Does it respect terminal width?
- Is colour optional rather than essential?
- Are boolean values presented as `Yes` and `No`?
- Are prompts clear and validated?

## 24.6 Safety

- Are sensitive values protected?
- Are permissions and ownership preserved?
- Is dry-run behaviour genuine?
- Is repeated execution safe?
- Are system-wide side effects explicit?

## 24.7 Documentation and Release

- Is documentation current?
- Are examples real?
- Is version metadata correct?
- Are operator-visible changes captured in release notes?
- Has the implementation been tested on a clean supported system where relevant?

---

# 25. The Canon in One Page

SolidGroundUX code SHALL:

- be explicit;
- be readable;
- use canonical names;
- use framework primitives;
- validate input;
- preserve accurate state;
- propagate failure;
- report success only after success;
- protect ownership and permissions;
- respect the operator’s control;
- use consistent UI and logging;
- document public behaviour;
- provide concrete examples;
- remain safe when repeated;
- and avoid side effects outside its declared purpose.

SolidGroundUX code SHALL NOT:

- invent commands or primitives;
- hide material changes;
- silently ignore errors;
- claim success prematurely;
- overwrite system metadata accidentally;
- log secrets;
- couple unrelated operations;
- force unnecessary interaction;
- or make the operator fight the framework.

---

# Final Declaration

SolidGroundUX exists to make scripts feel like parts of one system rather than accidents sharing a directory.

The framework is successful when the operator notices the task, not the framework.

The canon is successful when a new module feels familiar before it has ever been used.

The implementation is successful when its behaviour can be trusted without first reading every line of its source.

And when the task is complete, SolidGroundUX should do what it was designed to do from the beginning:

> **Get out of my way.**
