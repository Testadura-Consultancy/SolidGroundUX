#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Setup
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
#   Checksum    : c9746e7369195671242749f73f7dcb35c0fab93fa9660a2693d42028161cf787
#   Source      : sgnd-setup.sh
#   Wrapper     : sgnd-setup
#   Type        : script
#   Group       : Deployment
#   Purpose     : Standalone SolidGroundUX product setup, installation, update, rollback, and removal.
#
# Description:
#   Provides self-sufficient first-install and lifecycle setup for SolidGroundUX products.
#
#   The script:
#     - Keeps SolidGroundUX release state in the legacy releases/archive locations
#     - Keeps other project release state under /var/lib/solidgroundux/projects/<project>/
#     - Reads release-package.info from incoming ZIPs to select the owning project
#     - Installs a first release by verifying and extracting its complete tar archive
#     - Updates an existing installation and applies the incoming .removed manifest
#     - Rolls back by making the installed filesystem match a selected archived release
#     - Removes the selected project while preserving release packages for later reinstall
#     - Queries GitHub for the latest published release and downloads it only when needed
#     - Bootstraps a clean machine from sgnd-setup.sh plus adjacent product release ZIPs
#     - Installs a canonical setup copy under /var/lib/solidgroundux for future recovery
#     - Uses a small self-contained UI before SolidGroundUX is available
#     - Reuses the normal SolidGroundUX UI primitives/theme when a healthy framework is available
#     - Persists setup parameter values as standalone state
#     - Offers Setup, Management Console, or shell exit after first install
#
# Design principles:
#   - Standalone operation even when SolidGroundUX is absent or damaged
#   - Product ZIPs are the release unit; acquisition varies, installation does not
#   - Complete release archives; no incremental binary patching
#   - Conservative removal: files/symlinks are removed, directories only when empty
#   - Product ZIP acquisition is transactional; successful installs archive the original ZIP
#   - Bootstrap cleanup is limited to known setup/package files under /tmp
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================

set -uo pipefail

# --- Defaults -----------------------------------------------------------------------
    SGND_RELEASE_PROJECT="solidgroundux"
    SGND_RELEASE_PRODUCT="SolidGroundUX"
    SGND_RELEASE_GITHUB_REPO="Testadura-Mark/SolidGroundUX"
    SGND_MANAGEMENT_MODULES_GITHUB_REPO="Testadura-Consultancy/solidgrond-management-modules"
    SGND_RELEASE_LINE="2.1"
    SGND_RELEASE_BUILD=""
    SGND_RELEASE_API_URL="https://api.github.com/repos/Testadura-Mark/SolidGroundUX/releases/latest"
    SGND_RELEASE_CONFIG_FILE=""
    SGND_RELEASE_VARIANT="individual"

    FLAG_AUTO=0
    FLAG_DRYRUN=0
    FLAG_VERBOSE=0

    ACTION=""
    VAL_RELEASE=""
    VAL_SOURCE=""
    VAL_TARGET_ROOT="/"
    VAL_STATE_ROOT=""
    VAL_RELEASES_DIR=""
    VAL_ARCHIVE_ROOT=""
    VAL_GITHUB_REPO=""
    VAL_GITHUB_URL=""
    VAL_PROJECT=""
    VAL_VARIANT=""

    PROJECT_STATE_ROOT=""
    PROJECT_INFO_FILE=""

    FLAG_TARGET_ROOT_OVERRIDE=0
    FLAG_STATE_ROOT_OVERRIDE=0
    FLAG_RELEASES_DIR_OVERRIDE=0
    FLAG_ARCHIVE_ROOT_OVERRIDE=0
    FLAG_PROJECT_OVERRIDE=0
    FLAG_VARIANT_OVERRIDE=0
    FLAG_SOURCE_OVERRIDE=0
    FLAG_RELEASE_OVERRIDE=0
    FLAG_REPO_OVERRIDE=0

    RELEASE_UI_MODE="standalone"
    RELEASE_STATE_FILE=""

    SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_FILE")" && pwd)"
    SCRIPT_BASE="$(basename -- "$SCRIPT_FILE")"
    SCRIPT_NAME="${SCRIPT_BASE%.sh}"
    CANONICAL_MANAGER_PATH=""

    BOOTSTRAP_RELEASE_BASE=""
    BOOTSTRAP_SOURCE_DIR=""
    BOOTSTRAP_POST_INSTALL_ACTION="setup"

# --- Standalone UI ------------------------------------------------------------------
    # Default-theme-compatible standalone palette.
    # Kept local so the setup tool remains self-sufficient.
    # Bootstrap palette: design-time snapshot of the SolidGroundUX default theme.
    # It deliberately mirrors the normal default palette/style closely, but has no
    # runtime dependency on SolidGroundUX.
    _RL_RESET=$'\e[0m'
    _RL_BOLD=$'\e[1m'
    _RL_FAINT=$'\e[2m'
    _RL_ITALIC=$'\e[3m'

    _RL_SILVER=$'\e[0;38;5;250m'
    _RL_YELLOW=$'\e[38;2;215;190;0m'
    _RL_BRIGHT_CYAN=$'\e[38;2;70;255;255m'
    _RL_BRIGHT_GREEN=$'\e[38;2;70;255;110m'
    _RL_BRIGHT_ORANGE=$'\e[38;2;255;190;45m'
    _RL_BRIGHT_RED=$'\e[38;2;255;70;70m'
    _RL_DARK_WHITE=$'\e[38;2;155;155;155m'
    _RL_WHITE=$'\e[38;2;192;192;192m'
    _RL_BRIGHT_WHITE=$'\e[38;2;255;255;255m'
    _RL_BRIGHT_MAGENTA=$'\e[38;2;255;0;255m'

    _RL_UI_LABEL="$_RL_SILVER"
    _RL_UI_VALUE="$_RL_YELLOW"
    _RL_UI_TEXT="$_RL_SILVER"
    _RL_UI_INPUT="$_RL_YELLOW"
    _RL_UI_PROMPT="$_RL_BRIGHT_CYAN"

    _RL_MSG_INFO="$_RL_SILVER"
    _RL_MSG_START="$_RL_BRIGHT_GREEN"
    _RL_MSG_OK="$_RL_BRIGHT_GREEN"
    _RL_MSG_WARN="$_RL_BRIGHT_ORANGE"
    _RL_MSG_FAIL="$_RL_BRIGHT_RED"
    _RL_MSG_CANCEL="$_RL_YELLOW"
    _RL_MSG_END="$_RL_BRIGHT_GREEN"

    if [[ ! -t 1 || "${TERM:-}" == "dumb" ]]; then
        _RL_RESET=""
        _RL_BOLD=""
        _RL_FAINT=""
        _RL_ITALIC=""
        _RL_SILVER=""
        _RL_YELLOW=""
        _RL_BRIGHT_CYAN=""
        _RL_BRIGHT_GREEN=""
        _RL_BRIGHT_ORANGE=""
        _RL_BRIGHT_RED=""
        _RL_BRIGHT_MAGENTA=""
        _RL_UI_LABEL=""
        _RL_UI_VALUE=""
        _RL_UI_TEXT=""
        _RL_UI_INPUT=""
        _RL_UI_PROMPT=""
        _RL_MSG_INFO=""
        _RL_MSG_START=""
        _RL_MSG_OK=""
        _RL_MSG_WARN=""
        _RL_MSG_FAIL=""
        _RL_MSG_CANCEL=""
        _RL_MSG_END=""
    fi

    # fn: _release_framework_root_for_target - Resolve the framework root for the selected target
        # . Usage
        #   _release_framework_root_for_target
    _release_framework_root_for_target() {
        if [[ "$VAL_TARGET_ROOT" == "/" ]]; then
            printf '%s\n' "/"
        else
            printf '%s\n' "${VAL_TARGET_ROOT%/}"
        fi
    }

    # fn: _release_try_framework_ui - Prefer the installed SolidGroundUX UI when healthy
        # . Purpose
        #   Opportunistically load the normal framework UI after the target root is known.
        #
        # . Behavior
        #   - Never required for sgnd-setup operation.
        #   - Falls back silently to the bootstrap UI if the framework is absent, damaged,
        #     or cannot complete bootstrap.
        #   - Keeps setup business logic behind _release_* UI adapters.
        # . Usage
        #   _release_try_framework_ui
    _release_try_framework_ui() {
        local root=""
        local exe_common=""
        local rc=0

        RELEASE_UI_MODE="standalone"
        root="$(_release_framework_root_for_target)"
        if [[ "$root" == "/" ]]; then
            exe_common="/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        else
            exe_common="${root%/}/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        fi

        [[ -r "$exe_common" ]] || return 0

        # Supply the minimal executable metadata contract expected by bootstrap.
        SGND_FRAMEWORK_ROOT="$root"
        SGND_SCRIPT_FILE="$SCRIPT_FILE"
        SGND_SCRIPT_DIR="$SCRIPT_DIR"
        SGND_SCRIPT_BASE="$SCRIPT_BASE"
        SGND_SCRIPT_NAME="$SCRIPT_NAME"
        SGND_SCRIPT_TITLE="SolidGroundUX Setup"
        SGND_USING=()
        SGND_ARGS_SPEC=()
        SGND_SCRIPT_GLOBALS=()
        SGND_STATE_VARIABLES=()
        SGND_ON_EXIT_HANDLERS=()
        SGND_STATE_SAVE=0

        # A broken framework must never make its rescue/update tool unusable.
        set +u
        # shellcheck source=/dev/null
        source "$exe_common" >/dev/null 2>&1 || rc=$?
        if (( rc == 0 )) && declare -F _load_bootstrapper >/dev/null 2>&1; then
            _load_bootstrapper >/dev/null 2>&1 || rc=$?
        fi
        if (( rc == 0 )) && declare -F sgnd_bootstrap >/dev/null 2>&1; then
            sgnd_bootstrap >/dev/null 2>&1 || rc=$?
        fi
        set -u

        if (( rc == 0 )) \
            && declare -F sgnd_print >/dev/null 2>&1 \
            && declare -F sgnd_print_labeledvalue >/dev/null 2>&1 \
            && declare -F sgnd_print_sectionheader >/dev/null 2>&1 \
            && declare -F ask >/dev/null 2>&1; then
            RELEASE_UI_MODE="framework"
        fi

        return 0
    }

    # fn: _release_print - Print a line through the active UI implementation
        # . Usage
        #   _release_print "<args...>"
    _release_print() {
        if [[ "$RELEASE_UI_MODE" == "framework" ]] && declare -F sgnd_print >/dev/null 2>&1; then
            sgnd_print "$@"
        else
            printf '%s\n' "$*"
        fi
    }

    # fn: _release_section_header - Render a section header through the active UI
        # . Usage
        #   _release_section_header "<title>"
    _release_section_header() {
        local title="${1:-}"
        if [[ "$RELEASE_UI_MODE" == "framework" ]] && declare -F sgnd_print_sectionheader >/dev/null 2>&1; then
            sgnd_print_sectionheader "$title" --padend 0
            return 0
        fi

        printf '\n'
        [[ -n "$title" ]] && printf '%s%s%s%s\n' "$_RL_BRIGHT_WHITE" "$_RL_BOLD" "$title" "$_RL_RESET"
        _release_line "─"
    }

    # fn: _release_ask - Ask for a scalar value using framework ask() or the fallback UI
        # Arguments:
        #   $1 label, $2 variable name, $3 default
        # . Usage
        #   _release_ask "<label>" "<var_name>" "<default>"
    _release_ask() {
        local label="${1:-Value}"
        local var_name="${2:?missing variable name}"
        local default="${3:-}"
        local reply=""

        if (( FLAG_AUTO )); then
            [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$default"
            return 0
        fi

        if [[ "$RELEASE_UI_MODE" == "framework" ]] && declare -F ask >/dev/null 2>&1; then
            ask --label "$label" --var "$var_name" --default "$default" --colorize both
            return $?
        fi

        printf '%s%s%s [%s%s%s]: ' \
            "$_RL_UI_PROMPT" "$label" "$_RL_RESET" \
            "$_RL_UI_VALUE" "$default" "$_RL_RESET" > /dev/tty
        read -r reply < /dev/tty
        [[ -n "$reply" ]] || reply="$default"
        printf -v "$var_name" '%s' "$reply"
    }

    # fn: _release_ask_yesno - Ask a yes/no question with a default
        # . Usage
        #   _release_ask_yesno "<label>" "<default>"
    _release_ask_yesno() {
        local label="${1:-Continue?}"
        local default="${2:-Y}"
        local reply=""

        (( FLAG_AUTO )) && return 0

        if [[ "$RELEASE_UI_MODE" == "framework" ]] && declare -F ask >/dev/null 2>&1; then
            ask --label "$label (Y/N)" --var reply --default "$default" --choices "Y,Yes,N,No"
        else
            printf '%s%s%s [%s]: ' "$_RL_UI_PROMPT" "$label" "$_RL_RESET" "$default" > /dev/tty
            read -r reply < /dev/tty
            [[ -n "$reply" ]] || reply="$default"
        fi

        case "${reply^^}" in
            Y|YES) return 0 ;;
            *) return 1 ;;
        esac
    }

    # fn: _release_terminal_width - Return the usable terminal width
        # Returns:
        #   Prints a terminal width between 40 and 140 columns.
        # Usage:
        #   width="$(_release_terminal_width)"
    _release_terminal_width() {
        local width=80

        if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
            width="$(tput cols 2>/dev/null || printf '80')"
        fi

        [[ "$width" =~ ^[0-9]+$ ]] || width=80
        (( width < 40 )) && width=40
        (( width > 140 )) && width=140
        printf '%s\n' "$width"
    }

    # fn: _release_clear - Clear the active terminal reliably
        # Returns:
        #   0 always.
        # Usage:
        #   _release_clear
    _release_clear() {
        [[ -t 1 ]] || return 0
        printf '\033[2J\033[H'
    }

    # fn: _release_line - Print a repeated border character
        # Returns:
        #   0 always.
        # Usage:
        #   _release_line "═"
    _release_line() {
        local char="${1:-─}"
        local width=80
        local line=""

        width="$(_release_terminal_width)"
        printf -v line '%*s' "$width" ''
        line="${line// /$char}"

        printf '%s%s%s\n' "$_RL_BRIGHT_CYAN" "$line" "$_RL_RESET"
    }

    # fn: _release_metadata_field - Read a field from this script's Metadata header
        # . Purpose
        #   Read one value from the canonical script Metadata block without depending on
        #   SolidGroundUX framework libraries.
        # . Arguments
        #   $1  Metadata field name, for example Version or Build.
        # . Returns
        #   0 and the trimmed field value when found; 1 otherwise.
        # . Usage
        #   version="$(_release_metadata_field "Version")"
    _release_metadata_field() {
        local field="${1:-}"
        local value=""

        [[ -n "$field" ]] || return 1

        value="$(
            sed -n -E \
                "s/^#[[:space:]]*${field}[[:space:]]*:[[:space:]]*(.*)[[:space:]]*$/\1/p" \
                "$SCRIPT_FILE" \
                | head -n 1
        )"

        [[ -n "$value" ]] || return 1
        printf '%s\n' "$value"
    }

    # fn: _release_title - Render the standalone setup title
        # . Purpose
        #   Display the sgnd-setup identity and current hostname without using framework UI libraries.
        # . Returns
        #   0 always.
        # . Usage
        #   _release_title
    _release_title() {
        local width=80
        local manager_version=""
        local manager_build=""
        local title="SolidGroundUX Setup"
        local desc="Standalone package installation, update, rollback and removal"
        local host=""
        local pad=4
        local right_pad=4
        local gap=2
        local available=0

        manager_version="$(_release_metadata_field "Version" 2>/dev/null || true)"
        manager_build="$(_release_metadata_field "Build" 2>/dev/null || true)"

        if [[ -n "$manager_version" && -n "$manager_build" ]]; then
            title+=" (v. ${manager_version}.${manager_build})"
        elif [[ -n "$manager_version" ]]; then
            title+=" (v. ${manager_version})"
        fi

        width="$(_release_terminal_width)"
        host="$(hostname -f 2>/dev/null || hostname 2>/dev/null || printf 'unknown')"
        
        printf '\n'
        _release_line "═"
        
        available=$(( width - pad - right_pad - ${#title} - gap ))
        if (( available > ${#host} )); then
            printf '%*s%s%s%s%s%*s%s%s%s%s\n' \
                "$pad" '' "$_RL_BRIGHT_WHITE" "$_RL_BOLD" "$title" "$_RL_RESET" \
                "$(( available - ${#host} ))" '' \
                "$_RL_UI_VALUE" "$_RL_ITALIC" "$host" "$_RL_RESET"
        else
            printf '%*s%s%s%s%s\n' "$pad" '' "$_RL_BRIGHT_WHITE" "$_RL_BOLD" "$title" "$_RL_RESET"
        fi

        printf '%*s%s%s%s%s\n' "$pad" '' "$_RL_UI_TEXT" "$_RL_ITALIC" "$desc" "$_RL_RESET"
        _release_line "═"
    }

    # fn: _release_labeled_value - Print one aligned label/value pair
        # Returns:
        #   0 always.
        # Usage:
        #   _release_labeled_value "Installed release" "$current"
    _release_labeled_value() {
        local label="${1:-}"
        local value="${2:-}"
        local width="${3:-24}"

        if [[ "$RELEASE_UI_MODE" == "framework" ]] && declare -F sgnd_print_labeledvalue >/dev/null 2>&1; then
            sgnd_print_labeledvalue --label "$label" --value "$value" --labelwidth "$width"
            return 0
        fi

        printf '    %s%-*s%s : %s%s%s\n' \
            "$_RL_UI_PROMPT" "$width" "$label" "$_RL_RESET" \
            "$_RL_UI_VALUE" "$value" "$_RL_RESET"
    }

    # fn: _release_info - Write verbose informational output
        # . Purpose
        #   Write verbose informational output.
        # . Returns
        #   0 always.
        # . Usage
        #   _release_info "message"
    _release_info() {
        (( FLAG_VERBOSE )) || return 0
        printf '%sINFO%s  %s\n' "$_RL_MSG_INFO" "$_RL_RESET" "$*" >&2
    }

    # fn: _release_ok - Write a successful-operation message
        # . Purpose
        #   Write a successful-operation message.
        # . Returns
        #   0 always.
        # . Usage
        #   _release_ok "message"
    _release_ok() {
        printf '%sOK%s    %s\n' "$_RL_MSG_OK" "$_RL_RESET" "$*" >&2
    }

    # fn: _release_warn - Write a warning message
        # . Purpose
        #   Write a warning message.
        # . Returns
        #   0 always.
        # . Usage
        #   _release_warn "message"
    _release_warn() {
        printf '%sWARN%s  %s\n' "$_RL_MSG_WARN" "$_RL_RESET" "$*" >&2
    }

    # fn: _release_fail - Write a failure message
        # . Purpose
        #   Write a failure message.
        # . Returns
        #   0 always.
        # . Usage
        #   _release_fail "message"
    _release_fail() {
        printf '%sFAIL%s  %s\n' "$_RL_MSG_FAIL" "$_RL_RESET" "$*" >&2
    }

    # fn: _release_run - Execute a command or report it in dry-run mode
        # . Purpose
        #   Execute a command or report it in dry-run mode.
        # . Returns
        #   The executed command status, or 0 in dry-run mode.
        # . Usage
        #   _release_run mkdir -p /tmp/example
    _release_run() {
        if (( FLAG_DRYRUN )); then
            printf '[DRYRUN]'
            printf ' %q' "$@"
            printf '\n'
            return 0
        fi
        "$@"
    }

# --- Arguments and paths ------------------------------------------------------------
    # fn: _ensure_root - Re-execute sgnd-setup with elevated privileges when required
    _ensure_root() {
        local script_file=""

        (( EUID == 0 )) && return 0

        script_file="$(readlink -f "${BASH_SOURCE[0]}")" || {
            _release_fail "Cannot resolve sgnd-setup path."
            return 1
        }

        command -v sudo >/dev/null 2>&1 || {
            _release_fail "Setup requires root privileges and sudo is not available."
            return 1
        }

        if (( FLAG_AUTO )); then
            _release_fail "Automatic mode requires Setup to be started with root privileges."
            return 1
        fi

        _release_ask_yesno \
            "Setup requires elevated privileges. Restart with sudo?" \
            "Y" || {
                _release_warn "Setup cancelled."
                return 1
            }

        exec sudo -- "$script_file" "$@"
    }
    # fn: print_usage - Display standalone setup command-line help
        # . Purpose
        #   Display standalone setup command-line help.
        # . Returns
        #   0 always.
        # . Usage
        #   print_usage
    print_usage() {
        printf '%s\n' \
            'Usage:' \
            "  $SCRIPT_NAME [action] [options]" \
            '' \
            'Actions:' \
            '  --check                Check the configured GitHub Release for the latest build' \
            '  --download             Download the latest build when not already local/installed' \
            '  --update               Install latest GitHub product package (selected --project in --auto mode)' \
            '  --install              Install newest local product package (selected --project in --auto mode)' \
            '  --rollback             Install the previous archived release, or --release NAME' \
            '  --remove               Remove the active selected project installation' \
            '' \
            'Options:' \
            '  --release NAME         Operate on a specific release base or version' \
            '  --auto                 Do not ask for confirmations or selections' \
            '  --project SLUG         Select a locally known project (default: solidgroundux)' \
            '  --repo OWNER/REPO      Override configured GitHub repository' \
            '  --variant TYPE         Legacy archive compatibility only; new releases use product ZIPs' \
            '  --source URL|FILE      Transient product ZIP source for install/update (not persisted)' \
            '  --target-root PATH     Installation root (default: /)' \
            '  --state-root PATH      Setup state root' \
            '  --releases-dir PATH    Pending/downloaded releases directory' \
            '  --archive-root PATH    Installed release history directory' \
            '  --dryrun               Show filesystem actions without changing anything' \
            '  --verbose              Show informational diagnostics' \
            '  --help                 Show this help' \
            '' \
            'Persistent config:' \
            '  /var/lib/solidgroundux/release-manager.cfg' \
            '                        Release source and release-line settings' \
            '' \
            'Filesystem state:' \
            '  releases/              Pending product ZIP packages' \
            '  releases/archive/      Successfully installed original product ZIPs' \
            '  archive/ and projects/ Internal extracted release history used for rollback/removal'
    }

    # fn: _set_action - Set and validate the requested setup action
        # . Purpose
        #   Set and validate the requested setup action.
        # . Returns
        #   0 on success; 1 when conflicting actions are supplied.
        # . Usage
        #   _set_action update
    _set_action() {
        local requested="${1:?missing action}"
        if [[ -n "$ACTION" && "$ACTION" != "$requested" ]]; then
            _release_fail "Choose only one action: $ACTION or $requested"
            return 1
        fi
        ACTION="$requested"
    }

    # fn: parse_args - Parse sgnd-setup command-line arguments
        # . Purpose
        #   Parse sgnd-setup command-line arguments.
        # . Returns
        #   0 on success; non-zero on invalid arguments.
        # . Usage
        #   parse_args "$@"
    parse_args() {
        while (( $# > 0 )); do
            case "$1" in
                --check) _set_action check || return 1 ;;
                --download) _set_action download || return 1 ;;
                --update) _set_action update || return 1 ;;
                --install) _set_action install || return 1 ;;
                --rollback) _set_action rollback || return 1 ;;
                --remove) _set_action remove || return 1 ;;
                --release)
                    shift
                    VAL_RELEASE="${1:-}"
                    [[ -n "$VAL_RELEASE" ]] || { _release_fail "--release requires a value"; return 1; }
                    FLAG_RELEASE_OVERRIDE=1
                    ;;
                --auto) FLAG_AUTO=1 ;;
                --project)
                    shift
                    VAL_PROJECT="${1:-}"
                    [[ -n "$VAL_PROJECT" ]] || { _release_fail "--project requires a value"; return 1; }
                    FLAG_PROJECT_OVERRIDE=1
                    ;;
                --variant)
                    shift
                    VAL_VARIANT="${1:-}"
                    [[ "$VAL_VARIANT" == "bundle" || "$VAL_VARIANT" == "individual" ]] || { _release_fail "--variant must be bundle or individual"; return 1; }
                    FLAG_VARIANT_OVERRIDE=1
                    ;;
                --repo)
                    shift
                    VAL_GITHUB_REPO="${1:-}"
                    [[ -n "$VAL_GITHUB_REPO" ]] || { _release_fail "--repo requires a value"; return 1; }
                    FLAG_REPO_OVERRIDE=1
                    ;;
                --source)
                    shift
                    VAL_SOURCE="${1:-}"
                    [[ -n "$VAL_SOURCE" ]] || { _release_fail "--source requires a value"; return 1; }
                    FLAG_SOURCE_OVERRIDE=1
                    ;;
                --target-root)
                    shift
                    VAL_TARGET_ROOT="${1:-}"
                    [[ -n "$VAL_TARGET_ROOT" ]] || { _release_fail "--target-root requires a value"; return 1; }
                    FLAG_TARGET_ROOT_OVERRIDE=1
                    ;;
                --state-root)
                    shift
                    VAL_STATE_ROOT="${1:-}"
                    [[ -n "$VAL_STATE_ROOT" ]] || { _release_fail "--state-root requires a value"; return 1; }
                    FLAG_STATE_ROOT_OVERRIDE=1
                    ;;
                --releases-dir)
                    shift
                    VAL_RELEASES_DIR="${1:-}"
                    [[ -n "$VAL_RELEASES_DIR" ]] || { _release_fail "--releases-dir requires a value"; return 1; }
                    FLAG_RELEASES_DIR_OVERRIDE=1
                    ;;
                --archive-root)
                    shift
                    VAL_ARCHIVE_ROOT="${1:-}"
                    [[ -n "$VAL_ARCHIVE_ROOT" ]] || { _release_fail "--archive-root requires a value"; return 1; }
                    FLAG_ARCHIVE_ROOT_OVERRIDE=1
                    ;;
                --dryrun) FLAG_DRYRUN=1 ;;
                --verbose) FLAG_VERBOSE=1 ;;
                --help|-h) print_usage; exit 0 ;;
                *) _release_fail "Unknown argument: $1"; return 1 ;;
            esac
            shift
        done
    }

    # fn: _normalize_root - Normalize an absolute filesystem root
        # . Purpose
        #   Normalize an absolute filesystem root.
        # . Returns
        #   0 when the root is absolute; 1 otherwise.
        # . Usage
        #   root="$(_normalize_root "/")"
    _normalize_root() {
        local root="${1:-/}"
        [[ "$root" == /* ]] || return 1
        root="${root%/}"
        [[ -n "$root" ]] || root="/"
        printf '%s\n' "$root"
    }

    # fn: init_paths - Resolve target, state, release, and archive directories
        # . Purpose
        #   Resolve target, state, release, and archive directories.
        # . Returns
        #   0 on success; 1 when the target root is invalid.
        # . Usage
        #   init_paths
    # fn: _release_default_target_root - Derive target root only from canonical manager location
        # . Usage
        #   _release_default_target_root
    _release_default_target_root() {
        local suffix="/var/lib/solidgroundux/sgnd-setup.sh"
        local root=""

        if [[ "$SCRIPT_FILE" == *"$suffix" ]]; then
            root="${SCRIPT_FILE%$suffix}"
            [[ -n "$root" ]] || root="/"
            printf '%s\n' "$root"
            return 0
        fi

        # Bootstrap/unpacked copies are not in their required installed location.
        printf '%s\n' "/"
    }

    init_paths() {
        VAL_TARGET_ROOT="$(_normalize_root "$VAL_TARGET_ROOT")" || {
            _release_fail "Target root must be absolute: $VAL_TARGET_ROOT"
            return 1
        }

        if [[ -z "$VAL_STATE_ROOT" ]] || (( ! FLAG_STATE_ROOT_OVERRIDE )); then
            if [[ "$VAL_TARGET_ROOT" == "/" ]]; then
                VAL_STATE_ROOT="/var/lib/solidgroundux"
            else
                VAL_STATE_ROOT="${VAL_TARGET_ROOT%/}/var/lib/solidgroundux"
            fi
        fi

        CANONICAL_MANAGER_PATH="${VAL_STATE_ROOT%/}/sgnd-setup.sh"
        SGND_RELEASE_CONFIG_FILE="${VAL_STATE_ROOT%/}/release-manager.cfg"
        RELEASE_STATE_FILE="${VAL_STATE_ROOT%/}/release-manager.state"
    }

    # fn: _release_load_state - Load standalone parameter defaults
        # . Usage
        #   _release_load_state
    _release_load_state() {
        local file="${RELEASE_STATE_FILE:-}"
        local key="" value=""

        [[ -r "$file" ]] || return 0

        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            case "$key" in
                VAL_TARGET_ROOT)  (( FLAG_TARGET_ROOT_OVERRIDE )) || VAL_TARGET_ROOT="$value" ;;
                VAL_PROJECT)      (( FLAG_PROJECT_OVERRIDE )) || VAL_PROJECT="$value" ;;
                VAL_SOURCE)       : ;; # transient package source; intentionally not restored
                VAL_RELEASE)      (( FLAG_RELEASE_OVERRIDE )) || VAL_RELEASE="$value" ;;
                VAL_GITHUB_REPO)  (( FLAG_REPO_OVERRIDE )) || VAL_GITHUB_REPO="$value" ;;
                VAL_GITHUB_URL)   (( FLAG_REPO_OVERRIDE )) || VAL_GITHUB_URL="$value" ;;
                VAL_VARIANT)      (( FLAG_VARIANT_OVERRIDE )) || VAL_VARIANT="$value" ;;
                VAL_STATE_ROOT)   (( FLAG_STATE_ROOT_OVERRIDE )) || VAL_STATE_ROOT="$value" ;;
                *) ;;
            esac
        done < "$file"
    }

    # fn: _release_save_state - Persist accepted parameter values
        # . Usage
        #   _release_save_state
    _release_save_state() {
        local file="${RELEASE_STATE_FILE:-}"

        [[ -n "$file" ]] || return 0
        if (( FLAG_DRYRUN )); then
            _release_info "Would save setup state: $file"
            return 0
        fi

        mkdir -p -- "$(dirname -- "$file")" || return 1
        {
            printf 'VAL_TARGET_ROOT=%s\n' "$VAL_TARGET_ROOT"
            printf 'VAL_PROJECT=%s\n' "${VAL_PROJECT:-solidgroundux}"
            printf 'VAL_RELEASE=%s\n' "${VAL_RELEASE:-}"
            printf 'VAL_GITHUB_REPO=%s\n' "${VAL_GITHUB_REPO:-}"
            printf 'VAL_GITHUB_URL=%s\n' "${VAL_GITHUB_URL:-}"
            printf 'SGND_RELEASE_BUILD=%s\n' "${SGND_RELEASE_BUILD:-}"
            printf 'VAL_VARIANT=%s\n' "${VAL_VARIANT:-}"
            printf 'VAL_STATE_ROOT=%s\n' "$VAL_STATE_ROOT"
        } > "$file" || return 1
        chmod 0600 "$file" 2>/dev/null || true
    }

    # fn: _release_definition_value - Read one simple assignment from a definitions file
        # . Purpose
        #   Read product release metadata without sourcing project-controlled shell code.
        # . Returns
        #   0 with the unquoted value on stdout; 1 when the key is absent.
        # . Usage
        #   value="$(_release_definition_value "$file" "SGND_RELEASE_URL")"
    _release_definition_value() {
        local file="${1:?missing definitions file}"
        local key="${2:?missing key}"
        local value=""
        value="$(sed -n -E "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$/\1/p" "$file" | head -n 1)"
        [[ -n "$value" ]] || return 1
        value="$(_release_normalize_github_url "$value" 2>/dev/null || printf '%s' "$value")"
        printf '%s\n' "$value"
    }

    # fn: _release_normalize_github_url - Normalize a GitHub repository/release URL
        # Returns:
        #   0 with the normalized URL on stdout; 1 when empty.
        # Usage:
        #   url="$(_release_normalize_github_url "$url")"
    _release_normalize_github_url() {
        local url="${1:-}"
        url="$(printf '%s' "$url" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        while [[ ${#url} -ge 2 ]]; do
            if [[ "$url" == \"*\" && "$url" == *\" ]]; then
                url="${url#\"}"; url="${url%\"}"
            elif [[ "$url" == \'*\' && "$url" == *\' ]]; then
                url="${url#\'}"; url="${url%\'}"
            else
                break
            fi
            url="$(printf '%s' "$url" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        done
        [[ -n "$url" ]] || return 1
        printf '%s\n' "$url"
    }

    # fn: _release_project_repo_state_file - Resolve per-project repository state file
        # Returns:
        #   0 with the state pathname on stdout.
        # Usage:
        #   file="$(_release_project_repo_state_file "$project")"
    _release_project_repo_state_file() {
        local project="${1:-${VAL_PROJECT:-solidgroundux}}"
        printf '%s/projects/%s/repository.url\n' "${VAL_STATE_ROOT%/}" "$project"
    }

    # fn: _release_load_project_repo - Load a saved repository URL for one project
        # Returns:
        #   0 when a saved URL was loaded; 1 when none exists.
        # Usage:
        #   _release_load_project_repo "$project"
    _release_load_project_repo() {
        local project="${1:-${VAL_PROJECT:-solidgroundux}}" file="" url="" repo=""
        file="$(_release_project_repo_state_file "$project")"
        [[ -r "$file" ]] || return 1
        IFS= read -r url < "$file" || true
        url="$(_release_normalize_github_url "$url" 2>/dev/null || true)"
        [[ -n "$url" ]] || return 1
        repo="$(_release_repo_from_url "$url" 2>/dev/null || true)"
        [[ -n "$repo" ]] || return 1
        VAL_GITHUB_URL="$url"
        VAL_GITHUB_REPO="$repo"
        return 0
    }

    # fn: _release_save_project_repo - Persist repository URL for the selected project
        # Returns:
        #   0 on success; non-zero on persistence failure.
        # Usage:
        #   _release_save_project_repo
    _release_save_project_repo() {
        local file="" url=""
        url="$(_release_normalize_github_url "${VAL_GITHUB_URL:-}" 2>/dev/null || true)"
        [[ -n "$url" ]] || return 0
        VAL_GITHUB_URL="$url"
        file="$(_release_project_repo_state_file "${VAL_PROJECT:-solidgroundux}")"
        if (( FLAG_DRYRUN )); then
            _release_info "Would save project GitHub repository: $file"
            return 0
        fi
        mkdir -p -- "$(dirname -- "$file")" || return 1
        printf '%s\n' "$url" > "$file" || return 1
        chmod 0600 "$file" 2>/dev/null || true
    }

    # fn: _release_repo_from_url - Convert a GitHub release URL to OWNER/REPO
        # Returns:
        #   0 with OWNER/REPO on stdout; 1 for an unsupported URL.
        # Usage:
        #   repo="$(_release_repo_from_url "$url")"
    _release_repo_from_url() {
        local url="${1:-}"
        url="$(_release_normalize_github_url "$url" 2>/dev/null || true)"
        [[ -n "$url" ]] || return 1
        url="${url#https://github.com/}"
        url="${url#http://github.com/}"
        url="${url%/releases}"; url="${url%/}"
        [[ "$url" == */* && "$url" != http* ]] || return 1
        printf '%s\n' "$url"
    }

    # fn: _release_package_catalog - List release packages known to this target
        # . Purpose
        #   Build the selectable package catalog from installed product definitions, with
        #   bootstrap defaults for products that may not yet be installed on a clean target.
        # . Output
        #   Writes project|product|variant|release-url|version|build records.
        # . Usage
        #   mapfile -t packages < <(_release_package_catalog)
    _release_package_catalog() {
        local globals="${VAL_TARGET_ROOT%/}/usr/local/lib/solidgroundux/globals"
        local file="" product="" version="" build="" url="" product_var="" version_var="" build_var=""
        local modules_seen=0 framework_seen=0

        if [[ -f "$globals/sgnd-definitions.sh" ]]; then
            product="$(_release_definition_value "$globals/sgnd-definitions.sh" SGND_PRODUCT 2>/dev/null || true)"
            version="$(_release_definition_value "$globals/sgnd-definitions.sh" SGND_VERSION 2>/dev/null || true)"
            build="$(_release_definition_value "$globals/sgnd-definitions.sh" SGND_BUILD 2>/dev/null || true)"
            url="$(_release_definition_value "$globals/sgnd-definitions.sh" SGND_RELEASE_URL 2>/dev/null || true)"
            printf 'solidgroundux|%s|individual|%s|%s|%s\n' "${product:-SolidGroundUX}" "${url:-https://github.com/$SGND_RELEASE_GITHUB_REPO/releases}" "${version:-2.1}" "$build"
            framework_seen=1
        fi

        if [[ -d "$globals" ]]; then
            while IFS= read -r -d '' file; do
                [[ "$(basename -- "$file")" == "sgnd-definitions.sh" ]] && continue
                product_var="$(sed -n -E 's/^[[:space:]]*(SGND_[A-Za-z0-9_]+_PRODUCT)[[:space:]]*=.*$/\1/p' "$file" | head -n 1)"
                [[ -n "$product_var" ]] || continue
                version_var="${product_var%_PRODUCT}_VERSION"
                build_var="${product_var%_PRODUCT}_BUILD"
                product="$(_release_definition_value "$file" "$product_var" 2>/dev/null || true)"
                version="$(_release_definition_value "$file" "$version_var" 2>/dev/null || true)"
                build="$(_release_definition_value "$file" "$build_var" 2>/dev/null || true)"
                url="$(_release_definition_value "$file" "${product_var%_PRODUCT}_RELEASE_URL" 2>/dev/null || true)"
                if [[ "$product" == "SolidGroundUX Management Console Modules" ]]; then
                    modules_seen=1
                    [[ -n "$url" ]] || url="https://github.com/$SGND_MANAGEMENT_MODULES_GITHUB_REPO/releases"
                fi
                [[ -n "$url" ]] || continue
                printf '%s|%s|individual|%s|%s|%s\n' "$(basename -- "$file" -definitions.sh)" "$product" "$url" "$version" "$build"
            done < <(find "$globals" -maxdepth 1 -type f -name '*-definitions.sh' -print0 2>/dev/null | sort -z)
        fi

        (( framework_seen )) || {
            printf 'solidgroundux|SolidGroundUX|individual|https://github.com/%s/releases|2.1|\n' "$SGND_RELEASE_GITHUB_REPO"
        }
        (( modules_seen )) || printf 'solidground-management-console-modules|SolidGroundUX Management Console Modules|individual|https://github.com/%s/releases|1.1|\n' "$SGND_MANAGEMENT_MODULES_GITHUB_REPO"
    }

    # fn: _release_select_package_interactive - Select a product package and derive its context
        # . Purpose
        #   Make package selection the normal entry point. Project, product, channel, version,
        #   build, and GitHub URL are derived from the selected product; the URL remains editable.
        # . Returns
        #   0 after package selection; 2 when manual override was selected; 1 on cancellation.
        # . Usage
        #   _release_select_package_interactive
    _release_select_package_interactive() {
        local choice="" row="" project="" product="" variant="" url="" version="" build="" repo="" i=0
        local -a packages=()
        mapfile -t packages < <(_release_package_catalog)
        (( ${#packages[@]} > 0 )) || return 2

        printf '\n%sAvailable packages%s\n' "$_RL_BRIGHT_WHITE" "$_RL_RESET" > /dev/tty
        _release_line "─" > /dev/tty
        for (( i=0; i<${#packages[@]}; i++ )); do
            IFS='|' read -r project product variant url version build <<< "${packages[$i]}"
            printf '  %s%d)%s %s%s%s  %s[%s / %s.%s]%s\n' "$_RL_UI_PROMPT" "$((i+1))" "$_RL_RESET" "$_RL_UI_TEXT" "$product" "$_RL_RESET" "$_RL_DARK_WHITE" "$variant" "$version" "${build:--}" "$_RL_RESET" > /dev/tty
        done
        printf '  %sM)%s %sManual configuration / override%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        printf '  %sQ)%s %sCancel%s\n\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        _release_line "─" > /dev/tty
        printf '%sSelect package: %s' "$_RL_UI_PROMPT" "$_RL_UI_INPUT" > /dev/tty
        read -r choice < /dev/tty
        printf '%s' "$_RL_RESET" > /dev/tty
        case "${choice^^}" in M) return 2 ;; Q|"") return 1 ;; esac
        [[ "$choice" =~ ^[0-9]+$ ]] || return 1
        (( choice >= 1 && choice <= ${#packages[@]} )) || return 1
        row="${packages[$((choice-1))]}"
        IFS='|' read -r project product variant url version build <<< "$row"

        VAL_PROJECT="$project"
        VAL_VARIANT="$variant"
        SGND_RELEASE_VARIANT="$variant"
        SGND_RELEASE_LINE="$version"
        SGND_RELEASE_BUILD="$build"
        _set_project_context "$project" || return 1
        SGND_RELEASE_PRODUCT="$product"

        # Version and build are product metadata, not Setup input. Keep the
        # values discovered from the selected product definitions/catalog until GitHub
        # discovery supplies the identity of a newer published artifact. Repository
        # overrides are persisted per project and take precedence over definitions.
        VAL_GITHUB_URL=""
        VAL_GITHUB_REPO=""
        _release_load_project_repo "$project" || true
        _release_ask "GitHub repository URL" VAL_GITHUB_URL "${VAL_GITHUB_URL:-${url:-https://github.com/$SGND_RELEASE_GITHUB_REPO/releases}}" || return 1
        VAL_GITHUB_URL="$(_release_normalize_github_url "$VAL_GITHUB_URL" 2>/dev/null || true)"
        repo="$(_release_repo_from_url "$VAL_GITHUB_URL" 2>/dev/null || true)"
        [[ -n "$repo" ]] || { _release_fail "Invalid GitHub repository URL: $VAL_GITHUB_URL"; return 1; }
        VAL_GITHUB_REPO="$repo"
        _release_save_project_repo || return 1
        return 0
    }

    # fn: _release_prompt_manual_settings - Collect explicit product/repository/channel overrides
        # Returns:
        #   0 when the manual settings are valid; non-zero otherwise.
        # Usage:
        #   _release_prompt_manual_settings
    _release_prompt_manual_settings() {
        local repo=""
        _release_ask "Project" VAL_PROJECT "${VAL_PROJECT:-solidgroundux}" || return 1
        _set_project_context "${VAL_PROJECT:-solidgroundux}" || return 1
        _release_ask "Product" SGND_RELEASE_PRODUCT "${SGND_RELEASE_PRODUCT:-$VAL_PROJECT}" || return 1
        _release_load_project_repo "${VAL_PROJECT:-solidgroundux}" || true
        _release_ask "GitHub repository URL" VAL_GITHUB_URL "${VAL_GITHUB_URL:-https://github.com/${VAL_GITHUB_REPO:-$SGND_RELEASE_GITHUB_REPO}/releases}" || return 1
        VAL_GITHUB_URL="$(_release_normalize_github_url "$VAL_GITHUB_URL" 2>/dev/null || true)"
        repo="$(_release_repo_from_url "$VAL_GITHUB_URL" 2>/dev/null || true)"
        [[ -n "$repo" ]] || { _release_fail "Invalid GitHub repository URL: $VAL_GITHUB_URL"; return 1; }
        VAL_GITHUB_REPO="$repo"
        _release_save_project_repo || return 1
        _release_ask "Release variant (bundle/individual)" VAL_VARIANT "${VAL_VARIANT:-individual}" || return 1
        [[ "$VAL_VARIANT" == "bundle" || "$VAL_VARIANT" == "individual" ]] || return 1
        SGND_RELEASE_VARIANT="$VAL_VARIANT"
    }

    # fn: _release_prompt_settings - Resolve the setup target root
        # . Purpose
        #   Resolve only the installation target. Product/package selection belongs to each action.
        # . Usage
        #   _release_prompt_settings
    _release_prompt_settings() {
        local target_before="$VAL_TARGET_ROOT"
        (( FLAG_AUTO )) && return 0
        [[ -t 0 && -t 1 ]] || return 0

        _release_section_header "Setup target"
        _release_ask "Target root" VAL_TARGET_ROOT "$VAL_TARGET_ROOT" || return 1
        VAL_TARGET_ROOT="$(_normalize_root "$VAL_TARGET_ROOT")" || { _release_fail "Target root must be absolute: $VAL_TARGET_ROOT"; return 1; }
        if [[ "$VAL_TARGET_ROOT" != "$target_before" ]] && (( ! FLAG_STATE_ROOT_OVERRIDE )); then VAL_STATE_ROOT=""; fi
        init_paths || return 1
        _release_try_framework_ui
        _release_save_state
    }

    # fn: _package_info_value - Read one key from release-package.info safely
        # . Purpose
        #   Parse a simple KEY=value field without sourcing package-controlled shell code.
        # . Usage
        #   _package_info_value "<file>" "<key>"
    _package_info_value() {
        local file="${1:?missing package info}"
        local key="${2:?missing key}"
        local value=""

        value="$(sed -n -E "s/^${key}=(.*)$/\1/p" "$file" | head -n 1)"
        [[ -n "$value" ]] || return 1
        printf '%s\n' "$value"
    }

    # fn: _project_slug_safe - Validate a project slug used beneath the manager state root
        # . Usage
        #   _project_slug_safe "<slug>"
    _project_slug_safe() {
        local slug="${1:-}"
        [[ "$slug" =~ ^[a-z0-9][a-z0-9._-]*$ ]]
    }

    # fn: _load_project_info - Load persisted display identity for one project
        # . Usage
        #   _load_project_info "<slug>"
    _load_project_info() {
        local slug="${1:?missing project slug}"
        local info=""
        local product=""

        [[ "$slug" == "solidgroundux" ]] && {
            SGND_RELEASE_PRODUCT="SolidGroundUX"
            return 0
        }

        info="${VAL_STATE_ROOT%/}/projects/${slug}/project.info"
        if [[ -r "$info" ]]; then
            product="$(_package_info_value "$info" "SGND_PACKAGE_PRODUCT" 2>/dev/null || true)"
        fi

        SGND_RELEASE_PRODUCT="${product:-$slug}"
        return 0
    }

    # fn: _set_project_context - Select release/archive state for one project
        # . Purpose
        #   Make all existing installation-engine functions operate on the selected project.
        #
        # . Behavior
        #   - SolidGroundUX keeps its legacy state layout for backwards compatibility.
        #   - Other projects use /var/lib/solidgroundux/projects/<slug>/.
        # . Usage
        #   _set_project_context "<slug>"
    _set_project_context() {
        local slug="${1:-solidgroundux}"

        slug="${slug,,}"
        _project_slug_safe "$slug" || {
            _release_fail "Invalid project slug: $slug"
            return 1
        }

        SGND_RELEASE_PROJECT="$slug"
        VAL_PROJECT="$slug"

        if [[ "$slug" == "solidgroundux" ]]; then
            PROJECT_STATE_ROOT="$VAL_STATE_ROOT"
            PROJECT_INFO_FILE=""
            (( FLAG_RELEASES_DIR_OVERRIDE )) || VAL_RELEASES_DIR="${VAL_STATE_ROOT%/}/releases"
            (( FLAG_ARCHIVE_ROOT_OVERRIDE )) || VAL_ARCHIVE_ROOT="${VAL_STATE_ROOT%/}/archive"
        else
            PROJECT_STATE_ROOT="${VAL_STATE_ROOT%/}/projects/${slug}"
            PROJECT_INFO_FILE="${PROJECT_STATE_ROOT%/}/project.info"
            (( FLAG_RELEASES_DIR_OVERRIDE )) || VAL_RELEASES_DIR="${PROJECT_STATE_ROOT%/}/releases"
            (( FLAG_ARCHIVE_ROOT_OVERRIDE )) || VAL_ARCHIVE_ROOT="${PROJECT_STATE_ROOT%/}/archive"
        fi

        _load_project_info "$slug"
        if [[ "$slug" != "solidgroundux" && -z "${VAL_VARIANT:-}" ]]; then
            VAL_VARIANT="individual"
        fi
        SGND_RELEASE_VARIANT="${VAL_VARIANT:-$SGND_RELEASE_VARIANT}"
        return 0
    }

    # fn: _persist_project_info - Persist display identity for an admitted project package
        # . Usage
        #   _persist_project_info "<package_info>"
    _persist_project_info() {
        local package_info="${1:?missing package info}"

        [[ "$SGND_RELEASE_PROJECT" == "solidgroundux" ]] && return 0
        [[ -n "$PROJECT_INFO_FILE" ]] || return 1

        if (( FLAG_DRYRUN )); then
            printf '[DRYRUN] copy %q -> %q\n' "$package_info" "$PROJECT_INFO_FILE"
            return 0
        fi

        mkdir -p -- "$(dirname -- "$PROJECT_INFO_FILE")" || return 1
        cp -f -- "$package_info" "$PROJECT_INFO_FILE"
    }

    # fn: _list_known_projects - List locally known project slugs
        # . Usage
        #   _list_known_projects
    _list_known_projects() {
        local dir=""
        printf '%s\n' "solidgroundux"
        if [[ -d "${VAL_STATE_ROOT%/}/projects" ]]; then
            find "${VAL_STATE_ROOT%/}/projects" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null \
                | LC_ALL=C sort
        fi
    }

    # fn: _select_project_interactive - Select a locally known project
        # . Usage
        #   _select_project_interactive "<command_name>"
    _select_project_interactive() {
        local slug=""
        local choice=""
        local i=0
        local -a projects=()

        mapfile -t projects < <(_list_known_projects)
        (( ${#projects[@]} > 0 )) || return 1

        printf '\n%sProjects%s\n' "$_RL_BRIGHT_WHITE" "$_RL_RESET" > /dev/tty
        _release_line "─" > /dev/tty
        for (( i=0; i<${#projects[@]}; i++ )); do
            slug="${projects[$i]}"
            printf '  %s%d)%s %s%s%s\n' \
                "$_RL_UI_PROMPT" "$((i+1))" "$_RL_RESET" \
                "$_RL_UI_TEXT" "$slug" "$_RL_RESET" > /dev/tty
        done
        printf '  %sQ)%s %sReturn%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        _release_line "─" > /dev/tty
        printf '%sSelect project: %s' "$_RL_UI_PROMPT" "$_RL_UI_INPUT" > /dev/tty
        read -r choice < /dev/tty
        printf '%s' "$_RL_RESET" > /dev/tty

        case "${choice^^}" in Q|"") return 1 ;; esac
        [[ "$choice" =~ ^[0-9]+$ ]] || return 1
        (( choice >= 1 && choice <= ${#projects[@]} )) || return 1

        printf '%s\n' "${projects[$((choice-1))]}"
    }

    # fn: _require_command - Verify that a required system command is available
        # . Purpose
        #   Verify that a required system command is available.
        # . Returns
        #   0 when available; 1 otherwise.
        # . Usage
        #   _require_command tar
    _require_command() {
        local command_name="${1:?missing command}"
        command -v "$command_name" >/dev/null 2>&1 || {
            _release_fail "Required command not found: $command_name"
            return 1
        }
    }

# --- Standalone configuration --------------------------------------------------------
    # fn: _load_release_manager_config - Load persistent standalone setup settings
        # . Purpose
        #   Load release-source settings from the compatibility config file without
        #   depending on SolidGroundUX framework configuration libraries.
        # . Returns
        #   0 always; missing config is not an error.
        # . Usage
        #   _load_release_manager_config
    _load_release_manager_config() {
        local cfg="${SGND_RELEASE_CONFIG_FILE:-}"
        if [[ -z "$cfg" || ! -r "$cfg" ]]; then
            VAL_GITHUB_REPO="${VAL_GITHUB_REPO:-$SGND_RELEASE_GITHUB_REPO}"
            VAL_VARIANT="${VAL_VARIANT:-$SGND_RELEASE_VARIANT}"
            return 0
        fi

        # shellcheck disable=SC1090
        source "$cfg"
        : "${SGND_RELEASE_GITHUB_REPO:=Testadura-Mark/SolidGroundUX}"
        : "${SGND_RELEASE_LINE:=2.1}"
        : "${SGND_RELEASE_API_URL:=https://api.github.com/repos/${SGND_RELEASE_GITHUB_REPO}/releases/latest}"
        VAL_GITHUB_REPO="${VAL_GITHUB_REPO:-$SGND_RELEASE_GITHUB_REPO}"
        VAL_VARIANT="${VAL_VARIANT:-$SGND_RELEASE_VARIANT}"
        SGND_RELEASE_VARIANT="$VAL_VARIANT"
        return 0
    }

    # fn: _ensure_release_manager_config - Create the persistent standalone config when absent
        # . Purpose
        #   Seed release-manager.cfg with the current release source and release line.
        # . Returns
        #   0 on success; non-zero on write failure.
        # . Usage
        #   _ensure_release_manager_config
    _ensure_release_manager_config() {
        local cfg="${SGND_RELEASE_CONFIG_FILE:?setup config path not initialized}"
        [[ -e "$cfg" ]] && return 0

        if (( FLAG_DRYRUN )); then
            printf '[DRYRUN] create %q\n' "$cfg"
            return 0
        fi

        {
            printf '%s\n' '# SolidGroundUX Setup configuration'
            printf 'SGND_RELEASE_LINE=%q\n' "$SGND_RELEASE_LINE"
            printf 'SGND_RELEASE_GITHUB_REPO=%q\n' "${VAL_GITHUB_REPO:-$SGND_RELEASE_GITHUB_REPO}"
            printf 'SGND_RELEASE_VARIANT=%q\n' "${VAL_VARIANT:-$SGND_RELEASE_VARIANT}"
            printf 'SGND_RELEASE_API_URL=%q\n' "https://api.github.com/repos/${VAL_GITHUB_REPO:-$SGND_RELEASE_GITHUB_REPO}/releases/latest"
        } > "$cfg" || return 1

        chmod 0644 "$cfg"
    }

# --- Bootstrap housekeeping ----------------------------------------------------------
    # fn: _ensure_manager_directories - Ensure standalone setup directories exist
        # . Purpose
        #   Create the state, pending-release, and archive directories required by the
        #   standalone setup tool.
        # . Returns
        #   0 on success; non-zero when a required directory cannot be created.
        # . Usage
        #   _ensure_manager_directories
    _ensure_manager_directories() {
        _release_run mkdir -p -- "$VAL_STATE_ROOT" "$VAL_RELEASES_DIR" "$VAL_ARCHIVE_ROOT"
        if [[ "$SGND_RELEASE_PROJECT" != "solidgroundux" ]]; then
            _release_run mkdir -p -- "$PROJECT_STATE_ROOT"
        fi
    }

    # fn: _install_setup_wrappers - Install public setup commands
        # . Purpose
        #   Install sgnd-setup and retain sgnd-release-manager as a compatibility alias.
        # . Returns
        #   0 on success; non-zero on filesystem failure.
        # . Usage
        #   _install_setup_wrappers
    _install_setup_wrappers() {
        local bin_dir="" wrapper=""

        if [[ "$VAL_TARGET_ROOT" == "/" ]]; then
            bin_dir="/usr/local/bin"
        else
            bin_dir="${VAL_TARGET_ROOT%/}/usr/local/bin"
        fi
        _release_run mkdir -p -- "$bin_dir" || return 1

        for wrapper in "$bin_dir/sgnd-setup" "$bin_dir/sgnd-release-manager"; do
            if (( FLAG_DRYRUN )); then
                printf '[DRYRUN] write wrapper %q -> %q
' "$wrapper" "$CANONICAL_MANAGER_PATH"
                continue
            fi
            cat > "$wrapper" <<EOF
#!/usr/bin/env bash
exec "$CANONICAL_MANAGER_PATH" "\$@"
EOF
            chmod 0755 "$wrapper" || return 1
        done
        return 0
    }

    # fn: _install_setup_self - Install the standalone setup script at its canonical path
        # . Purpose
        #   Copy a bootstrap/setup copy to the canonical recovery path and install wrappers.
        # . Returns
        #   0 on success; non-zero on filesystem failure.
        # . Usage
        #   _install_setup_self
    _install_setup_self() {
        local source="$SCRIPT_FILE"
        [[ -n "$CANONICAL_MANAGER_PATH" ]] || return 1
        _release_run mkdir -p -- "$(dirname -- "$CANONICAL_MANAGER_PATH")" || return 1
        if [[ "$source" != "$CANONICAL_MANAGER_PATH" ]]; then
            _release_run cp -f -- "$source" "$CANONICAL_MANAGER_PATH" || return 1
        fi
        _release_run chmod 0755 -- "$CANONICAL_MANAGER_PATH" || return 1
        _install_setup_wrappers
    }

    # fn: _install_release_manager - Verify the canonical setup copy and wrappers at its canonical path
        # . Purpose
        #   Copy the currently running setup tool to the machine-local state root so
        #   future update, rollback, repair, and removal operations do not depend on a
        #   temporary bootstrap copy.
        # . Returns
        #   0 on success; non-zero when the manager cannot be copied or made executable.
        # . Usage
        #   _install_release_manager
    _install_release_manager() {
        [[ -n "$CANONICAL_MANAGER_PATH" ]] || return 1

        # The installed SolidGroundUX tar owns the canonical manager copy.
        # A ZIP-root/bootstrap or development copy must never overwrite it merely
        # because it is executing from a different pathname.
        [[ -f "$CANONICAL_MANAGER_PATH" ]] || {
            _release_fail "Canonical setup tool is missing: $CANONICAL_MANAGER_PATH"
            return 1
        }

        _release_run chmod 0755 -- "$CANONICAL_MANAGER_PATH" || return 1
        _install_setup_wrappers || return 1
        return 0
    }


    # fn: _cleanup_bootstrap_files - Remove known temporary bootstrap files after first install
        # . Purpose
        #   Clean only known first-install files when sgnd-setup was run
        #   from /tmp, leaving unrelated temporary files untouched.
        # . Returns
        #   0 always unless removal of a known bootstrap file fails.
        # . Usage
        #   _cleanup_bootstrap_files
    _cleanup_bootstrap_files() {
        local base="${BOOTSTRAP_RELEASE_BASE:-}"
        local source_dir="${BOOTSTRAP_SOURCE_DIR:-$SCRIPT_DIR}"
        local artifact=""
        local -a artifacts=()

        case "$source_dir" in
            /tmp|/tmp/*) ;;
            *) return 0 ;;
        esac

        [[ "$SCRIPT_FILE" != "$CANONICAL_MANAGER_PATH" ]] || return 0

        # New first-install packages contain product release ZIPs beside sgnd-setup.sh.
        # They have already been admitted to the canonical package store before cleanup.
        if [[ "$base" == "packages" ]]; then
            local package_row="" package_zip=""
            while IFS= read -r package_row; do
                package_zip="${package_row%%|*}"
                [[ -f "$package_zip" ]] && _release_run rm -f -- "$package_zip" || true
            done < <(_scan_product_packages "$source_dir")
        fi

        if [[ -n "$base" ]]; then
            artifacts=(
                "${base}.tar.gz"
                "${base}.tar.gz.sha256"
                "${base}.manifest"
                "${base}.manifest.sha256"
                "${base}.removed"
                "${base}.removed.sha256"
                "SHA256SUMS"
                "release-package.info"
                "RELEASE-PRODUCTS"
            )

            for artifact in "${artifacts[@]}"; do
                [[ -e "${source_dir%/}/${artifact}" ]] || continue
                _release_run rm -f -- "${source_dir%/}/${artifact}" || return 1
            done
        fi

        # The running script may safely unlink its temporary pathname after the canonical
        # copy has been written; the current process continues from the already-open file.
        [[ -e "$SCRIPT_FILE" ]] && _release_run rm -f -- "$SCRIPT_FILE" || true

        if [[ "$source_dir" != "/tmp" ]]; then
            if (( FLAG_DRYRUN )); then
                printf '[DRYRUN] rmdir -- %q\n' "$source_dir"
            else
                rmdir -- "$source_dir" 2>/dev/null || true
            fi
        fi

        return 0
    }

    # fn: _release_choose_post_install_action - Select what to do after a successful first install
        # . Purpose
        #   Let an interactive first-install session continue into Setup, open the
        #   Management Console, or return to the shell.
        # . Behavior
        #   - R continues into the Setup.
        #   - C opens the installed Management Console.
        #   - E, Esc, or Enter exits to the shell.
        #   - Exit is the default.
        # . Outputs (globals)
        #   BOOTSTRAP_POST_INSTALL_ACTION
        # . Returns
        #   0 after recording the selected action.
        # . Usage
        #   _release_choose_post_install_action
    _release_choose_post_install_action() {
        local choice=""

        BOOTSTRAP_POST_INSTALL_ACTION="exit"
        (( FLAG_AUTO )) && return 0
        [[ -t 0 && -t 1 ]] || return 0

        printf '\n' > /dev/tty
        printf '    %sR)%s %sSetup%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        printf '    %sC)%s %sManagement Console%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        printf '    %sE)%s %sExit%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        printf '\n%sSelect next action [Exit]: %s' "$_RL_UI_PROMPT" "$_RL_UI_INPUT" > /dev/tty
        IFS= read -r -s -n 1 choice < /dev/tty || true
        printf '%s\n' "$_RL_RESET" > /dev/tty

        case "$choice" in
            [Rr]) BOOTSTRAP_POST_INSTALL_ACTION="setup" ;;
            [Cc]) BOOTSTRAP_POST_INSTALL_ACTION="management-console" ;;
            [Ee]|$'\e'|"") BOOTSTRAP_POST_INSTALL_ACTION="exit" ;;
            *) BOOTSTRAP_POST_INSTALL_ACTION="exit" ;;
        esac
        return 0
    }

# --- Release identity and discovery -------------------------------------------------
    # fn: _release_product_artifact_name - Convert a display product name to its canonical release-file identity
        # Returns:
        #   Product name with whitespace runs replaced by hyphens.
        # Usage:
        #   artifact_product="$(_release_product_artifact_name "$SGND_RELEASE_PRODUCT")"
    _release_product_artifact_name() {
        local product_name="${1:-}"
        printf '%s\n' "$product_name" | sed -E 's/[[:space:]]+/-/g'
    }

    # fn: _release_base_from_archive - Derive a release base name from a tar.gz archive path
        # . Purpose
        #   Derive a release base name from a tar.gz archive path.
        # . Returns
        #   0 for a tar.gz archive; 1 otherwise.
        # . Usage
        #   base="$(_release_base_from_archive "$archive")"
    _release_base_from_archive() {
        local archive="${1:?missing archive}"
        local name="$(basename -- "$archive")"
        [[ "$name" == *.tar.gz ]] || return 1
        printf '%s\n' "${name%.tar.gz}"
    }

    # fn: _release_matches - Test whether a release base matches an optional selector
        # . Purpose
        #   Test whether a release base matches an optional selector.
        # . Returns
        #   0 when it matches; 1 otherwise.
        # . Usage
        #   _release_matches "$base" "$VAL_RELEASE"
    _release_variant_matches() {
        local base="${1:?missing base}"
        local variant="individual"
        local artifact_product="$(_release_product_artifact_name "$SGND_RELEASE_PRODUCT")"
        if [[ "$variant" == "bundle" ]]; then
            [[ "$base" == "${artifact_product}-bundled-"* ]]
        else
            [[ "$base" == "${artifact_product}-"* && "$base" != "${artifact_product}-bundled-"* ]]
        fi
    }

    _release_matches() {
        local base="${1:?missing base}"
        local requested="${2:-}"
        local artifact_product="$(_release_product_artifact_name "$SGND_RELEASE_PRODUCT")"
        _release_variant_matches "$base" || return 1
        [[ -z "$requested" ]] && return 0
        [[ "$base" == "$requested" ]] && return 0
        [[ "$base" == "${artifact_product}-${requested}" ]] && return 0
        [[ "$base" == "${artifact_product}-bundled-${requested}" ]] && return 0
        return 1
    }

    # fn: _release_sort - Sort release identifiers by version
        # . Purpose
        #   Sort release identifiers by version.
        # . Returns
        #   Status returned by sort.
        # . Usage
        #   printf "%s\n" "$release" | _release_sort
    _release_sort() {
        LC_ALL=C sort -V
    }

    # fn: _current_release - Return the highest archived release as the current version
        # . Purpose
        #   Return the highest archived release as the current version.
        # . Returns
        #   0 when an archived release exists; non-zero otherwise.
        # . Usage
        #   current="$(_current_release)"
    _current_release() {
        [[ -d "$VAL_ARCHIVE_ROOT" ]] || return 1
        _list_archived_releases | tail -n 1
    }

    # fn: _previous_release - Return the archived release immediately preceding current
        # . Purpose
        #   Return the archived release immediately preceding current.
        # . Returns
        #   0 when a previous release exists; non-zero otherwise.
        # . Usage
        #   previous="$(_previous_release)"
    _previous_release() {
        [[ -d "$VAL_ARCHIVE_ROOT" ]] || return 1
        _list_archived_releases | tail -n 2 | head -n 1
    }

    # fn: _list_archived_releases - List archived releases in ascending version order
        # . Purpose
        #   List archived releases in ascending version order.
        # . Returns
        #   0 always.
        # . Usage
        #   _list_archived_releases
    _list_archived_releases() {
        [[ -d "$VAL_ARCHIVE_ROOT" ]] || return 0
        local base="" artifact_product="$(_release_product_artifact_name "$SGND_RELEASE_PRODUCT")"
        while IFS= read -r base; do
            _release_variant_matches "$base" && printf '%s\n' "$base"
        done < <(find "$VAL_ARCHIVE_ROOT" -mindepth 1 -maxdepth 1 -type d -name "${artifact_product}-*" -printf '%f\n' 2>/dev/null) | _release_sort
    }

    # fn: _find_pending_archives - List pending release tarballs under the releases directory
        # . Purpose
        #   List pending release tarballs under the releases directory.
        # . Returns
        #   0 always.
        # . Usage
        #   _find_pending_archives
    _find_pending_archives() {
        [[ -d "$VAL_RELEASES_DIR" ]] || return 0
        local archive="" base="" artifact_product="$(_release_product_artifact_name "$SGND_RELEASE_PRODUCT")"
        while IFS= read -r archive; do
            base="$(_release_base_from_archive "$archive" 2>/dev/null || true)"
            [[ -n "$base" ]] && _release_variant_matches "$base" && printf '%s\n' "$archive"
        done < <(find "$VAL_RELEASES_DIR" -maxdepth 2 -type f -name "${artifact_product}-*.tar.gz" -print 2>/dev/null)
    }

    # fn: _newest_pending_archive - Find the newest pending archive matching an optional release selector
        # . Purpose
        #   Find the newest pending archive matching an optional release selector.
        # . Returns
        #   0 when found; 1 otherwise.
        # . Usage
        #   archive="$(_newest_pending_archive "$VAL_RELEASE")"
    _newest_pending_archive() {
        local archive=""
        local base=""
        local requested="${1:-}"
        local -a rows=()

        while IFS= read -r archive; do
            [[ -n "$archive" ]] || continue
            base="$(_release_base_from_archive "$archive")" || continue
            _release_matches "$base" "$requested" || continue
            rows+=("${base}|${archive}")
        done < <(_find_pending_archives)

        (( ${#rows[@]} > 0 )) || return 1
        printf '%s\n' "${rows[@]}" | LC_ALL=C sort -t '|' -k1,1V | tail -n 1 | cut -d '|' -f2-
    }

    # fn: _find_archived_archive - Find the tarball belonging to an archived release
        # . Purpose
        #   Find the tarball belonging to an archived release.
        # . Returns
        #   0 when found; 1 otherwise.
        # . Usage
        #   _find_archived_archive "$release"
    _find_archived_archive() {
        local requested="${1:?missing release}"
        local base=""
        local dir=""

        while IFS= read -r base; do
            _release_matches "$base" "$requested" || continue
            dir="${VAL_ARCHIVE_ROOT%/}/${base}"
            [[ -f "$dir/${base}.tar.gz" ]] && { printf '%s\n' "$dir/${base}.tar.gz"; return 0; }
        done < <(_list_archived_releases)
        return 1
    }

    # fn: _release_location - Resolve a release tarball from pending or archived storage
        # . Purpose
        #   Resolve a release tarball from pending or archived storage.
        # . Returns
        #   0 when found; non-zero otherwise.
        # . Usage
        #   _release_location "$release"
    _release_location() {
        local requested="${1:?missing release}"
        local archive=""

        archive="$(_newest_pending_archive "$requested" 2>/dev/null || true)"
        if [[ -n "$archive" ]]; then
            printf '%s\n' "$archive"
            return 0
        fi

        _find_archived_archive "$requested"
    }

    # fn: _pending_release_base_exists - Test whether a release is available in releases/
        # . Purpose
        #   Test whether a release is available in releases/.
        # . Returns
        #   0 when present; 1 otherwise.
        # . Usage
        #   _pending_release_base_exists "$release"
    _pending_release_base_exists() {
        local requested="${1:?missing release}"
        local archive=""
        archive="$(_newest_pending_archive "$requested" 2>/dev/null || true)"
        [[ -n "$archive" ]]
    }

    # fn: _archived_release_base_exists - Test whether a release is present in archive/
        # . Purpose
        #   Test whether a release is present in archive/.
        # . Returns
        #   0 when present; 1 otherwise.
        # . Usage
        #   _archived_release_base_exists "$release"
    _archived_release_base_exists() {
        local requested="${1:?missing release}"
        _find_archived_archive "$requested" >/dev/null 2>&1
    }

# --- Release verification -----------------------------------------------------------
    # fn: _verify_sha256_sidecar - Verify one release artifact against its SHA256 sidecar
        # . Purpose
        #   Verify one release artifact against its SHA256 sidecar.
        # . Returns
        #   0 when valid; 1 on missing or mismatched data.
        # . Usage
        #   _verify_sha256_sidecar "$file" "$file.sha256"
    _verify_sha256_sidecar() {
        local file_path="${1:?missing file}"
        local sha_file="${2:?missing checksum}"
        local expected=""
        local actual=""

        [[ -f "$file_path" ]] || { _release_fail "Missing release file: $file_path"; return 1; }
        [[ -f "$sha_file" ]] || { _release_fail "Missing checksum file: $sha_file"; return 1; }

        expected="$(awk 'NF {print $1; exit}' "$sha_file")"
        [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || {
            _release_fail "Invalid checksum file: $sha_file"
            return 1
        }

        actual="$(sha256sum "$file_path" | awk '{print $1}')" || return 1
        [[ "${actual,,}" == "${expected,,}" ]] || {
            _release_fail "Checksum mismatch: $(basename -- "$file_path")"
            return 1
        }

        _release_info "Verified checksum: $(basename -- "$file_path")"
    }

    # fn: _safe_relative_path - Validate and normalize a release-relative path
        # . Purpose
        #   Validate and normalize a release-relative path.
        # . Returns
        #   0 when safe; 1 for absolute or traversing paths.
        # . Usage
        #   path="$(_safe_relative_path "$raw")"
    _safe_relative_path() {
        local path="${1:-}"
        path="${path#./}"
        path="${path%/}"
        [[ -n "$path" ]] || return 1
        [[ "$path" != /* ]] || return 1
        [[ "$path" != ".." && "$path" != ../* && "$path" != */../* && "$path" != */.. ]] || return 1
        printf '%s\n' "$path"
    }

    # fn: _validate_tar_paths - Reject unsafe paths contained in a release tarball
        # . Purpose
        #   Reject unsafe paths contained in a release tarball.
        # . Returns
        #   0 when all paths are safe; 1 otherwise.
        # . Usage
        #   _validate_tar_paths "$archive"
    _validate_tar_paths() {
        local archive="${1:?missing archive}"
        local entry=""

        while IFS= read -r entry; do
            [[ "$entry" == "./" || -z "$entry" ]] && continue
            _safe_relative_path "$entry" >/dev/null || {
                _release_fail "Unsafe archive path rejected: $entry"
                return 1
            }
        done < <(tar -tzf "$archive")
    }

    # fn: _validate_manifest_paths - Reject unsafe paths contained in a release manifest
        # . Purpose
        #   Reject unsafe paths contained in a release manifest.
        # . Returns
        #   0 when all paths are safe; 1 otherwise.
        # . Usage
        #   _validate_manifest_paths "$manifest"
    _validate_manifest_paths() {
        local manifest="${1:?missing manifest}"
        local raw=""
        local path=""

        while IFS= read -r raw || [[ -n "$raw" ]]; do
            [[ -n "${raw//[[:space:]]/}" ]] || continue
            [[ "$raw" =~ ^[[:space:]]*# ]] && continue
            path="${raw%%[[:space:]]*}"
            [[ "$path" == "." || "$path" == "./" ]] && continue
            _safe_relative_path "$path" >/dev/null || {
                _release_fail "Unsafe manifest path rejected: $path"
                return 1
            }
        done < "$manifest"
    }

    # fn: _verify_release_set - Verify checksums and path safety for a complete release set
        # . Purpose
        #   Verify checksums and path safety for a complete release set.
        # . Returns
        #   0 when the release set is valid; 1 otherwise.
        # . Usage
        #   _verify_release_set "$archive"
    _verify_release_set() {
        local archive="${1:?missing archive}"
        local base=""
        local dir=""
        local manifest=""
        local removed=""

        _require_command tar || return 1
        _require_command sha256sum || return 1

        base="$(_release_base_from_archive "$archive")" || return 1
        dir="$(dirname -- "$archive")"
        manifest="$dir/${base}.manifest"
        removed="$dir/${base}.removed"

        _verify_sha256_sidecar "$archive" "${archive}.sha256" || return 1
        _verify_sha256_sidecar "$manifest" "${manifest}.sha256" || return 1
        _verify_sha256_sidecar "$removed" "${removed}.sha256" || return 1
        _validate_tar_paths "$archive" || return 1
        _validate_manifest_paths "$manifest" || return 1
        _validate_manifest_paths "$removed" || return 1

        return 0
    }

# --- Manifest operations ------------------------------------------------------------
    # fn: _manifest_paths - Emit normalized paths from a release manifest
        # . Purpose
        #   Emit normalized paths from a release manifest.
        # . Returns
        #   0 after reading the manifest.
        # . Usage
        #   _manifest_paths "$manifest"
    _manifest_paths() {
        local manifest="${1:?missing manifest}"
        local raw=""
        local path=""

        while IFS= read -r raw || [[ -n "$raw" ]]; do
            [[ -n "${raw//[[:space:]]/}" ]] || continue
            [[ "$raw" =~ ^[[:space:]]*# ]] && continue
            path="${raw%%[[:space:]]*}"
            [[ "$path" == "." || "$path" == "./" ]] && continue
            path="$(_safe_relative_path "$path")" || continue
            printf '%s\n' "$path"
        done < "$manifest"
    }

    # fn: _target_path - Map a release-relative path beneath the configured target root
        # . Purpose
        #   Map a release-relative path beneath the configured target root.
        # . Returns
        #   0 always.
        # . Usage
        #   target="$(_target_path "$rel")"
    _target_path() {
        local rel="${1:?missing relative path}"
        if [[ "$VAL_TARGET_ROOT" == "/" ]]; then
            printf '/%s\n' "$rel"
        else
            printf '%s/%s\n' "${VAL_TARGET_ROOT%/}" "$rel"
        fi
    }

    # fn: _remove_paths_from_stream - Remove streamed release paths conservatively from the target
        # . Purpose
        #   Remove streamed release paths conservatively from the target.
        # . Returns
        #   0 on success; non-zero when file removal fails.
        # . Usage
        #   _manifest_paths "$manifest" | _remove_paths_from_stream
    _remove_paths_from_stream() {
        local rel=""
        local target=""
        local -a paths=()
        local i=0

        while IFS= read -r rel; do
            [[ -n "$rel" ]] || continue
            paths+=("$rel")
        done

        # Deepest paths first so directories can be removed after their children.
        if (( ${#paths[@]} > 0 )); then
            mapfile -t paths < <(printf '%s\n' "${paths[@]}" | awk '{ print gsub("/", "/"), $0 }' | sort -k1,1nr -k2,2r | cut -d' ' -f2-)
        fi

        for (( i=0; i<${#paths[@]}; i++ )); do
            rel="${paths[$i]}"
            target="$(_target_path "$rel")"

            if [[ -L "$target" || -f "$target" ]]; then
                _release_run rm -f -- "$target" || return 1
                _release_info "Removed obsolete file: /$rel"
            elif [[ -d "$target" ]]; then
                if (( FLAG_DRYRUN )); then
                    printf '[DRYRUN] rmdir -- %q\n' "$target"
                else
                    rmdir -- "$target" 2>/dev/null || true
                fi
            fi
        done
    }

    # fn: _apply_removed_manifest - Apply the incoming release removal manifest
        # . Purpose
        #   Apply the incoming release removal manifest.
        # . Returns
        #   0 when complete; non-zero on removal failure.
        # . Usage
        #   _apply_removed_manifest "$removed"
    _apply_removed_manifest() {
        local removed="${1:?missing removed manifest}"
        [[ -s "$removed" ]] || return 0
        _manifest_paths "$removed" | _remove_paths_from_stream
    }

    # fn: _remove_release_difference - Remove paths present in one release manifest but absent from another
        # . Purpose
        #   Remove paths present in one release manifest but absent from another.
        # . Returns
        #   0 on success; non-zero on comparison/removal failure.
        # . Usage
        #   _remove_release_difference "$current_manifest" "$target_manifest"
    _remove_release_difference() {
        local from_manifest="${1:?missing from manifest}"
        local to_manifest="${2:?missing to manifest}"
        local old_sorted=""
        local new_sorted=""
        local diff_file=""

        old_sorted="$(mktemp)" || return 1
        new_sorted="$(mktemp)" || { rm -f "$old_sorted"; return 1; }
        diff_file="$(mktemp)" || { rm -f "$old_sorted" "$new_sorted"; return 1; }

        _manifest_paths "$from_manifest" | LC_ALL=C sort -u > "$old_sorted"
        _manifest_paths "$to_manifest" | LC_ALL=C sort -u > "$new_sorted"
        LC_ALL=C comm -23 "$old_sorted" "$new_sorted" > "$diff_file"

        _remove_paths_from_stream < "$diff_file"
        local rc=$?
        rm -f -- "$old_sorted" "$new_sorted" "$diff_file"
        return "$rc"
    }

# --- Archive/release movement -------------------------------------------------------
    # fn: _archive_release_set - Move an installed pending release set into versioned archive history
        # . Purpose
        #   Move an installed pending release set into versioned archive history.
        # . Returns
        #   0 on success; non-zero on filesystem failure.
        # . Usage
        #   _archive_release_set "$archive"
    _archive_release_set() {
        local archive="${1:?missing archive}"
        local base=""
        local source_dir=""
        local dest_dir=""
        local artifact=""
        local -a artifacts=()

        base="$(_release_base_from_archive "$archive")" || return 1
        source_dir="$(dirname -- "$archive")"
        dest_dir="${VAL_ARCHIVE_ROOT%/}/${base}"

        # Already archived: no movement required.
        if [[ "$source_dir" == "$dest_dir" ]]; then
            return 0
        fi

        artifacts=(
            "${base}.tar.gz"
            "${base}.tar.gz.sha256"
            "${base}.manifest"
            "${base}.manifest.sha256"
            "${base}.removed"
            "${base}.removed.sha256"
            "${base}.package"
            "${base}.products"
        )

        _release_run mkdir -p -- "$dest_dir" || return 1

        for artifact in "${artifacts[@]}"; do
            [[ -e "${source_dir%/}/${artifact}" ]] || continue
            _release_run mv -f -- "${source_dir%/}/${artifact}" "$dest_dir/" || return 1
        done

        if (( ! FLAG_DRYRUN )); then
            {
                for artifact in "${base}.tar.gz" "${base}.manifest" "${base}.removed"; do
                    if [[ -f "$dest_dir/$artifact" ]]; then
                        sha256sum "$dest_dir/$artifact" | sed "s|  $dest_dir/|  |"
                    fi
                done
            } > "$dest_dir/SHA256SUMS"
        fi

        # Remove release-local checksum residue and the empty versioned pending directory.
        if [[ "$source_dir" != "$VAL_RELEASES_DIR" && "$source_dir" == "$VAL_RELEASES_DIR"/* ]]; then
            if [[ -f "$source_dir/SHA256SUMS" ]]; then
                _release_run rm -f -- "$source_dir/SHA256SUMS" || return 1
            fi
            if (( FLAG_DRYRUN )); then
                printf '[DRYRUN] rmdir -- %q\n' "$source_dir"
            else
                rmdir -- "$source_dir" 2>/dev/null || true
            fi
        fi
    }

    # fn: _move_archive_dir_to_releases - Return one archived release directory to releases/
        # . Purpose
        #   Return one archived release directory to releases/.
        # . Returns
        #   0 on success; 1 when the destination exists or movement fails.
        # . Usage
        #   _move_archive_dir_to_releases "$base"
    _move_archive_dir_to_releases() {
        local base="${1:?missing release base}"
        local source="${VAL_ARCHIVE_ROOT%/}/${base}"
        local dest="${VAL_RELEASES_DIR%/}/${base}"

        [[ -d "$source" ]] || return 0
        [[ ! -e "$dest" ]] || {
            _release_fail "Cannot move archived release back to releases; destination exists: $dest"
            return 1
        }

        _release_run mkdir -p -- "$VAL_RELEASES_DIR" || return 1
        _release_run mv -- "$source" "$dest"
    }

    # fn: _move_newer_archives_to_releases - Return archived versions newer than a rollback target to releases/
        # . Purpose
        #   Return archived versions newer than a rollback target to releases/.
        # . Returns
        #   0 on success; non-zero on movement failure.
        # . Usage
        #   _move_newer_archives_to_releases "$target_base"
    _move_newer_archives_to_releases() {
        local target_base="${1:?missing target release}"
        local base=""
        local newer=0

        while IFS= read -r base; do
            [[ "$base" == "$target_base" ]] && { newer=1; continue; }
            (( newer )) || continue
            _move_archive_dir_to_releases "$base" || return 1
        done < <(_list_archived_releases)
    }

    # fn: _move_all_archives_to_releases - Return all archived releases to releases/
        # . Purpose
        #   Return all archived releases to releases/.
        # . Returns
        #   0 on success; non-zero on movement failure.
        # . Usage
        #   _move_all_archives_to_releases
    _move_all_archives_to_releases() {
        local base=""
        while IFS= read -r base; do
            [[ -n "$base" ]] || continue
            _move_archive_dir_to_releases "$base" || return 1
        done < <(_list_archived_releases)
    }

# --- Release channel ----------------------------------------------------------------
    # fn: _remember_release_channel - Persist the channel of the successfully installed release
    _remember_release_channel() {
        local archive="${1:?missing archive}" base="" metadata="" type=""
        base="$(_release_base_from_archive "$archive")" || return 1
        metadata="${VAL_ARCHIVE_ROOT%/}/${base}/${base}.package"
        [[ -r "$metadata" ]] || metadata="$(dirname -- "$archive")/${base}.package"
        type="$(_package_info_value "$metadata" "SGND_PACKAGE_TYPE" 2>/dev/null || true)"
        [[ -n "$type" ]] || type="individual"
        [[ "$type" == "product" ]] && type="individual"
        [[ "$type" == "bundle" || "$type" == "individual" ]] || return 1
        VAL_VARIANT="$type"
        SGND_RELEASE_VARIANT="$type"
        _release_save_state
    }

# --- Installation engine ------------------------------------------------------------
    # fn: _extract_release - Extract a complete SolidGroundUX release beneath the target root
        # . Purpose
        #   Extract a complete SolidGroundUX release beneath the target root.
        # . Returns
        #   0 on success; non-zero when extraction fails.
        # . Usage
        #   _extract_release "$archive"
    _extract_release() {
        local archive="${1:?missing archive}"
        _release_run mkdir -p -- "$VAL_TARGET_ROOT" || return 1
        _release_run tar -xzpf "$archive" -C "$VAL_TARGET_ROOT" --no-same-owner --no-overwrite-dir || return 1
        _release_ok "Installed $(_release_base_from_archive "$archive")"
    }

    # fn: _install_pending_archive - Install, update, or roll back to a pending release archive
        # . Purpose
        #   Install, update, or roll back to a pending release archive.
        # . Returns
        #   0 on success; non-zero on verification or deployment failure.
        # . Usage
        #   _install_pending_archive "$archive"
    _install_pending_archive() {
        local archive="${1:?missing archive}"
        local base=""
        local current=""
        local removed=""
        local current_manifest=""
        local target_manifest=""

        base="$(_release_base_from_archive "$archive")" || return 1
        current="$(_current_release 2>/dev/null || true)"

        _verify_release_set "$archive" || return 1

        if [[ -z "$current" ]]; then
            _release_info "Clean install: $base"
            _extract_release "$archive" || return 1
            _archive_release_set "$archive" || return 1
            _remember_release_channel "$archive" || return 1
            return 0
        fi

        if [[ "$base" == "$current" ]]; then
            _release_info "Reinstalling current release: $base"
            _extract_release "$archive" || return 1
            _archive_release_set "$archive" || return 1
            _remember_release_channel "$archive" || return 1
            return 0
        fi

        if [[ "$(printf '%s\n%s\n' "$current" "$base" | _release_sort | tail -n 1)" == "$base" ]]; then
            removed="$(dirname -- "$archive")/${base}.removed"
            _release_info "Updating $current -> $base"
            _apply_removed_manifest "$removed" || return 1
            _extract_release "$archive" || return 1
            _archive_release_set "$archive" || return 1
            _remember_release_channel "$archive" || return 1
            return 0
        fi

        # A specifically selected older pending release is treated as a rollback target.
        current_manifest="${VAL_ARCHIVE_ROOT%/}/${current}/${current}.manifest"
        target_manifest="$(dirname -- "$archive")/${base}.manifest"
        _release_info "Rolling back $current -> $base"
        _remove_release_difference "$current_manifest" "$target_manifest" || return 1
        _extract_release "$archive" || return 1
        _archive_release_set "$archive" || return 1
        _remember_release_channel "$archive" || return 1
        _move_newer_archives_to_releases "$base" || return 1
    }

    # fn: _rollback_to_archived_release - Make the installed framework match a selected archived release
        # . Purpose
        #   Make the installed framework match a selected archived release.
        # . Returns
        #   0 on success; non-zero when rollback cannot be completed.
        # . Usage
        #   _rollback_to_archived_release "$target_base"
    _rollback_to_archived_release() {
        local target_base="${1:?missing target release}"
        local current=""
        local archive=""
        local current_manifest=""
        local target_manifest=""

        current="$(_current_release 2>/dev/null || true)"
        [[ -n "$current" ]] || { _release_fail "$SGND_RELEASE_PRODUCT is not currently installed"; return 1; }
        [[ "$target_base" != "$current" ]] || { _release_ok "Already running $current"; return 0; }

        archive="$(_find_archived_archive "$target_base")" || {
            _release_fail "Archived release not found: $target_base"
            return 1
        }

        _verify_release_set "$archive" || return 1
        current_manifest="${VAL_ARCHIVE_ROOT%/}/${current}/${current}.manifest"
        target_manifest="$(dirname -- "$archive")/${target_base}.manifest"

        _release_info "Rolling back $current -> $target_base"
        _remove_release_difference "$current_manifest" "$target_manifest" || return 1
        _extract_release "$archive" || return 1
        _move_newer_archives_to_releases "$target_base" || return 1
        _release_ok "Rollback complete: $target_base"
    }

    # fn: _remove_by_manifest - Remove files listed by a selected release manifest
        # . Purpose
        #   Remove exactly the files/symlinks owned by a selected release manifest.
        #   Directories are removed only when empty by _remove_paths_from_stream.
        # . Returns
        #   0 on success; non-zero when the manifest is invalid or removal fails.
        # . Usage
        #   _remove_by_manifest "$manifest"
    _remove_by_manifest() {
        local manifest="${1:?missing manifest}"

        [[ -f "$manifest" ]] || {
            _release_fail "Removal manifest not found: $manifest"
            return 1
        }
        _validate_manifest_paths "$manifest" || return 1

        _release_info "Removing files listed by: $(basename -- "$manifest")"
        _manifest_paths "$manifest" | _remove_paths_from_stream || return 1
        _release_ok "Manifest removal complete: $(basename -- "$manifest")"
    }

    # fn: _file_belongs_to_product - Test a text file for positive SolidGround product ownership
        # . Purpose
        #   Recognize the canonical title header '# <Product> - ...' and an explicit
        #   '# Product : <Product>' metadata line. Binary/non-readable files never match.
        # . Returns
        #   0 when the file positively identifies the requested product; 1 otherwise.
        # . Usage
        #   _file_belongs_to_product "$path" "$SGND_RELEASE_PRODUCT"
    _file_belongs_to_product() {
        local file="${1:?missing file}"
        local product="${2:?missing product}"
        local line=""
        local count=0

        [[ -f "$file" && -r "$file" ]] || return 1
        LC_ALL=C grep -Iq . "$file" 2>/dev/null || return 1

        while IFS= read -r line && (( count < 80 )); do
            count=$(( count + 1 ))
            if [[ "$line" == "# $product -"* || "$line" == "# $product —"* ]]; then
                return 0
            fi
            if [[ "$line" =~ ^#[[:space:]]*Product[[:space:]]*:[[:space:]]*(.*)$ ]] && [[ "${BASH_REMATCH[1]}" == "$product" ]]; then
                return 0
            fi
        done < "$file"
        return 1
    }

    # fn: _scan_product_owned_paths - Emit files beneath managed roots that positively identify a product
        # . Purpose
        #   Recover product ownership without a release manifest by inspecting file headers.
        #   Only files with positive product metadata are emitted; symlinks are not followed.
        # . Returns
        #   0 after scanning the available managed roots.
        # . Usage
        #   _scan_product_owned_paths "$SGND_RELEASE_PRODUCT"
    _scan_product_owned_paths() {
        local product="${1:?missing product}"
        local root="${VAL_TARGET_ROOT%/}"
        local scan_root=""
        local file=""
        local rel=""
        local -a roots=("etc" "usr/local" "var/lib/solidgroundux")

        [[ -n "$root" ]] || root="/"
        for rel in "${roots[@]}"; do
            scan_root="$root/$rel"
            [[ -d "$scan_root" ]] || continue
            while IFS= read -r -d '' file; do
                _file_belongs_to_product "$file" "$product" || continue
                if [[ "$root" == "/" ]]; then
                    printf '%s\n' "${file#/}"
                else
                    printf '%s\n' "${file#${root}/}"
                fi
            done < <(find "$scan_root" -xdev -type f -print0 2>/dev/null)
        done
    }

    # fn: _remove_by_product_scan - Remove files positively identified as belonging to a product
        # . Purpose
        #   Provide a recovery cleanup independent of release manifests by scanning canonical
        #   managed roots for SolidGround metadata headers belonging to the selected product.
        # . Returns
        #   0 on success; non-zero when removal fails.
        # . Usage
        #   _remove_by_product_scan "$SGND_RELEASE_PRODUCT"
    _remove_by_product_scan() {
        local product="${1:?missing product}"
        local matches=""
        local count=0

        matches="$(mktemp)" || return 1
        _scan_product_owned_paths "$product" > "$matches"
        count="$(wc -l < "$matches" | tr -d '[:space:]')"

        if (( count == 0 )); then
            rm -f -- "$matches"
            _release_ok "No header-owned files found for $product"
            return 0
        fi

        _release_info "Found $count header-owned file(s) for $product"
        _remove_paths_from_stream < "$matches"
        local rc=$?
        rm -f -- "$matches"
        (( rc == 0 )) && _release_ok "Product ownership cleanup complete: $product"
        return "$rc"
    }

    # fn: _remove_bundle_products_by_scan - Remove header-owned files for every product in a bundle
        # . Purpose
        #   Apply ownership cleanup to each product recorded in RELEASE-PRODUCTS.
        # . Returns
        #   0 when every product scan succeeds; non-zero on the first failure.
        # . Usage
        #   _remove_bundle_products_by_scan
    _remove_bundle_products_by_scan() {
        local product=""
        local found=0

        while IFS= read -r product; do
            [[ -n "$product" ]] || continue
            found=1
            _remove_by_product_scan "$product" || return 1
        done < <(_bundle_product_names)

        (( found )) || {
            _release_fail "Bundle product metadata is unavailable; no products were scanned"
            return 1
        }
        return 0
    }

# --- GitHub/source acquisition ------------------------------------------------------
    # fn: _download_to - Download or copy a release source to a destination file
        # . Purpose
        #   Download or copy a release source to a destination file.
        # . Returns
        #   0 on success; non-zero on transfer failure.
        # . Usage
        #   _download_to "$source" "$destination"
    _download_to() {
        local source="${1:?missing source}"
        local dest="${2:?missing destination}"

        if [[ "$source" == http://* || "$source" == https://* ]]; then
            if command -v curl >/dev/null 2>&1; then
                curl -fL --retry 2 --connect-timeout 15 -o "$dest" "$source"
                return $?
            fi
            if command -v wget >/dev/null 2>&1; then
                wget -O "$dest" "$source"
                return $?
            fi
            _release_fail "Neither curl nor wget is available for HTTP downloads"
            return 1
        fi

        source="${source#file://}"
        [[ -f "$source" ]] || { _release_fail "Release source not found: $source"; return 1; }
        cp -f -- "$source" "$dest"
    }

    # fn: _github_release_json - Fetch metadata from the configured GitHub Release endpoint
        # . Purpose
        #   Read the configured GitHub Release metadata. The endpoint is persistent while
        #   individual build ZIP assets can be replaced or added underneath it.
        # . Returns
        #   0 and the release JSON on stdout; non-zero when lookup fails.
        # . Usage
        #   json="$(_github_release_json)"
    _github_release_json() {
        local url="${SGND_RELEASE_API_URL:?missing release API URL}"
        local temp_file=""
        local http_code=""
        local curl_rc=0

        # Repository selection is project-aware. An explicit/stateful repository wins;
        # otherwise retain the configured default.
        if [[ -n "${VAL_GITHUB_URL:-}" ]]; then
            local repo=""
            repo="$(_release_repo_from_url "$VAL_GITHUB_URL" 2>/dev/null || true)"
            [[ -n "$repo" ]] || { _release_fail "Invalid GitHub repository URL: $VAL_GITHUB_URL"; return 1; }
            url="https://api.github.com/repos/${repo}/releases/latest"
        elif [[ -n "${VAL_GITHUB_REPO:-}" ]]; then
            url="https://api.github.com/repos/${VAL_GITHUB_REPO}/releases/latest"
        fi

        if command -v curl >/dev/null 2>&1; then
            temp_file="$(mktemp)" || return 1
            http_code="$(curl -sS -L -o "$temp_file" -w '%{http_code}' "$url")" || curl_rc=$?
            if (( curl_rc != 0 )); then
                rm -f -- "$temp_file"
                _release_fail "Could not contact GitHub Release API"
                return 1
            fi
            case "$http_code" in
                200) cat -- "$temp_file"; rm -f -- "$temp_file"; return 0 ;;
                404) rm -f -- "$temp_file"; return 4 ;;
                *)
                    rm -f -- "$temp_file"
                    _release_fail "GitHub Release API returned HTTP $http_code"
                    return 1
                    ;;
            esac
        fi

        if command -v wget >/dev/null 2>&1; then
            # wget cannot portably expose the HTTP status separately. Keep transport/HTTP
            # failures as errors rather than misclassifying them as an empty release channel.
            wget -qO- "$url"
            return $?
        fi

        _release_fail "Neither curl nor wget is available for GitHub checks"
        return 1
    }

    # fn: _github_latest_asset - Resolve the newest build ZIP attached to the configured GitHub Release
        # . Purpose
        #   Inspect Release assets and select the highest
        #   SolidGroundUX-<release-line>.<build>-release.zip by version sorting.
        # . Returns
        #   Prints "<release-base>|<download-url>" and returns 0 when found.
        # . Usage
        #   row="$(_github_latest_asset)"
    _github_latest_asset() {
        local json=""
        local url=""
        local name=""
        local base=""
        local variant="${VAL_VARIANT:-${SGND_RELEASE_VARIANT:-individual}}"
        local artifact_product="$(_release_product_artifact_name "$SGND_RELEASE_PRODUCT")"
        local prefix="${artifact_product}-"
        local suffix="-release.zip"
        local github_rc=0
        local -a rows=()


        json="$(_github_release_json)" || github_rc=$?
        if (( github_rc != 0 )); then
            (( github_rc == 4 )) && return 4
            _release_fail "Could not read configured GitHub Release metadata"
            return 1
        fi

        # browser_download_url is the authoritative artifact identity. Parsing the URL
        # directly avoids depending on GitHub JSON field ordering or pairing an asset's
        # name field with a later URL field.
        while IFS= read -r url; do
            [[ -n "$url" ]] || continue
            name="${url##*/}"
            [[ "${name,,}" == "${prefix,,}"*"${suffix,,}" ]] || continue
            [[ "${name,,}" == "${artifact_product,,}-bundled-"* ]] && continue
            base="${name%$suffix}"
            rows+=("${base}|${url}")
        done < <(
            printf '%s\n' "$json" | sed -n -E                 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p'
        )

        (( ${#rows[@]} > 0 )) || return 4
        printf '%s\n' "${rows[@]}" | LC_ALL=C sort -t '|' -k1,1V | tail -n 1
    }

    # fn: _latest_online_release - Resolve the canonical base name of the newest published build
        # . Purpose
        #   Resolve the highest build asset attached to the configured GitHub Release.
        # . Returns
        #   0 on success; non-zero when GitHub lookup fails.
        # . Usage
        #   _latest_online_release
    _latest_online_release() {
        local row=""
        local asset_rc=0
        row="$(_github_latest_asset)" || asset_rc=$?
        (( asset_rc == 0 )) || return "$asset_rc"
        printf '%s\n' "${row%%|*}"
    }

    # fn: _github_release_asset_url - Resolve the download URL for the newest published build
        # . Purpose
        #   Return the browser download URL selected by _github_latest_asset.
        # . Returns
        #   0 on success; non-zero when GitHub lookup fails.
        # . Usage
        #   url="$(_github_release_asset_url)"
    _github_release_asset_url() {
        local row=""
        local asset_rc=0
        row="$(_github_latest_asset)" || asset_rc=$?
        (( asset_rc == 0 )) || return "$asset_rc"
        printf '%s\n' "${row#*|}"
    }

    # fn: _release_is_local_or_installed - Test whether a release is already downloaded or archived
        # . Purpose
        #   Test whether a release is already downloaded or archived.
        # . Returns
        #   0 when present locally; 1 otherwise.
        # . Usage
        #   _release_is_local_or_installed "$base"
    _release_is_local_or_installed() {
        local base="${1:?missing base}"
        _archived_release_base_exists "$base" && return 0
        _pending_release_base_exists "$base" && return 0
        return 1
    }

    # fn: _admit_extracted_release - Validate an extracted release ZIP and admit its artifacts to releases/
        # . Purpose
        #   Validate an extracted release ZIP and admit its artifacts to releases/.
        # . Returns
        #   0 on success; non-zero when validation or movement fails.
        # . Usage
        #   _admit_extracted_release "$root" "$expected_base"
    _admit_extracted_release() {
        local extracted_root="${1:?missing extraction root}"
        local expected_base="${2:-}"
        local package_info="${extracted_root%/}/release-package.info"
        local package_format=""
        local package_project=""
        local package_product=""
        local package_type="individual"
        local package_release=""
        local archive=""
        local base=""
        local source_dir=""
        local artifact=""
        local -a artifacts=()

        [[ -r "$package_info" ]] || {
            _release_fail "Release ZIP is missing release-package.info"
            return 1
        }

        package_format="$(_package_info_value "$package_info" "SGND_PACKAGE_FORMAT" 2>/dev/null || true)"
        package_project="$(_package_info_value "$package_info" "SGND_PACKAGE_PROJECT" 2>/dev/null || true)"
        package_product="$(_package_info_value "$package_info" "SGND_PACKAGE_PRODUCT" 2>/dev/null || true)"
        package_type="$(_package_info_value "$package_info" "SGND_PACKAGE_TYPE" 2>/dev/null || true)"
        package_release="$(_package_info_value "$package_info" "SGND_PACKAGE_RELEASE" 2>/dev/null || true)"
        [[ -n "$package_type" ]] || package_type="individual"

        [[ "$package_format" == "1" || "$package_format" == "2" || "$package_format" == "3" ]] || {
            _release_fail "Unsupported release package format: ${package_format:-missing}"
            return 1
        }
        [[ "$package_type" == "individual" || "$package_type" == "bundle" || "$package_type" == "product" ]] || {
            _release_fail "Unsupported release package type: $package_type"
            return 1
        }
        _project_slug_safe "$package_project" || {
            _release_fail "Invalid package project slug: $package_project"
            return 1
        }
        [[ -n "$package_product" && -n "$package_release" ]] || {
            _release_fail "Release package identity is incomplete"
            return 1
        }

        _set_project_context "$package_project" || return 1
        SGND_RELEASE_PRODUCT="$package_product"
        VAL_VARIANT="$package_type"
        SGND_RELEASE_VARIANT="$package_type"
        _ensure_manager_directories || return 1
        _persist_project_info "$package_info" || return 1

        archive="${extracted_root%/}/${package_release}.tar.gz"
        [[ -f "$archive" ]] || {
            _release_fail "Release ZIP archive does not match package identity: ${package_release}.tar.gz"
            return 1
        }

        base="$(_release_base_from_archive "$archive")" || return 1
        if [[ "$base" != "$package_release" ]]; then
            _release_fail "Release package identity mismatch: $package_release != $base"
            return 1
        fi
        if [[ -n "$expected_base" && "$base" != "$expected_base" ]]; then
            _release_fail "Downloaded release identity mismatch: expected $expected_base, found $base"
            return 1
        fi

        _verify_release_set "$archive" || return 1
        source_dir="$(dirname -- "$archive")"
        artifacts=(
            "${base}.tar.gz"
            "${base}.tar.gz.sha256"
            "${base}.manifest"
            "${base}.manifest.sha256"
            "${base}.removed"
            "${base}.removed.sha256"
        )

        _release_run mkdir -p -- "$VAL_RELEASES_DIR" || return 1
        for artifact in "${artifacts[@]}"; do
            [[ -f "$source_dir/$artifact" ]] || {
                _release_fail "Release ZIP is missing: $artifact"
                return 1
            }
            _release_run mv -f -- "$source_dir/$artifact" "$VAL_RELEASES_DIR/" || return 1
        done
        _release_run cp -f -- "$package_info" "${VAL_RELEASES_DIR%/}/${base}.package" || return 1
        if [[ "$package_type" == "bundle" ]]; then
            [[ -f "${extracted_root%/}/RELEASE-PRODUCTS" ]] || { _release_fail "Bundled package is missing RELEASE-PRODUCTS"; return 1; }
            _release_run cp -f -- "${extracted_root%/}/RELEASE-PRODUCTS" "${VAL_RELEASES_DIR%/}/${base}.products" || return 1
        fi

        _release_ok "Release admitted for ${SGND_RELEASE_PRODUCT}: $base"
        printf '%s\n' "$base"
    }

    # fn: _acquire_release - Acquire, stage, validate, and admit a release ZIP
        # . Purpose
        #   Acquire, stage, validate, and admit a release ZIP.
        # . Returns
        #   0 on success; non-zero on discovery, transfer, extraction, or validation failure.
        # . Usage
        #   _acquire_release "$expected_base" "$source"
    _acquire_release() {
        local expected_base="${1:-}"
        local source="${2:-}"
        local temp_dir=""
        local zip_path=""
        local base=""

        _require_command unzip || return 1
        _require_command mktemp || return 1

        if [[ -z "$source" ]]; then
            local asset_row=""
            asset_row="$(_github_latest_asset)" || return 1
            base="${asset_row%%|*}"
            source="${asset_row#*|}"
            [[ -n "$expected_base" ]] || expected_base="$base"
        fi

        if [[ -n "$expected_base" ]] && _release_is_local_or_installed "$expected_base"; then
            _release_ok "$expected_base is already installed or available locally"
            printf '%s\n' "$expected_base"
            return 0
        fi

        temp_dir="$(mktemp -d)" || return 1
        zip_path="$temp_dir/release.zip"

        _release_info "Downloading release to temporary staging: $source"
        if (( FLAG_DRYRUN )); then
            printf '[DRYRUN] acquire %q -> %q\n' "$source" "$zip_path"
            rm -rf -- "$temp_dir"
            [[ -n "$expected_base" ]] && printf '%s\n' "$expected_base"
            return 0
        fi

        _download_to "$source" "$zip_path" || { rm -rf -- "$temp_dir"; return 1; }
        unzip -q "$zip_path" -d "$temp_dir/extracted" || {
            _release_fail "Could not extract downloaded release ZIP"
            rm -rf -- "$temp_dir"
            return 1
        }

        base="$(_admit_extracted_release "$temp_dir/extracted" "$expected_base")" || {
            rm -rf -- "$temp_dir"
            return 1
        }

        rm -rf -- "$temp_dir"
        printf '%s\n' "$base"
    }

# --- Product package ZIP workflow ---------------------------------------------------
    # fn: _package_zip_info_value - Read one package metadata value directly from a ZIP
        # Returns:
        #   0 with the requested value on stdout; non-zero when unavailable.
        # Usage:
        #   project="$(_package_zip_info_value "$zip" SGND_PACKAGE_PROJECT)"
    _package_zip_info_value() {
        local zip_file="${1:?missing package ZIP}"
        local key="${2:?missing package metadata key}"
        local value=""
        value="$(unzip -p "$zip_file" release-package.info 2>/dev/null | sed -n -E "s/^${key}=(.*)$/\\1/p" | head -n 1)"
        [[ -n "$value" ]] || return 1
        printf '%s\n' "$value"
    }

    # fn: _package_zip_record - Describe one valid product package ZIP
        # Output:
        #   path|project|product|version|build|release
        # Returns:
        #   0 for a valid product package; 1 otherwise.
        # Usage:
        #   _package_zip_record "/path/product-release.zip"
    _package_zip_record() {
        local zip_file="${1:?missing package ZIP}"
        local format="" type="" project="" product="" version="" build="" release=""
        [[ -f "$zip_file" ]] || return 1
        format="$(_package_zip_info_value "$zip_file" SGND_PACKAGE_FORMAT 2>/dev/null || true)"
        type="$(_package_zip_info_value "$zip_file" SGND_PACKAGE_TYPE 2>/dev/null || true)"
        project="$(_package_zip_info_value "$zip_file" SGND_PACKAGE_PROJECT 2>/dev/null || true)"
        product="$(_package_zip_info_value "$zip_file" SGND_PACKAGE_PRODUCT 2>/dev/null || true)"
        version="$(_package_zip_info_value "$zip_file" SGND_PACKAGE_VERSION 2>/dev/null || true)"
        build="$(_package_zip_info_value "$zip_file" SGND_PACKAGE_BUILD 2>/dev/null || true)"
        release="$(_package_zip_info_value "$zip_file" SGND_PACKAGE_RELEASE 2>/dev/null || true)"
        [[ "$format" == "1" || "$format" == "2" || "$format" == "3" ]] || return 1
        [[ "$type" == "individual" || "$type" == "product" ]] || return 1
        _project_slug_safe "$project" || return 1
        [[ -n "$product" && -n "$version" && -n "$build" && -n "$release" ]] || return 1
        printf '%s|%s|%s|%s|%s|%s\n' "$zip_file" "$project" "$product" "$version" "$build" "$release"
    }

    # fn: _package_store_dir - Return the canonical pending product-package directory
        # Returns:
        #   Canonical global product ZIP store.
        # Usage:
        #   dir="$(_package_store_dir)"
    _package_store_dir() {
        printf '%s/releases\n' "${VAL_STATE_ROOT%/}"
    }

    # fn: _package_archive_dir - Return the canonical installed package archive directory
        # Returns:
        #   Canonical original-ZIP archive root.
        # Usage:
        #   dir="$(_package_archive_dir)"
    _package_archive_dir() {
        printf '%s/releases/archive\n' "${VAL_STATE_ROOT%/}"
    }

    # fn: _scan_product_packages - Scan one directory for valid product release ZIPs
        # Output:
        #   One _package_zip_record per valid package ZIP.
        # Usage:
        #   _scan_product_packages "/var/lib/solidgroundux/releases"
    _scan_product_packages() {
        local directory="${1:?missing package directory}" zip_file=""
        [[ -d "$directory" ]] || return 0
        while IFS= read -r -d '' zip_file; do
            _package_zip_record "$zip_file" 2>/dev/null || true
        done < <(find "$directory" -maxdepth 1 -type f -name '*-release.zip' -print0 2>/dev/null | sort -z)
    }

    # fn: _local_package_catalog - List locally discoverable product packages
        # Purpose:
        #   Always scan beside the running setup script and the canonical system releases
        #   directory; optionally scan one additional directory for Install other.
        # Output:
        #   Unique package records, preferring canonical/system copies over duplicates.
        # Usage:
        #   mapfile -t rows < <(_local_package_catalog "$extra_dir")
    _local_package_catalog() {
        local extra_dir="${1:-}" line="" key="" rest="" project="" release=""
        local -A seen=()
        local directory=""
        local -a dirs=("$SCRIPT_DIR" "$(_package_store_dir)")
        [[ -n "$extra_dir" ]] && dirs+=("$extra_dir")
        for directory in "${dirs[@]}"; do
            [[ -d "$directory" ]] || continue
            while IFS= read -r line; do
                [[ -n "$line" ]] || continue
                key="${line#*|}"; key="${key%|*}" # enough to dedupe identical metadata/path-independent rows
                # Exact release identity is the final field; project + release is authoritative.
                rest="${line#*|}"
                project="${rest%%|*}"
                release="${line##*|}"
                key="${project}|${release}"
                [[ -n "${seen[$key]+x}" ]] && continue
                seen[$key]=1
                printf '%s\n' "$line"
            done < <(_scan_product_packages "$directory")
        done
    }

    # fn: _newest_local_package_for_project - Resolve newest local product ZIP for one project
        # Returns:
        #   0 with package record on stdout; 1 when none exists.
        # Usage:
        #   row="$(_newest_local_package_for_project "$project")"
    _newest_local_package_for_project() {
        local project="${1:?missing project}" line="" row_project="" release=""
        local -a rows=()
        while IFS= read -r line; do
            IFS='|' read -r _ row_project _ _ _ release <<< "$line"
            [[ "$row_project" == "$project" ]] || continue
            rows+=("${release}|${line}")
        done < <(_local_package_catalog)
        (( ${#rows[@]} > 0 )) || return 1
        printf '%s\n' "${rows[@]}" | LC_ALL=C sort -t'|' -k1,1V | tail -n 1 | cut -d'|' -f2-
    }

    # fn: _admit_product_package_zip - Copy one valid product ZIP into canonical releases
        # Returns:
        #   0 with canonical ZIP path on stdout; non-zero on validation/copy failure.
        # Usage:
        #   admitted="$(_admit_product_package_zip "$source_zip")"
    _admit_product_package_zip() {
        local source_zip="${1:?missing package ZIP}" record="" destination_dir="" destination=""
        record="$(_package_zip_record "$source_zip")" || {
            _release_fail "Not a valid SolidGroundUX product package ZIP: $source_zip"
            return 1
        }
        destination_dir="$(_package_store_dir)"
        destination="${destination_dir%/}/$(basename -- "$source_zip")"
        _release_run mkdir -p -- "$destination_dir" || return 1
        if [[ "$(readlink -f "$source_zip")" != "$(readlink -m "$destination")" ]]; then
            _release_run cp -f -- "$source_zip" "$destination" || return 1
        fi
        printf '%s\n' "$destination"
    }

    # fn: _archive_product_package_zip - Archive the original ZIP after successful installation
        # Returns:
        #   0 on success; non-zero on filesystem failure.
        # Usage:
        #   _archive_product_package_zip "$zip" "$project"
    _archive_product_package_zip() {
        local zip_file="${1:?missing package ZIP}" project="${2:?missing project}" archive_dir=""
        archive_dir="$(_package_archive_dir)/$project"
        _release_run mkdir -p -- "$archive_dir" || return 1
        _release_run mv -f -- "$zip_file" "$archive_dir/" || return 1
    }

    # fn: _install_product_package_zip - Install one product ZIP through the canonical tar engine
        # Purpose:
        #   Extract/validate a product ZIP, admit its tar release set, install it using the
        #   existing release engine, then archive the original ZIP only after success.
        # Returns:
        #   0 on success; non-zero on validation/installation failure.
        # Usage:
        #   _install_product_package_zip "$zip"
    _install_product_package_zip() {
        local input_zip="${1:?missing package ZIP}" canonical_zip="" temp_dir="" base="" archive=""
        local project="" product=""
        canonical_zip="$(_admit_product_package_zip "$input_zip")" || return 1
        project="$(_package_zip_info_value "$canonical_zip" SGND_PACKAGE_PROJECT 2>/dev/null || true)"
        product="$(_package_zip_info_value "$canonical_zip" SGND_PACKAGE_PRODUCT 2>/dev/null || true)"
        _set_project_context "$project" || return 1
        SGND_RELEASE_PRODUCT="$product"
        VAL_VARIANT="individual"
        SGND_RELEASE_VARIANT="individual"
        _ensure_manager_directories || return 1

        temp_dir="$(mktemp -d)" || return 1
        if ! unzip -q "$canonical_zip" -d "$temp_dir"; then
            _release_fail "Could not extract product package: $canonical_zip"
            rm -rf -- "$temp_dir"
            return 1
        fi
        base="$(_admit_extracted_release "$temp_dir" "")" || {
            rm -rf -- "$temp_dir"
            return 1
        }
        archive="$(_newest_pending_archive "$base" 2>/dev/null || true)"
        [[ -n "$archive" ]] || {
            _release_fail "Admitted package release was not found: $base"
            rm -rf -- "$temp_dir"
            return 1
        }
        if ! _install_pending_archive "$archive"; then
            rm -rf -- "$temp_dir"
            return 1
        fi
        rm -rf -- "$temp_dir"
        _archive_product_package_zip "$canonical_zip" "$project" || return 1
        _release_ok "Installed product package: $product ($base)"
        return 0
    }

    # fn: _select_package_records - Select one, several, or all package records
        # Arguments:
        #   $1 title; remaining arguments are package records.
        # Output:
        #   Selected records, one per line.
        # Returns:
        #   0 on selection; 1 on cancel/invalid input.
        # Usage:
        #   mapfile -t selected < <(_select_package_records "Local releases" "${rows[@]}")
    _select_package_records() {
        local title="${1:?missing title}"; shift
        local choice="" i=0 record="" zip_file="" project="" product="" version="" build="" release=""
        local -a rows=("$@") indexes=()
        (( ${#rows[@]} > 0 )) || { _release_fail "No product packages available"; return 1; }
        printf '\n%s%s%s\n' "$_RL_BRIGHT_WHITE" "$title" "$_RL_RESET" > /dev/tty
        _release_line "─" > /dev/tty
        for (( i=0; i<${#rows[@]}; i++ )); do
            record="${rows[$i]}"
            IFS='|' read -r zip_file project product version build release <<< "$record"
            printf '  %s%d)%s %s%s%s  %s%s.%s%s\n' "$_RL_UI_PROMPT" "$((i+1))" "$_RL_RESET" "$_RL_UI_TEXT" "$product" "$_RL_RESET" "$_RL_DARK_WHITE" "$version" "$build" "$_RL_RESET" > /dev/tty
        done
        printf '  %sA)%s %sAll%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        printf '  %sQ)%s %sCancel%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        printf '%sSelect product(s): %s' "$_RL_UI_PROMPT" "$_RL_UI_INPUT" > /dev/tty
        read -r choice < /dev/tty
        printf '%s' "$_RL_RESET" > /dev/tty
        case "${choice^^}" in
            Q|"") return 1 ;;
            A) printf '%s\n' "${rows[@]}"; return 0 ;;
        esac
        choice="${choice// /}"
        IFS=',' read -r -a indexes <<< "$choice"
        for choice in "${indexes[@]}"; do
            [[ "$choice" =~ ^[0-9]+$ ]] || return 1
            (( choice >= 1 && choice <= ${#rows[@]} )) || return 1
            printf '%s\n' "${rows[$((choice-1))]}"
        done
    }

    # fn: _product_catalog - List known products without requiring package preselection
        # Output:
        #   project|product|github-url|version|build
        # Usage:
        #   mapfile -t products < <(_product_catalog)
    _product_catalog() {
        local line="" project="" product="" variant="" url="" version="" build="" zip="" release=""
        local -A seen=()
        while IFS= read -r line; do
            IFS='|' read -r project product variant url version build <<< "$line"
            [[ "$variant" == "individual" ]] || continue
            [[ -n "${seen[$project]+x}" ]] && continue
            seen[$project]=1
            printf '%s|%s|%s|%s|%s\n' "$project" "$product" "$url" "$version" "$build"
        done < <(_release_package_catalog)
        while IFS= read -r line; do
            IFS='|' read -r zip project product version build release <<< "$line"
            [[ -n "${seen[$project]+x}" ]] && continue
            seen[$project]=1
            printf '%s|%s||%s|%s\n' "$project" "$product" "$version" "$build"
        done < <(_local_package_catalog)
    }

    # fn: _select_product_records - Select one, several, or all known products
        # Output:
        #   Selected product records.
        # Usage:
        #   mapfile -t selected < <(_select_product_records "Products" "${rows[@]}")
    _select_product_records() {
        local title="${1:?missing title}"; shift
        local choice="" i=0 row="" project="" product="" url="" version="" build=""
        local -a rows=("$@") indexes=()
        (( ${#rows[@]} > 0 )) || return 1
        printf '\n%s%s%s\n' "$_RL_BRIGHT_WHITE" "$title" "$_RL_RESET" > /dev/tty
        _release_line "─" > /dev/tty
        for (( i=0; i<${#rows[@]}; i++ )); do
            IFS='|' read -r project product url version build <<< "${rows[$i]}"
            printf '  %s%d)%s %s%s%s\n' "$_RL_UI_PROMPT" "$((i+1))" "$_RL_RESET" "$_RL_UI_TEXT" "$product" "$_RL_RESET" > /dev/tty
        done
        printf '  %sA)%s %sAll products%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        printf '  %sQ)%s %sCancel%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        printf '%sSelect product(s): %s' "$_RL_UI_PROMPT" "$_RL_UI_INPUT" > /dev/tty
        read -r choice < /dev/tty
        printf '%s' "$_RL_RESET" > /dev/tty
        case "${choice^^}" in Q|"") return 1 ;; A) printf '%s\n' "${rows[@]}"; return 0 ;; esac
        choice="${choice// /}"
        IFS=',' read -r -a indexes <<< "$choice"
        for choice in "${indexes[@]}"; do
            [[ "$choice" =~ ^[0-9]+$ ]] || return 1
            (( choice >= 1 && choice <= ${#rows[@]} )) || return 1
            printf '%s\n' "${rows[$((choice-1))]}"
        done
    }

    # fn: _install_explicit_package_source - Install a directly supplied product ZIP source
        # Returns:
        #   0 on success; non-zero on download/installation failure.
        # Usage:
        #   _install_explicit_package_source "$VAL_SOURCE"
    _install_explicit_package_source() {
        local source="${1:?missing package source}" zip_path=""
        if [[ "$source" == http://* || "$source" == https://* ]]; then
            zip_path="$(_package_store_dir)/${source##*/}"
            _release_run mkdir -p -- "$(_package_store_dir)" || return 1
            _download_to "$source" "$zip_path" || return 1
        else
            source="${source#file://}"
            [[ -f "$source" ]] || { _release_fail "Package source not found: $source"; return 1; }
            zip_path="$source"
        fi
        _install_product_package_zip "$zip_path"
    }

    # fn: _action_install_latest_local_packages - Select/install newest local package per product
        # Usage:
        #   _action_install_latest_local_packages
    _action_install_latest_local_packages() {
        local product_row="" project="" product="" url="" version="" build="" package_row=""
        local -a products=() packages=() selected=()
        [[ -n "${VAL_SOURCE:-}" ]] && { _install_explicit_package_source "$VAL_SOURCE"; return $?; }
        mapfile -t products < <(_product_catalog)
        for product_row in "${products[@]}"; do
            IFS='|' read -r project product url version build <<< "$product_row"
            package_row="$(_newest_local_package_for_project "$project" 2>/dev/null || true)"
            [[ -n "$package_row" ]] && packages+=("$package_row")
        done
        if (( FLAG_AUTO )); then
            project="${VAL_PROJECT:-solidgroundux}"
            package_row="$(_newest_local_package_for_project "$project" 2>/dev/null || true)"
            [[ -n "$package_row" ]] || { _release_fail "No local product package found for project: $project"; return 1; }
            selected=("$package_row")
        else
            mapfile -t selected < <(_select_package_records "Newest local product releases" "${packages[@]}") || return 1
        fi
        for package_row in "${selected[@]}"; do
            _install_product_package_zip "${package_row%%|*}" || return 1
        done
    }

    # fn: _action_install_other_packages - Select/install product ZIPs from another directory
        # Usage:
        #   _action_install_other_packages
    _action_install_other_packages() {
        local directory="" row=""
        local -a packages=() selected=()
        _release_ask "Package directory" directory "$SCRIPT_DIR" || return 1
        [[ -d "$directory" ]] || { _release_fail "Package directory not found: $directory"; return 1; }
        mapfile -t packages < <(_scan_product_packages "$directory")
        mapfile -t selected < <(_select_package_records "Available product packages" "${packages[@]}") || return 1
        for row in "${selected[@]}"; do
            _install_product_package_zip "${row%%|*}" || return 1
        done
    }

    # fn: _action_install_latest_github_products - Select products, download/install newest GitHub ZIPs
        # Usage:
        #   _action_install_latest_github_products
    _action_install_latest_github_products() {
        local row="" project="" product="" url="" version="" build="" repo="" asset="" source="" zip_path=""
        local -a products=() selected=()
        [[ -n "${VAL_SOURCE:-}" ]] && { _install_explicit_package_source "$VAL_SOURCE"; return $?; }
        mapfile -t products < <(_product_catalog)
        if (( FLAG_AUTO )); then
            project="${VAL_PROJECT:-solidgroundux}"
            for row in "${products[@]}"; do
                [[ "${row%%|*}" == "$project" ]] && { selected=("$row"); break; }
            done
            (( ${#selected[@]} == 1 )) || { _release_fail "Unknown product project: $project"; return 1; }
        else
            mapfile -t selected < <(_select_product_records "Install latest GitHub release" "${products[@]}") || return 1
        fi
        for row in "${selected[@]}"; do
            IFS='|' read -r project product url version build <<< "$row"
            _set_project_context "$project" || return 1
            SGND_RELEASE_PRODUCT="$product"
            VAL_VARIANT="individual"; SGND_RELEASE_VARIANT="individual"
            VAL_GITHUB_URL=""; VAL_GITHUB_REPO=""
            _release_load_project_repo "$project" || true
            if [[ -z "$VAL_GITHUB_URL" && -n "$url" ]]; then
                VAL_GITHUB_URL="$(_release_normalize_github_url "$url" 2>/dev/null || true)"
                repo="$(_release_repo_from_url "$VAL_GITHUB_URL" 2>/dev/null || true)"
                [[ -n "$repo" ]] && VAL_GITHUB_REPO="$repo"
            fi
            if [[ -z "$VAL_GITHUB_REPO" ]]; then
                _release_ask "GitHub repository URL for $product" VAL_GITHUB_URL "${VAL_GITHUB_URL:-}" || return 1
                VAL_GITHUB_URL="$(_release_normalize_github_url "$VAL_GITHUB_URL" 2>/dev/null || true)"
                repo="$(_release_repo_from_url "$VAL_GITHUB_URL" 2>/dev/null || true)"
                [[ -n "$repo" ]] || { _release_fail "Invalid GitHub repository URL: $VAL_GITHUB_URL"; return 1; }
                VAL_GITHUB_REPO="$repo"
                _release_save_project_repo || return 1
            fi
            asset="$(_github_latest_asset)" || { _release_fail "No GitHub release found for $product"; return 1; }
            source="${asset#*|}"
            zip_path="$(_package_store_dir)/${source##*/}"
            _release_run mkdir -p -- "$(_package_store_dir)" || return 1
            if [[ ! -f "$zip_path" ]]; then
                _release_info "Downloading $product: ${source##*/}"
                _download_to "$source" "$zip_path" || return 1
            fi
            _install_product_package_zip "$zip_path" || return 1
        done
    }

    # fn: _release_display_identity - Reduce a release basename to Version.Build for display
        # Arguments:
        #   $1  Product display name.
        #   $2  Full release basename.
        # Returns:
        #   0 with a compact display identity on stdout.
        # Usage:
        #   display="$(_release_display_identity "$product" "$release")"
    _release_display_identity() {
        local product="${1:-}"
        local release="${2:-}"
        local artifact=""

        [[ -n "$release" ]] || { printf '%s\n' '-'; return 0; }
        artifact="$(_release_product_artifact_name "$product")"
        release="${release#${artifact}-bundled-}"
        release="${release#${artifact}-}"
        printf '%s\n' "$release"
    }

    # fn: _dashboard_product_rows - Render product-centric installed/local/GitHub status
        # Usage:
        #   _dashboard_product_rows
    _dashboard_product_rows() {
        local row="" project="" product="" url="" version="" build=""
        local installed="" installed_display="" local_row="" local_release="" local_display=""
        local github="" github_display="" repo="" status="" line_color=""
        local -a products=()
        mapfile -t products < <(_product_catalog)
        printf '%s%-44s %-16s %-16s %-16s%s\n' "$_RL_BRIGHT_WHITE" "Product" "Installed" "Local" "GitHub" "$_RL_RESET"
        _release_line "─"
        for row in "${products[@]}"; do
            IFS='|' read -r project product url version build <<< "$row"
            _set_project_context "$project" >/dev/null 2>&1 || continue
            SGND_RELEASE_PRODUCT="$product"
            installed="$(_current_release 2>/dev/null || true)"
            installed_display="$(_release_display_identity "$product" "$installed")"
            local_row="$(_newest_local_package_for_project "$project" 2>/dev/null || true)"
            local_release="${local_row##*|}"
            if [[ -n "$local_row" ]]; then
                local_display="$(_release_display_identity "$product" "$local_release")"
            else
                local_release=""
                local_display="-"
            fi
            github="Not checked"
            VAL_GITHUB_URL=""; VAL_GITHUB_REPO=""
            _release_load_project_repo "$project" || true
            if [[ -z "$VAL_GITHUB_URL" && -n "$url" ]]; then
                VAL_GITHUB_URL="$(_release_normalize_github_url "$url" 2>/dev/null || true)"
                repo="$(_release_repo_from_url "$VAL_GITHUB_URL" 2>/dev/null || true)"
                [[ -n "$repo" ]] && VAL_GITHUB_REPO="$repo"
            fi
            if [[ -n "$VAL_GITHUB_REPO" ]]; then
                github="$(_latest_online_release 2>/dev/null || printf '%s' 'Unavailable')"
            else
                github="Not configured"
            fi
            case "$github" in
                Unavailable|"Not configured"|"Not checked") github_display="$github" ;;
                *) github_display="$(_release_display_identity "$product" "$github")" ;;
            esac
            status=0
            if [[ -n "$local_release" && ( -z "$installed" || "$(printf '%s\n%s\n' "$installed" "$local_release" | _release_sort | tail -n 1)" == "$local_release" && "$installed" != "$local_release" ) ]]; then status=1; fi
            if [[ "$github" != "Unavailable" && "$github" != "Not configured" && "$github" != "Not checked" && -n "$github" && ( -z "$installed" || "$(printf '%s\n%s\n' "$installed" "$github" | _release_sort | tail -n 1)" == "$github" && "$installed" != "$github" ) ]]; then status=1; fi
            if (( status )); then line_color="${_RL_BOLD}${_RL_BRIGHT_GREEN}"; else line_color="$_RL_UI_TEXT"; fi
            printf '%s%-44.44s %-16.16s %-16.16s %-16.16s%s\n' "$line_color" "$product" "$installed_display" "$local_display" "$github_display" "$_RL_RESET"
        done
    }

    # fn: _bootstrap_first_install_packages - First install from adjacent product ZIPs
        # Purpose:
        #   Install setup itself, admit adjacent product ZIPs, let the operator select one or
        #   more products, then install them through the normal product-package pipeline.
        # Returns:
        #   0 when no adjacent product packages exist or installation succeeds; non-zero otherwise.
        # Usage:
        #   _bootstrap_first_install_packages
    _bootstrap_first_install_packages() {
        local row="" canonical=""
        local -a packages=() selected=()
        mapfile -t packages < <(_scan_product_packages "$SCRIPT_DIR")
        (( ${#packages[@]} > 0 )) || return 0
        _release_info "First-install product packages found beside setup: ${#packages[@]}"
        _install_setup_self || return 1
        for row in "${packages[@]}"; do
            canonical="$(_admit_product_package_zip "${row%%|*}")" || return 1
        done
        if (( FLAG_AUTO )); then
            selected=("${packages[@]}")
        else
            mapfile -t selected < <(_select_package_records "First install - select products" "${packages[@]}") || return 1
        fi
        for row in "${selected[@]}"; do
            _install_product_package_zip "${row%%|*}" || return 1
        done
        BOOTSTRAP_RELEASE_BASE="packages"
        BOOTSTRAP_SOURCE_DIR="$SCRIPT_DIR"
        _cleanup_bootstrap_files || return 1
        _release_choose_post_install_action || return 1
        return 0
    }

# --- Interactive helpers ------------------------------------------------------------
    # fn: _confirm - Request a standalone yes/no confirmation
        # . Purpose
        #   Request a standalone yes/no confirmation.
        # . Returns
        #   0 for confirmation; 1 for rejection or unavailable interaction.
        # . Usage
        #   _confirm "Continue?"
    _confirm() {
        local prompt="${1:-Continue?}"

        (( FLAG_AUTO )) && return 0
        [[ -t 0 && -t 1 ]] || {
            _release_fail "Confirmation required; use --auto for non-interactive operation"
            return 1
        }

        _release_ask_yesno "$prompt" "Y"
    }


    # fn: _bundle_products_file - Locate product metadata for the selected bundle
        # . Purpose
        #   Locate RELEASE-PRODUCTS metadata retained beside the installed or pending bundle.
        # . Returns
        #   0 and the metadata path when found; 1 otherwise.
        # . Usage
        #   products_file="$(_bundle_products_file)"
    _bundle_products_file() {
        local base=""
        local archive=""
        local products=""

        base="$(_current_release 2>/dev/null || true)"
        if [[ -n "$base" ]]; then
            products="${VAL_ARCHIVE_ROOT%/}/${base}/${base}.products"
            [[ -r "$products" ]] && { printf '%s\n' "$products"; return 0; }
        fi

        archive="$(_newest_pending_archive 2>/dev/null || true)"
        if [[ -n "$archive" ]]; then
            base="$(_release_base_from_archive "$archive" 2>/dev/null || true)"
            products="$(dirname -- "$archive")/${base}.products"
            [[ -r "$products" ]] && { printf '%s\n' "$products"; return 0; }
        fi
        return 1
    }

    # fn: _bundle_product_names - Emit product names recorded in bundle metadata
        # . Purpose
        #   Read the first field of RELEASE-PRODUCTS records without hard-coding products.
        # . Returns
        #   0 when bundle metadata is available; 1 otherwise.
        # . Usage
        #   mapfile -t products < <(_bundle_product_names)
    _bundle_product_names() {
        local products_file=""
        local line=""
        local product=""

        products_file="$(_bundle_products_file)" || return 1
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -n "${line//[[:space:]]/}" ]] || continue
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            IFS='|' read -r product _ <<< "$line"
            [[ -n "$product" ]] && printf '%s\n' "$product"
        done < "$products_file"
    }

    # fn: _select_bundle_removal_scope - Select one constituent product or the complete bundle
        # . Purpose
        #   Present products from RELEASE-PRODUCTS dynamically so future bundle members require
        #   no release-manager code changes. ALL represents the complete bundle/all products.
        # . Returns
        #   0 with product name or ALL on stdout; 1 when returning/cancelling.
        # . Usage
        #   scope="$(_select_bundle_removal_scope "Removal scope")"
    _select_bundle_removal_scope() {
        local title="${1:-Removal scope}"
        local choice=""
        local i=0
        local -a products=()

        mapfile -t products < <(_bundle_product_names)
        (( ${#products[@]} > 0 )) || {
            _release_fail "Bundle product metadata is unavailable; cannot determine removal scope"
            return 1
        }

        printf '\n%s%s%s\n' "$_RL_BRIGHT_WHITE" "$title" "$_RL_RESET" > /dev/tty
        _release_line "─" > /dev/tty
        printf '\n' > /dev/tty
        for i in "${!products[@]}"; do
            printf '  %s%d)%s %s%s%s\n' "$_RL_UI_PROMPT" "$(( i + 1 ))" "$_RL_RESET" "$_RL_DARK_WHITE" "${products[$i]}" "$_RL_RESET" > /dev/tty
        done
        printf '  %s%d)%s %sAll products in bundle%s\n' "$_RL_UI_PROMPT" "$(( ${#products[@]} + 1 ))" "$_RL_RESET" "$_RL_MSG_FAIL" "$_RL_RESET" > /dev/tty
        printf '  %sQ)%s %sReturn%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        printf '\n' > /dev/tty
        _release_line "─" > /dev/tty
        printf '%sSelect product: %s' "$_RL_UI_PROMPT" "$_RL_UI_INPUT" > /dev/tty
        read -r choice < /dev/tty
        printf '%s' "$_RL_RESET" > /dev/tty

        case "${choice^^}" in Q|"") return 1 ;; esac
        [[ "$choice" =~ ^[0-9]+$ ]] || return 1
        if (( choice == ${#products[@]} + 1 )); then
            printf '%s\n' 'ALL'
            return 0
        fi
        (( choice >= 1 && choice <= ${#products[@]} )) || return 1
        printf '%s\n' "${products[$(( choice - 1 ))]}"
    }

    # fn: _list_product_manifests - List archived manifests for a product and release variant
        # . Purpose
        #   Find manifests by exact product artifact identity without prefix collisions.
        # . Returns
        #   0 after emitting matching manifest paths in version order.
        # . Usage
        #   _list_product_manifests "$product" individual
    _list_product_manifests() {
        local product="${1:?missing product}"
        local variant="${2:-individual}"
        local artifact_product=""
        local dir=""
        local base=""
        local remainder=""
        local manifest=""
        local -a rows=()

        artifact_product="$(_release_product_artifact_name "$product")"
        [[ -d "$VAL_ARCHIVE_ROOT" ]] || return 0
        while IFS= read -r dir; do
            base="$(basename -- "$dir")"
            if [[ "$variant" == "bundle" ]]; then
                [[ "$base" == "${artifact_product}-bundled-"* ]] || continue
                remainder="${base#${artifact_product}-bundled-}"
            else
                [[ "$base" == "${artifact_product}-"* && "$base" != "${artifact_product}-bundled-"* ]] || continue
                remainder="${base#${artifact_product}-}"
            fi
            # Release identities begin with the numeric version. This rejects longer product
            # names that merely share the requested product's filename prefix.
            [[ "$remainder" =~ ^[0-9] ]] || continue
            manifest="${dir%/}/${base}.manifest"
            [[ -f "$manifest" ]] && rows+=("$base|$manifest")
        done < <(find "$VAL_ARCHIVE_ROOT" -mindepth 1 -maxdepth 1 -type d -name "${artifact_product}-*" -print 2>/dev/null)

        (( ${#rows[@]} > 0 )) || return 0
        printf '%s\n' "${rows[@]}" | LC_ALL=C sort -t'|' -k1,1V | cut -d'|' -f2-
    }

    # fn: _select_removal_manifest_for - Select an archived manifest for a product/variant
        # . Purpose
        #   Present matching archived manifests from new to old.
        # . Returns
        #   0 with the selected manifest path on stdout; 1 when returning/cancelling.
        # . Usage
        #   manifest="$(_select_removal_manifest_for "$product" individual)"
    _select_removal_manifest_for() {
        local product="${1:?missing product}"
        local variant="${2:-individual}"
        local manifest=""
        local choice=""
        local i=0
        local -a manifests=()

        mapfile -t manifests < <(_list_product_manifests "$product" "$variant")
        (( ${#manifests[@]} > 0 )) || {
            _release_fail "No archived ${variant} manifests found for $product"
            return 1
        }

        printf '\n%sRemoval manifests: %s%s\n' "$_RL_BRIGHT_WHITE" "$product" "$_RL_RESET" > /dev/tty
        _release_line "─" > /dev/tty
        printf "${_RL_ITALIC}  Manifests listed from new to old. Only the selected manifest is used.\n${_RL_RESET}" > /dev/tty
        printf '\n' > /dev/tty
        for (( i=${#manifests[@]}-1; i>=0; i-- )); do
            manifest="${manifests[$i]}"
            printf '  %s%d)%s %s%s%s\n' "$_RL_UI_PROMPT" "$(( ${#manifests[@]} - i ))" "$_RL_RESET" "$_RL_DARK_WHITE" "$(basename -- "$manifest")" "$_RL_RESET" > /dev/tty
        done
        printf '  %sQ)%s %sReturn%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        printf '\n' > /dev/tty
        _release_line "─" > /dev/tty
        printf '%sSelect manifest: %s' "$_RL_UI_PROMPT" "$_RL_UI_INPUT" > /dev/tty
        read -r choice < /dev/tty
        printf '%s' "$_RL_RESET" > /dev/tty

        case "${choice^^}" in Q|"") return 1 ;; esac
        [[ "$choice" =~ ^[0-9]+$ ]] || return 1
        (( choice >= 1 && choice <= ${#manifests[@]} )) || return 1
        i=$(( ${#manifests[@]} - choice ))
        printf '%s\n' "${manifests[$i]}"
    }

    # fn: _select_removal_manifest - Select an archived manifest for the active package
        # . Purpose
        #   Preserve the individual-package path while delegating to the generic selector.
        # . Returns
        #   0 with the selected manifest path on stdout; 1 when returning/cancelling.
        # . Usage
        #   manifest="$(_select_removal_manifest)"
    _select_removal_manifest() {
        _select_removal_manifest_for "$SGND_RELEASE_PRODUCT" "${VAL_VARIANT:-${SGND_RELEASE_VARIANT:-individual}}"
    }

    # fn: _select_archived_release - Select an archived release from a submenu
        # . Purpose
        #   Select an archived release or the remove operation from a submenu.
        # . Returns
        #   0 with the selected target on stdout; 1 when returning/cancelling.
        # . Usage
        #   target="$(_select_archived_release)"
    _select_archived_release() {
        local current=""
        local base=""
        local choice=""
        local i=0
        local -a releases=()

        current="$(_current_release 2>/dev/null || true)"
        mapfile -t releases < <(_list_archived_releases)
        (( ${#releases[@]} > 0 )) || { _release_fail "No archived releases found"; return 1; }

        printf '\n%sArchived releases%s\n' "$_RL_BRIGHT_WHITE" "$_RL_RESET" > /dev/tty
        
        _release_line "─" > /dev/tty
        printf "${_RL_ITALIC}  Versions listed from new to old. Buildnr concatenates year,day-of-year,hour\n${_RL_RESET}" > /dev/tty
        printf "${_RL_ITALIC}  Selected version will be installed over the current one.\n${_RL_RESET}" > /dev/tty
        printf "\n" > /dev/tty
        for (( i=${#releases[@]}-1; i>=0; i-- )); do
            base="${releases[$i]}"
            if [[ "$base" == "$current" ]]; then
                printf '  %s%d)%s %s%s%s %s(current)%s\n' "$_RL_UI_PROMPT" "$(( ${#releases[@]} - i ))" "$_RL_RESET" "$_RL_BRIGHT_WHITE" "$base" "$_RL_RESET" "$_RL_BRIGHT_WHITE" "$_RL_RESET" > /dev/tty
            else
                printf '  %s%d)%s %s%s%s\n' "$_RL_UI_PROMPT" "$(( ${#releases[@]} - i ))" "$_RL_RESET" "$_RL_DARK_WHITE" "$base" "$_RL_RESET" > /dev/tty
            fi
        done
        printf '  %sQ)%s %sReturn%s\n' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET" > /dev/tty
        printf '\n' > /dev/tty
        _release_line "─" > /dev/tty
        printf '%sSelect target: %s' "$_RL_UI_PROMPT" "$_RL_UI_INPUT" > /dev/tty

        read -r choice < /dev/tty
        printf '%s' "$_RL_RESET" > /dev/tty
        case "${choice^^}" in
            Q|"") return 1 ;;
        esac

        [[ "$choice" =~ ^[0-9]+$ ]] || return 1
        (( choice >= 1 && choice <= ${#releases[@]} )) || return 1
        i=$(( ${#releases[@]} - choice ))
        printf '%s\n' "${releases[$i]}"
    }

    # fn: _print_status - Display the product setup dashboard
        # Purpose:
        #   Show installed, newest local, and newest GitHub releases for every known product.
        # Usage:
        #   _print_status
    _print_status() {
        _dashboard_product_rows
        printf '
'
        _release_labeled_value "Package directory" "$(_package_store_dir)"
        _release_labeled_value "Package archive" "$(_package_archive_dir)"
    }

    # fn: _interactive_menu - Run the standalone product setup menu
        # Returns:
        #   0 on normal exit.
        # Usage:
        #   _interactive_menu
    _interactive_menu() {
        local choice="" target="" product_row="" project="" product="" url="" version="" build=""
        local -a products=() selected=()
        while true; do
            _release_clear
            _release_title
            _print_status
            _release_line "─"
            printf '
'
            printf '    %s1)%s %sInstall latest GitHub release%s
' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET"
            printf '    %s2)%s %sInstall newest local release%s
' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET"
            printf '    %s3)%s %sInstall other release%s
' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET"
            printf '    %s4)%s %sInstall archived version%s
' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET"
            printf '    %s5)%s %sRemove using manifest%s
' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET"
            printf '    %s6)%s %sRemove product by ownership scan%s
' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET"
            printf '    %sQ)%s %sQuit%s

' "$_RL_UI_PROMPT" "$_RL_RESET" "$_RL_UI_TEXT" "$_RL_RESET"
            _release_line "─"
            printf '%sSelect option: %s' "$_RL_UI_PROMPT" "$_RL_UI_INPUT" > /dev/tty
            read -r choice < /dev/tty
            printf '%s' "$_RL_RESET" > /dev/tty
            case "${choice^^}" in
                1) _action_install_latest_github_products; _pause ;;
                2) _action_install_latest_local_packages; _pause ;;
                3) _action_install_other_packages; _pause ;;
                4)
                    mapfile -t products < <(_product_catalog)
                    mapfile -t selected < <(_select_product_records "Select product" "${products[@]}") || continue
                    (( ${#selected[@]} == 1 )) || { _release_warn "Archived installation currently accepts one product at a time"; _pause; continue; }
                    IFS='|' read -r project product url version build <<< "${selected[0]}"
                    _set_project_context "$project" || { _pause; continue; }
                    SGND_RELEASE_PRODUCT="$product"
                    target="$(_select_archived_release 2>/dev/tty)" || continue
                    _confirm "Install $target?" && _rollback_to_archived_release "$target"
                    _pause
                    ;;
                5)
                    mapfile -t products < <(_product_catalog)
                    mapfile -t selected < <(_select_product_records "Select product" "${products[@]}") || continue
                    (( ${#selected[@]} == 1 )) || { _release_warn "Removal currently accepts one product at a time"; _pause; continue; }
                    IFS='|' read -r project product url version build <<< "${selected[0]}"
                    _set_project_context "$project" || { _pause; continue; }
                    SGND_RELEASE_PRODUCT="$product"
                    target="$(_select_removal_manifest_for "$product" individual 2>/dev/tty)" || continue
                    _confirm "Remove files listed by $(basename -- "$target")?" && _remove_by_manifest "$target"
                    _pause
                    ;;
                6)
                    mapfile -t products < <(_product_catalog)
                    mapfile -t selected < <(_select_product_records "Select product" "${products[@]}") || continue
                    (( ${#selected[@]} == 1 )) || { _release_warn "Ownership removal currently accepts one product at a time"; _pause; continue; }
                    IFS='|' read -r project product url version build <<< "${selected[0]}"
                    _set_project_context "$project" || { _pause; continue; }
                    SGND_RELEASE_PRODUCT="$product"
                    _confirm "Scan managed trees and remove files whose headers identify $product?" && _remove_by_product_scan "$product"
                    _pause
                    ;;
                Q) return 0 ;;
            esac
        done
    }

    # fn: _pause - Wait for Enter after an interactive operation
        # . Purpose
        #   Wait for Enter after an interactive operation.
        # . Returns
        #   0 always.
        # . Usage
        #   _pause
    _pause() {
        [[ -t 0 && -t 1 ]] || return 0
        printf '\n%sPress Enter to continue...%s' "$_RL_UI_PROMPT" "$_RL_UI_INPUT" > /dev/tty
        read -r _ < /dev/tty
        printf '%s' "$_RL_RESET" > /dev/tty
    }

# --- Action dispatch ----------------------------------------------------------------
    # fn: _action_check - Report the latest published build and its local state
        # . Purpose
        #   Report the latest GitHub release and its local state.
        # . Returns
        #   0 on success; non-zero when online discovery fails.
        # . Usage
        #   _action_check
    _action_check() {
        local latest=""
        local current=""
        local local_state="Not downloaded"

        local check_rc=0
        latest="$(_latest_online_release)" || check_rc=$?
        if (( check_rc != 0 )); then
            if (( check_rc == 4 )); then
                printf '\n'
                _release_labeled_value "GitHub check" "No published release is currently available for $SGND_RELEASE_PRODUCT."
                return 0
            fi
            return 1
        fi
        # The selected product owns its version/build identity. GitHub discovery must
        # therefore be able to find a newer product version than the locally configured
        # one (for example local 1.1 with a published 1.2 package). Learn both values
        # from the selected asset after discovery succeeds.
        local artifact_product=""
        local published_identity=""
        artifact_product="$(_release_product_artifact_name "$SGND_RELEASE_PRODUCT")"
        published_identity="${latest#${artifact_product}-}"
        [[ "$published_identity" == bundled-* ]] && published_identity="${published_identity#bundled-}"
        SGND_RELEASE_BUILD="${published_identity##*.}"
        SGND_RELEASE_LINE="${published_identity%.*}"
        current="$(_current_release 2>/dev/null || true)"

        if _archived_release_base_exists "$latest"; then
            local_state="Installed"
        elif _pending_release_base_exists "$latest"; then
            local_state="Downloaded"
        fi

        printf '\n'
        _release_labeled_value "Latest published build" "$latest"
        _release_labeled_value "Installed release" "${current:-Not installed}"
        _release_labeled_value "Latest build state" "$local_state"

        if [[ "$local_state" == "Installed" ]]; then
            _release_ok "Already current"
        elif [[ -n "$current" && "$(printf '%s\n%s\n' "$current" "$latest" | _release_sort | tail -n 1)" == "$current" ]]; then
            _release_ok "Installed release is current or newer"
        else
            _release_warn "Update available: $latest"
        fi
    }

    # fn: _action_download - Acquire the latest build or explicitly sourced release without installing it
        # . Purpose
        #   Acquire the latest or explicitly sourced release without installing it.
        # . Returns
        #   0 on success; non-zero on acquisition failure.
        # . Usage
        #   _action_download
    _action_download() {
        local latest=""

        if [[ -n "$VAL_SOURCE" ]]; then
            _acquire_release "" "$VAL_SOURCE" >/dev/null
            return $?
        fi

        latest="$(_latest_online_release)" || return 1
        _acquire_release "$latest" "" >/dev/null
    }

    # fn: _action_update - Acquire if needed and install the selected update source
        # . Purpose
        #   In interactive mode, select the configured GitHub source or a package ZIP/URL,
        #   then acquire if needed and install the latest applicable release.
        # . Returns
        #   0 on success; 2 on cancellation; non-zero on failure.
        # . Usage
        #   _action_update
    _action_update() {
        local latest=""
        local current=""
        local archive=""
        local update_source=""

        if (( ! FLAG_AUTO )) && [[ -t 0 && -t 1 ]]; then
            update_source="${VAL_SOURCE:-G}"
            _release_ask \
                "Update source (G = configured GitHub, or package ZIP/URL)" \
                update_source \
                "$update_source" || return 1

            case "${update_source^^}" in
                G|GITHUB) VAL_SOURCE="" ;;
                *) VAL_SOURCE="$update_source" ;;
            esac
        fi

        current="$(_current_release 2>/dev/null || true)"

        if [[ -n "$VAL_SOURCE" ]]; then
            _acquire_release "" "$VAL_SOURCE" >/dev/null || return 1
            current="$(_current_release 2>/dev/null || true)"
            archive="$(_newest_pending_archive)" || {
                _release_fail "No pending release was found after acquisition"
                return 1
            }
            latest="$(_release_base_from_archive "$archive")"
        else
            latest="$(_latest_online_release)" || return 1

            if _archived_release_base_exists "$latest"; then
                _release_ok "Latest published build is already installed: $latest"
                return 0
            fi

            if [[ -n "$current" && "$(printf '%s\n%s\n' "$current" "$latest" | _release_sort | tail -n 1)" == "$current" ]]; then
                _release_ok "Installed release is current or newer: $current"
                return 0
            fi

            if ! _pending_release_base_exists "$latest"; then
                _acquire_release "$latest" "" >/dev/null || return 1
            fi

            archive="$(_newest_pending_archive "$latest")" || {
                _release_fail "Latest build was not found after acquisition: $latest"
                return 1
            }
        fi

        if [[ -n "$current" && "$(printf '%s\n%s\n' "$current" "$latest" | _release_sort | tail -n 1)" == "$current" && "$current" != "$latest" ]]; then
            _release_ok "Installed release is current or newer: $current"
            return 0
        fi

        _confirm "Install $latest?" || return 2
        _install_pending_archive "$archive"
    }

    # fn: _action_install - Install the newest matching pending local release
        # . Purpose
        #   Install the newest matching pending local release.
        # . Returns
        #   0 on success; 2 on cancellation; non-zero on failure.
        # . Usage
        #   _action_install
    _action_install() {
        local archive=""

        archive="$(_newest_pending_archive "$VAL_RELEASE" 2>/dev/null || true)"

        if [[ -z "$archive" && -z "$VAL_SOURCE" ]] && (( ! FLAG_AUTO )); then
            _release_ask "Package ZIP or URL" VAL_SOURCE "${VAL_SOURCE:-}" || return 1
        fi

        if [[ -n "$VAL_SOURCE" ]]; then
            _acquire_release "" "$VAL_SOURCE" >/dev/null || return 1
            _release_save_state || true
        fi

        archive="$(_newest_pending_archive "$VAL_RELEASE" 2>/dev/null || true)"
        [[ -n "$archive" ]] || {
            _release_fail "No matching pending release found for project: $SGND_RELEASE_PROJECT"
            return 1
        }

        _confirm "Install $(_release_base_from_archive "$archive")?" || return 2
        _install_pending_archive "$archive"
    }

    # fn: _action_rollback - Install the previous or explicitly selected archived release
        # . Purpose
        #   Install the previous or explicitly selected archived release.
        # . Returns
        #   0 on success; 2 on cancellation; non-zero on failure.
        # . Usage
        #   _action_rollback
    _action_rollback() {
        local target="$VAL_RELEASE"
        local previous=""

        if [[ -z "$target" ]]; then
            previous="$(_previous_release 2>/dev/null || true)"
            [[ -n "$previous" ]] || {
                _release_fail "No previous archived release is available"
                return 1
            }
            target="$previous"
        fi

        _confirm "Install archived release $target?" || return 2
        _rollback_to_archived_release "$target"
    }

    # fn: _action_remove - Remove the active SolidGroundUX installation after confirmation
        # . Purpose
        #   Remove the active SolidGroundUX installation after confirmation.
        # . Returns
        #   0 on success; 2 on cancellation; non-zero on failure.
        # . Usage
        #   _action_remove
    _action_remove() {
        local current=""
        local manifest=""

        current="$(_current_release 2>/dev/null || true)"
        [[ -n "$current" ]] || {
            _release_ok "$SGND_RELEASE_PRODUCT is not installed"
            return 0
        }
        manifest="${VAL_ARCHIVE_ROOT%/}/${current}/${current}.manifest"
        _confirm "Remove $SGND_RELEASE_PRODUCT using $(basename -- "$manifest")?" || return 2
        _remove_by_manifest "$manifest" || return 1
        _move_all_archives_to_releases || return 1
        _release_ok "$SGND_RELEASE_PRODUCT removed; archived releases returned to the releases directory"
    }

# --- Main ----------------------------------------------------------------------------
    # fn: main - Run standalone sgnd-setup initialization and dispatch
        # . Purpose
        #   Run standalone sgnd-setup initialization and dispatch.
        # . Returns
        #   Exit status of the selected interactive or command-line action.
        # . Usage
        #   main "$@"
    main() {
        local default_root=""
        local rc=0

        # Establish the bootstrap/default UI first; it is always available.
        RELEASE_UI_MODE="standalone"

        default_root="$(_release_default_target_root)"
        VAL_TARGET_ROOT="$default_root"

        parse_args "$@" || return $?
        _ensure_root

        clear

        # Resolve the first state location from the explicit/default target root,
        # then load stored defaults without overriding explicit CLI values.
        init_paths || return $?
        _release_load_state
        init_paths || return $?

        # If the stored/explicit target already contains SolidGroundUX, use its UI
        # for the settings/menu. Otherwise the design-time default fallback remains.
        _release_try_framework_ui

        _load_release_manager_config

        # In interactive mode parameters are questions; in --auto mode state/CLI/defaults win.
        _release_prompt_settings || return $?
        # Rebase project state paths without discarding the product identity selected by
        # the package catalog. _set_project_context normally loads persisted identity.
        local selected_product="${SGND_RELEASE_PRODUCT:-}"
        _set_project_context "${VAL_PROJECT:-solidgroundux}" || return 1
        [[ -n "$selected_product" ]] && SGND_RELEASE_PRODUCT="$selected_product"

        _require_command find || return 1
        _require_command sort || return 1
        _require_command tar || return 1
        _require_command sha256sum || return 1
        _require_command awk || return 1
        _require_command sed || return 1
        _require_command comm || return 1
        _require_command mktemp || return 1

        _ensure_manager_directories || return 1
        _ensure_release_manager_config || return 1

        # First install discovers product ZIPs beside sgnd-setup and installs through
        # the same package pipeline used by normal local/GitHub actions.
        if [[ -z "$ACTION" ]]; then
            _bootstrap_first_install_packages || return $?
        fi

        if [[ -z "$ACTION" && -n "${BOOTSTRAP_RELEASE_BASE:-}" ]]; then
            _install_release_manager || return 1

            case "${BOOTSTRAP_POST_INSTALL_ACTION:-setup}" in
                exit)
                    _release_save_state || true
                    return 0
                    ;;
                management-console)
                    _release_save_state || true
                    if [[ "$VAL_TARGET_ROOT" == "/" ]]; then
                        [[ -x /usr/local/bin/sgnd-console ]] || {
                            _release_fail "Management Console command not found: /usr/local/bin/sgnd-console"
                            return 1
                        }
                        exec /usr/local/bin/sgnd-console
                    fi

                    _release_fail "Management Console handoff is only available for the live target root (/)"
                    return 1
                    ;;
                setup)
                    ;;
                *)
                    _release_fail "Unknown post-install action: $BOOTSTRAP_POST_INSTALL_ACTION"
                    return 1
                    ;;
            esac
        elif [[ -f "$CANONICAL_MANAGER_PATH" ]]; then
            _install_release_manager || return 1
        elif [[ "$SCRIPT_FILE" != "$CANONICAL_MANAGER_PATH" ]]; then
            _install_setup_self || return 1
        fi

        if [[ -z "$ACTION" ]]; then
            [[ -t 0 && -t 1 ]] || {
                _release_fail "No action specified in non-interactive mode"
                print_usage
                return 1
            }
            _interactive_menu
            _release_save_state || true
            return $?
        fi

        case "$ACTION" in
            check) _action_check || rc=$? ;;
            download) _action_download || rc=$? ;;
            update) _action_install_latest_github_products || rc=$? ;;
            install) _action_install_latest_local_packages || rc=$? ;;
            rollback) _action_rollback || rc=$? ;;
            remove) _action_remove || rc=$? ;;
            *) _release_fail "Unknown action: $ACTION"; rc=1 ;;
        esac

        if (( rc == 0 )); then
            _release_save_state || true
        fi

        if (( rc == 0 )) && [[ -n "${BOOTSTRAP_RELEASE_BASE:-}" ]]; then
            _cleanup_bootstrap_files || return 1
        fi

        return "$rc"
    }

    main "$@"
