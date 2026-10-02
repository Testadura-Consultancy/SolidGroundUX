# =====================================================================================
# SolidGroundUX - Bootstrap Core
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
#   Checksum    : 1780f5dfeb149a56313cc136e0bbe24f2580db36d4642367a57aa0592d90141e
#   Source      : sgnd-bootstrap.sh
#   Type        : library
#   Group       : Bootstrap
#   Purpose     : Initialize the SolidGroundUX framework and load core modules
#
# Description:
#   Provides the central bootstrap mechanism for all SolidGroundUX scripts.
#
#   The library:
#     - Orchestrates framework initialization sequence
#     - Loads core and declared libraries (SGND_USING)
#     - Parses and separates framework and script arguments
#     - Initializes environment, configuration, and runtime state
#     - Applies standard execution flow for all scripts
#     - Ensures consistent startup behavior across all tools
#
# Design principles:
#   - Single entry point for framework initialization
#   - Deterministic and repeatable startup sequence
#   - Explicit dependency loading via SGND_USING
#   - Minimal assumptions about script context
#
# Role in framework:
#   - Central orchestrator of the SolidGroundUX runtime
#   - Bridges bootstrap environment, argument parsing, and module loading
#   - Ensures every script runs within a fully initialized framework context
#
# Non-goals:
#   - Business logic execution
#   - UI rendering or interaction handling
#   - Application-specific behavior
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail
# - Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard - Enforce source-only, single-load library initialization
        # . Purpose
        #   Ensure the file is sourced as a library and initialized only once.
        #
        # . Behavior
        #   - Derives a unique guard variable name from the current filename.
        #   - Aborts execution when the file is run directly instead of sourced.
        #   - Sets the guard variable on first load.
        #   - Returns immediately when the library was already loaded.
        #
        # Inputs
        #   BASH_SOURCE[0]
        #   $0
        #
        # Outputs (globals)
        #   SGND_<MODULE>_LOADED
        #
        # . Returns
        #   0 when already loaded or successfully initialized.
        #   Exits with code 2 when executed instead of sourced.
        #
        # . Usage
        #   _sgnd_lib_guard
    _sgnd_lib_guard() {
        local lib_base=""
        local guard=""

        lib_base="$(basename "${BASH_SOURCE[0]}" .sh)"
        lib_base="${lib_base//-/_}"
        guard="SGND_${lib_base^^}_LOADED"

        [[ "${BASH_SOURCE[0]}" != "$0" ]] || {
            printf 'This is a library; source it, do not execute it: %s\n' "${BASH_SOURCE[0]}" >&2
            exit 2
        }

        [[ -n "${!guard-}" ]] && return 0
        printf -v "$guard" '1'
    }

    _sgnd_lib_guard
    unset -f _sgnd_lib_guard

    if declare -F sgnd_module_init_metadata >/dev/null 2>&1 \
        && declare -F sgnd_header_buffer_load >/dev/null 2>&1; then
        sgnd_module_init_metadata "${BASH_SOURCE[0]}"
    fi
# - Main sequence helpers + EXIT dispatch -------------------------------------------
    # fn: _parse_bootstrap_args - Parse early bootstrap options
        # . Purpose
        #   Extract bootstrap-only options before the full argument parser is available.
        #
        # . Behavior
        #   - Detects state mode, root policy, logfile, and console loglevel bootstrap options.
        #   - Supports --loglevel <silent|quiet|normal|verbose|debug|trace>, --loglevel=<...>, --quiet, and --silent.
        #   - Stores all remaining arguments in SGND_BOOTSTRAP_REST.
        #   - Stops parsing at '--' or the first non-bootstrap argument.
        #
        # . Arguments
        #   $@  Raw script arguments passed to sgnd_bootstrap.
        #
        # Outputs (globals):
        #   exe_state, exe_root, SGND_CONSOLE_LOG_LEVEL, SGND_BOOTSTRAP_REST
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _parse_bootstrap_args "$@"
    _parse_bootstrap_args() {
        exe_state=0
        exe_root=0

        SGND_BOOTSTRAP_REST=()

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --state)
                    exe_state=1; shift ;;
                --autostate)
                     exe_state=2; shift ;;
                --needroot)
                    exe_root=1; shift ;;
                --cannotroot)
                    exe_root=2; shift ;;
                --quiet)
                    SGND_CONSOLE_LOG_LEVEL="quiet"
                    shift ;;
                --silent)
                    SGND_CONSOLE_LOG_LEVEL="silent"
                    shift ;;
                --loglevel)
                    shift
                    case "${1:-}" in
                        off|none|silent) SGND_CONSOLE_LOG_LEVEL="silent" ;;
                        warn|quiet)      SGND_CONSOLE_LOG_LEVEL="quiet" ;;
                        normal)          SGND_CONSOLE_LOG_LEVEL="normal" ;;
                        verbose)         SGND_CONSOLE_LOG_LEVEL="verbose" ;;
                        debug)           SGND_CONSOLE_LOG_LEVEL="debug" ;;
                        trace|all)       SGND_CONSOLE_LOG_LEVEL="trace" ;;
                        *)               SGND_CONSOLE_LOG_LEVEL="silent" ;;
                    esac
                    [[ $# -gt 0 ]] && shift ;;
                --loglevel=*)
                    case "${1#--loglevel=}" in
                        off|none|silent) SGND_CONSOLE_LOG_LEVEL="silent" ;;
                        warn|quiet)      SGND_CONSOLE_LOG_LEVEL="quiet" ;;
                        normal)          SGND_CONSOLE_LOG_LEVEL="normal" ;;
                        verbose)         SGND_CONSOLE_LOG_LEVEL="verbose" ;;
                        debug)           SGND_CONSOLE_LOG_LEVEL="debug" ;;
                        trace|all)       SGND_CONSOLE_LOG_LEVEL="trace" ;;
                        *)               SGND_CONSOLE_LOG_LEVEL="silent" ;;
                    esac
                    shift ;;
                --) 
                    shift; SGND_BOOTSTRAP_REST=("$@"); return 0 ;;
                *) 
                    SGND_BOOTSTRAP_REST=("$@"); return 0 ;;
            esac
        done
    }

    # fn: _init_bootstrap - Initialize bootstrap environment
        # . Purpose
        #   Prepare the minimum framework environment required before core libraries load.
        #
        # . Behavior
        #   - Resolves the bootstrap directory.
        #   - Resolves and sources framework/project definition libraries from globals/.
        #   - Sources the comment-header parser and bootstrap environment library.
        #   - Initializes metadata for early-loaded core modules and the active script.
        #   - Applies defaults, rebases paths, and ensures required directories exist.
        #
        # Outputs (globals):
        #   SGND_BOOTSTRAP_DIR and environment/path globals initialized by bootstrap-env.
        #
        # . Returns
        #   0 when initialization succeeds.
        #   Non-zero when sourcing, metadata initialization, path setup, or directory creation fails.
        #
        # . Usage
        #   _init_bootstrap
    _init_bootstrap() {
        sayinfo "Sourcing bootstrap environment"
        SGND_BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

        if [[ "$SGND_FRAMEWORK_ROOT" == "/" ]]; then
            SGND_GLOBALS_FOLDER="/usr/local/lib/solidgroundux/globals"
        else
            SGND_GLOBALS_FOLDER="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/globals"
        fi

        local framework_definitions=""
        sgnd_framework_resolve_path \
            "usr/local/lib/solidgroundux/globals/sgnd-definitions.sh" \
            framework_definitions || return 126

        # shellcheck source=/dev/null
        source "$SGND_BOOTSTRAP_DIR/sgnd-comment-header-parser.sh"
        source "$framework_definitions"
        source "$SGND_BOOTSTRAP_DIR/sgnd-bootstrap-env.sh"

        # Project definition files are foundational globals rather than SGND_USING
        # dependencies. Source every additional *-definitions.sh from globals/.
        local project_def=""
        while IFS= read -r -d '' project_def; do
            [[ "$(basename -- "$project_def")" == "sgnd-definitions.sh" ]] && continue
            # shellcheck source=/dev/null
            source "$project_def"
        done < <(
            find "$SGND_GLOBALS_FOLDER" -maxdepth 1 -type f -name '*-definitions.sh' -print0 2>/dev/null | sort -z
        )

        # Core modules cannot self-initialize metadata during early source phase.
        # Initialize them here once header parsing helpers are available.
        sgnd_module_init_metadata "$SGND_BOOTSTRAP_DIR/sgnd-bootstrap.sh"
        sgnd_module_init_metadata "$SGND_BOOTSTRAP_DIR/sgnd-comment-header-parser.sh"
        sgnd_module_init_metadata "$framework_definitions"
        sgnd_module_init_metadata "$SGND_BOOTSTRAP_DIR/sgnd-bootstrap-env.sh"

        sgnd_script_init_metadata
        sgnd_apply_defaults

        sayinfo "Rebasing directories"
        sgnd_rebase_directories
        sgnd_rebase_framework_cfg_paths

        sayinfo "Making sure directories exist"
        sgnd_ensure_dirs "${SGND_FRAMEWORK_DIRS[@]}"
    }


    # fn: _source_corelibs - Source required core libraries
        # . Purpose
        #   Load the fixed set of framework core libraries in bootstrap order.
        #
        # . Behavior
        #   - Rebases directories before resolving library paths.
        #   - Iterates SGND_CORE_LIBS in order.
        #   - Sources each core library from SGND_COMMON_LIB.
        #
        # Inputs (globals):
        #   SGND_CORE_LIBS, SGND_COMMON_LIB
        #
        # . Returns
        #   0 when all core libraries are sourced.
        #   Non-zero when a sourced library fails.
        #
        # . Usage
        #   _source_corelibs
    _source_corelibs(){
        sayinfo "Loading core libraries..."  
        sgnd_rebase_directories

        local lib path
        for lib in "${SGND_CORE_LIBS[@]}"; do
            sgnd_framework_resolve_path \
                "usr/local/lib/solidgroundux/common/$lib" \
                path || {
                    sayfail "Core library not found: $lib"
                    return 126
                }
            # shellcheck source=/dev/null
            source "$path"
        done
    }

    # fn: _source_usinglibs - Source declared optional libraries
        # . Purpose
        #   Load script-declared framework libraries listed in SGND_USING.
        #
        # . Behavior
        #   - Returns without action when SGND_USING is not declared or empty.
        #   - Resolves each declared library relative to SGND_COMMON_LIB.
        #   - Validates readability before sourcing.
        #   - Relies on each library guard to prevent duplicate initialization.
        #
        # Inputs (globals):
        #   SGND_USING, SGND_COMMON_LIB
        #
        # . Returns
        #   0 when no libraries are declared or all declared libraries load successfully.
        #   126 when a declared library is missing or unreadable.
        #   Non-zero when a sourced library fails.
        #
        # . Usage
        #   _source_usinglibs
    _source_usinglibs() {
        local lib path

        declare -p SGND_USING >/dev/null 2>&1 || return 0
        (( ${#SGND_USING[@]} > 0 )) || return 0

        sayinfo "Loading optional libraries..."

        for lib in "${SGND_USING[@]}"; do
            sgnd_framework_resolve_path \
                "usr/local/lib/solidgroundux/common/$lib" \
                path || {
                    sayfail "Optional library not found or unreadable: $lib"
                    return 126
                }

            [[ -r "$path" ]] || {
                sayfail "Optional library not found or unreadable: $path"
                return 126
            }

            saydebug "Sourcing optional library: $path"
            # shellcheck source=/dev/null
            source "$path"
        done
    }

    # fn: _sgnd_on_exit_run - Run registered exit handlers
        # . Purpose
        #   Dispatch registered framework cleanup handlers when the shell exits.
        #
        # . Behavior
        #   - Captures the current exit status immediately.
        #   - Runs SGND_ON_EXIT_HANDLERS in reverse registration order.
        #   - Ignores individual handler failures to preserve exit dispatch.
        #   - Returns the original exit status.
        #
        # Inputs (globals):
        #   SGND_ON_EXIT_HANDLERS
        #
        # . Returns
        #   The original shell exit status captured on entry.
        #
        # . Usage
        #   trap '_sgnd_on_exit_run' EXIT
    _sgnd_on_exit_run() {
        local rc=$?
        local i cmd
        saydebug "Entering on exit"
        declare -p SGND_ON_EXIT_HANDLERS >/dev/null 2>&1 || { return "$rc"; }

        for (( i=${#SGND_ON_EXIT_HANDLERS[@]}-1; i>=0; i-- )); do
            
            cmd="${SGND_ON_EXIT_HANDLERS[i]}"
            saydebug "On exit executing: $cmd"
            eval "$cmd" || true
        done

        return "$rc"
    }

    # fn: _sgnd_save_state_dispatch - Save state on clean exit
        # . Purpose
        #   Conditionally persist framework state from the exit-handler stack.
        #
        # . Behavior
        #   - Captures the current exit status immediately.
        #   - Saves state only on clean exit when SGND_STATE_SAVE is enabled.
        #   - Skips state save for Ctrl+C and failing exits.
        #   - Returns the original exit status.
        #
        # Inputs (globals):
        #   SGND_STATE_SAVE
        #
        # . Returns
        #   The original shell exit status captured on entry.
        #
        # . Usage
        #   sgnd_on_exit_add "_sgnd_save_state_dispatch"
    _sgnd_save_state_dispatch() {
        local rc=$?   # capture immediately!

        # Only run state save on clean exit
        if (( rc == 0 && SGND_STATE_SAVE == 1 )); then
            sgnd_save_state
        elif (( rc == 130 )); then
            saydebug "Interrupted (Ctrl+C), not saving state"
        else
            saydebug "Error exit ($rc), not saving state"
        fi

        return "$rc"
    }
    # fn: sgnd_script_init_metadata - Script init metadata
        # . Purpose
        #   Initialize script metadata globals from a script comment header.
        #
        # . Behavior
        #   - Parses the active executable comment header into SGND_SCRIPT_* runtime metadata aliases.
        #   - Uses Metadata/Shortname when present, otherwise the normalized script filename.
        #   - Leaves already populated SGND_SCRIPT_* values unchanged.
        #
        # Outputs (globals):
        #   SGND_SCRIPT_PRODUCT
        #   SGND_SCRIPT_TITLE
        #   SGND_SCRIPT_DESCRIPTION
        #   SGND_SCRIPT_DESC
        #   SGND_SCRIPT_SHORTNAME
        #   SGND_SCRIPT_VERSION / BUILD / CHECKSUM / SOURCE / TYPE / PURPOSE
        #   SGND_SCRIPT_DEVELOPERS / COMPANY / CLIENT / COPYRIGHT / LICENSE
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_script_init_metadata "/usr/local/libexec/solidgroundux/management-console.sh"
    sgnd_script_init_metadata() {
        local metadata=""
        local attribution=""
        local value=""
        local shortname=""

        [[ -n "${SGND_SCRIPT_FILE:-}" && -r "$SGND_SCRIPT_FILE" ]] || return 1

        # --- Banner (Product / Title) ------------------------------------------------
        [[ -n "${SGND_SCRIPT_PRODUCT:-}" && -n "${SGND_SCRIPT_TITLE:-}" ]] || \
            sgnd_header_get_banner_parts "$SGND_SCRIPT_FILE" SGND_SCRIPT_PRODUCT SGND_SCRIPT_TITLE

        # --- Description (multiline section) -----------------------------------------
        [[ -n "${SGND_SCRIPT_DESCRIPTION:-}" ]] || \
            sgnd_header_get_section "$SGND_SCRIPT_FILE" "Description" SGND_SCRIPT_DESCRIPTION

        # --- Load sections once ------------------------------------------------------
        sgnd_header_get_section "$SGND_SCRIPT_FILE" "Metadata" metadata
        sgnd_header_get_section "$SGND_SCRIPT_FILE" "Attribution" attribution

        # --- Metadata fields ---------------------------------------------------------
        if [[ -z "${SGND_SCRIPT_SHORTNAME:-}" ]]; then
            shortname="$(sgnd_section_get_field_value "$metadata" "Shortname")"
            [[ -n "$shortname" ]] || shortname="${SGND_SCRIPT_NAME:-$(basename -- "$SGND_SCRIPT_FILE" .sh)}"
            shortname="${shortname//-/_}"
            shortname="${shortname// /_}"
            shortname="${shortname^^}"
            SGND_SCRIPT_SHORTNAME="$shortname"
        fi

        [[ -n "${SGND_SCRIPT_VERSION:-}" ]]   || SGND_SCRIPT_VERSION="$(sgnd_section_get_field_value "$metadata" "Version")"
        [[ -n "${SGND_SCRIPT_BUILD:-}" ]]     || SGND_SCRIPT_BUILD="$(sgnd_section_get_field_value "$metadata" "Build")"
        [[ -n "${SGND_SCRIPT_CHECKSUM:-}" ]]  || SGND_SCRIPT_CHECKSUM="$(sgnd_section_get_field_value "$metadata" "Checksum")"
        [[ -n "${SGND_SCRIPT_SOURCE:-}" ]]    || SGND_SCRIPT_SOURCE="$(sgnd_section_get_field_value "$metadata" "Source")"
        [[ -n "${SGND_SCRIPT_TYPE:-}" ]]      || SGND_SCRIPT_TYPE="$(sgnd_section_get_field_value "$metadata" "Type")"
        [[ -n "${SGND_SCRIPT_PURPOSE:-}" ]]   || SGND_SCRIPT_PURPOSE="$(sgnd_section_get_field_value "$metadata" "Purpose")"

        # --- Attribution fields ------------------------------------------------------
        [[ -n "${SGND_SCRIPT_DEVELOPERS:-}" ]] || SGND_SCRIPT_DEVELOPERS="$(sgnd_section_get_field_value "$attribution" "Developers")"    
        [[ -n "${SGND_SCRIPT_COMPANY:-}" ]]    || SGND_SCRIPT_COMPANY="$(sgnd_section_get_field_value "$attribution" "Company")"
        [[ -n "${SGND_SCRIPT_CLIENT:-}" ]]     || SGND_SCRIPT_CLIENT="$(sgnd_section_get_field_value "$attribution" "Client")"
        [[ -n "${SGND_SCRIPT_COPYRIGHT:-}" ]]  || SGND_SCRIPT_COPYRIGHT="$(sgnd_section_get_field_value "$attribution" "Copyright")"
        [[ -n "${SGND_SCRIPT_LICENSE:-}" ]]    || SGND_SCRIPT_LICENSE="$(sgnd_section_get_field_value "$attribution" "License")"

        # --- Short description (first line of Description) ------------------------------
        if [[ -z "${SGND_SCRIPT_DESC:-}" ]]; then
            if [[ -n "${SGND_SCRIPT_DESCRIPTION:-}" ]]; then
                SGND_SCRIPT_DESC="${SGND_SCRIPT_DESCRIPTION%%$'\n'*}"
            else
                SGND_SCRIPT_DESC=""
            fi
        fi
        return 0
    }
    # fn: sgnd_module_init_metadata - Module init metadata
        # . Purpose
        #   Initialize module metadata globals from a sourced library or module comment header.
        #
        # . Behavior
        #   - Parses the canonical comment header once and exposes module-scoped metadata globals.
        #   - Uses Metadata/Shortname as the variable prefix when present.
        #   - Falls back to the normalized filename when Shortname is omitted.
        #
        # . Arguments
        #   $1  FILE - File path.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_module_init_metadata "/tmp/sgnd-example.txt"
    sgnd_module_init_metadata() {
        local file="${1:-${BASH_SOURCE[1]}}"
        local abs_file=""
        local dir=""
        local base=""
        local name=""
        local shortname=""
        local key=""
        local prefix=""
        local var_name=""

        local product=""
        local title=""
        local desc=""
        local metadata=""
        local attribution=""
        local value=""

        [[ -n "$file" && -r "$file" ]] || return 1

        abs_file="$(readlink -f "$file")" || return 1
        dir="$(cd -- "$(dirname -- "$abs_file")" && pwd)" || return 1
        base="$(basename -- "$abs_file")"
        name="${base%.sh}"

        # --- Load header buffer and sections once ------------------------------------
        sgnd_header_buffer_load "$abs_file" || return 1
        sgnd_header_buffer_get_section "Description" desc || desc=""
        sgnd_header_buffer_get_section "Metadata" metadata || metadata=""
        sgnd_header_buffer_get_section "Attribution" attribution || attribution=""

        # --- Metadata identity -------------------------------------------------------
        shortname="$(sgnd_section_get_field_value "$metadata" "Shortname")"
        [[ -n "$shortname" ]] || shortname="$name"
        key="${shortname//-/_}"
        key="${key// /_}"
        key="${key^^}"
        prefix="SGND_${key}"

        # --- Structural variables ----------------------------------------------------
        var_name="${prefix}_FILE";      [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$abs_file"
        var_name="${prefix}_DIR";       [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$dir"
        var_name="${prefix}_BASE";      [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$base"
        var_name="${prefix}_NAME";      [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$name"
        var_name="${prefix}_KEY";       [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$prefix"
        var_name="${prefix}_SHORTNAME"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$key"

        # --- Banner (Product / Title) ------------------------------------------------
        if sgnd_header_get_banner_parts_from_text "$SGND_HEADER_BUFFER_TEXT" product title; then
            var_name="${prefix}_PRODUCT"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$product"
            var_name="${prefix}_TITLE";   [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$title"
        else
            var_name="${prefix}_PRODUCT"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' ""
            var_name="${prefix}_TITLE";   [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' ""
        fi

        # --- Description (multiline section) -----------------------------------------
        var_name="${prefix}_DESC"
        if [[ -z "${!var_name-}" ]]; then
            printf -v "$var_name" '%s' "$desc"
        fi

        # --- Metadata fields ---------------------------------------------------------
        value="$(sgnd_section_get_field_value "$metadata" "Version")"
        var_name="${prefix}_VERSION"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$metadata" "Build")"
        var_name="${prefix}_BUILD"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$metadata" "Checksum")"
        var_name="${prefix}_CHECKSUM"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$metadata" "Source")"
        var_name="${prefix}_SOURCE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$metadata" "Type")"
        var_name="${prefix}_TYPE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$metadata" "Purpose")"
        var_name="${prefix}_PURPOSE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        # --- Attribution fields ------------------------------------------------------
        value="$(sgnd_section_get_field_value "$attribution" "Developers")"
        var_name="${prefix}_DEVELOPERS"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$attribution" "Company")"
        var_name="${prefix}_COMPANY"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$attribution" "Client")"
        var_name="${prefix}_CLIENT"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$attribution" "Copyright")"
        var_name="${prefix}_COPYRIGHT"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        value="$(sgnd_section_get_field_value "$attribution" "License")"
        var_name="${prefix}_LICENSE"; [[ -n "${!var_name-}" ]] || printf -v "$var_name" '%s' "$value"

        return 0
    }

    # fn: sgnd_on_exit_install - On exit install
        # . Purpose
        #   Install the SolidGroundUX exit trap dispatcher once for the current shell.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_on_exit_install
    sgnd_on_exit_install() {
        # Install once
        [[ "${_SGND_ON_EXIT_INSTALLED-0}" -eq 1 ]] && return 0
        _SGND_ON_EXIT_INSTALLED=1
        trap '_sgnd_on_exit_run' EXIT
    }
    # fn: sgnd_parse_statespec - Parse statespec
        # . Purpose
        #   Parse a save-state specification into source variable and state key parts.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  SPEC - Positional value used by this function.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_parse_statespec "example"
    sgnd_parse_statespec() {
        local spec="${1-}"
        _statekey="" _statelabel="" _statedefault="" _statevalidate="" _statecolorize=""
        IFS='|' read -r _statekey _statelabel _statedefault _statevalidate _statecolorize <<< "$spec"
    }
    # fn: sgnd_enable_save_state - Enable save state
        # . Purpose
        #   Enable automatic persistence of selected runtime values on shell exit.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_enable_save_state
    sgnd_enable_save_state(){
        SGND_STATE_SAVE=1
    }
    # fn: sgnd_disable_save_state - Disable save state
        # . Purpose
        #   Disable automatic save-state handling for the current shell.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_disable_save_state
    sgnd_disable_save_state(){
        SGND_STATE_SAVE=0
    }
    # fn: sgnd_save_state - Save state
        # . Purpose
        #   Persist configured runtime state values to the active state domain.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_save_state
    sgnd_save_state(){

        (( ! SGND_STATE_SAVE )) && return 0

        if [[ "$FLAG_DRYRUN" -eq 1 ]]; then
            sayinfo "Would have saved state variables from list"
        else
            saydebug "Assembling list out of SGND_STATE_VARIABLES"
            local line key label def validator colorize
            local keys=()

            [[ ${#SGND_STATE_VARIABLES[@]} -gt 0 ]] || return 0
            saystart "Saving state variables"
            for line in "${SGND_STATE_VARIABLES[@]}"; do
                sgnd_parse_statespec "$line"
                key="$(sgnd_trim "$_statekey")"
                _sgnd_is_ident "$key" || continue
                keys+=( "$key" )
            done

            saydebug "Saving state variables from array"
            # Only save if the array exists and has elements
            [[ ${#keys[@]} -gt 0 ]] || return 0
            sgnd_state_save_keys "${keys[@]}"
            sayend "Done saving state variables."
        fi
    }    
    # fn: sgnd_on_exit_add - On exit add
        # . Purpose
        #   Register a function or command to run through the SolidGroundUX exit dispatcher.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_on_exit_add
    sgnd_on_exit_add() {
        # store as one string per handler: "fn arg1 arg2 ..."
        SGND_ON_EXIT_HANDLERS+=( "$*" )
    }
    # fn: sgnd_check_license - Check license
        # . Purpose
        #   Validate the current SolidGroundUX license state when licensing is enabled.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_check_license
    sgnd_check_license() {
        local license_file="$SGND_LICENSE_FILE"
        local license_name="${SGND_LICENSE_FILE##*/}"
        local accepted_file="$SGND_STATE_DIR/$license_name.accepted"
        local framework_relative_license=""

        # SGND_LICENSE_FILE is rebased to the contextual root during bootstrap. When
        # that root belongs to an SDK/MCM development tree, resolve the Framework-owned
        # license through the canonical Framework resolver instead.
        if [[ ! -r "$license_file" && "$SGND_FRAMEWORK_ROOT" != "/" ]]; then
            if [[ "$license_file" == "${SGND_FRAMEWORK_ROOT%/}/"* ]]; then
                framework_relative_license="${license_file#${SGND_FRAMEWORK_ROOT%/}/}"
                if sgnd_framework_resolve_path "$framework_relative_license" license_file; then
                    SGND_LICENSE_FILE="$license_file"
                fi
            fi
        fi
        local isaccepted=0
        local wasaccepted=0
        local current_hash

        saydebug "license_file: %s\n" "$license_file"
        saydebug "accepted_file: %s\n" "$accepted_file"

        saydebug "Checking license acceptance state for: $license_file"
        if ! current_hash="$(sgnd_hash_sha256_file "$license_file")"; then
            saywarning "sgnd_check_license: could not compute hash"
            current_hash=""
        fi

        if [[ -z "$current_hash" ]]; then
            saywarning "sgnd_check_license: license hash is empty; license cannot be accepted"
            isaccepted=0
        else
            if [[ -r "$accepted_file" ]]; then

                local stored_hash
                stored_hash="$(cat "$accepted_file" 2>/dev/null)"
                wasaccepted=1

                if [[ "$stored_hash" == "$current_hash" ]]; then
                    sayinfo "sgnd_check_license: accepted state matches current license hash"
                    isaccepted=1
                else
                    sayinfo "sgnd_check_license: accepted state hash does NOT match current license hash"
                fi
            else
                sayinfo "sgnd_check_license: no accepted state file found at: $accepted_file"
            fi
        fi

        if (( isaccepted == 0 )); then
            local question_text
            
            if (( ${wasaccepted:-0} == 1 )); then
                question_text="The license has been updated since you last accepted it. Do you accept the new license terms?"
            else
                question_text="Do you accept these license terms? \n (You must accept to use this software.)"
            fi

            printf "Should print license here"

            sgnd_print_license

            local accepted="Y"
            ask --label "$question_text" --var accepted --default "$accepted" --colorize both --labelclr "${CYAN}"
           
            case $? in
                0)
                    mkdir -p "$SGND_STATE_DIR"
                    echo "$current_hash" > "$accepted_file"
                    isaccepted=1
                    ;;
                1|2)
                    saywarning "Cancelled by user."
                    return 2
                    ;;
                *)
                    sayfail "Aborting (unexpected response)."
                    return 1
                    ;;
            esac
                       
            sayinfo "sgnd_check_license: license not accepted; prompting user"
        fi

        sayinfo "License acceptance status: $(
            [[ $isaccepted -eq 1 ]] \
            && echo "${SGND_UI_VALID}ACCEPTED${RESET}" \
            || echo "${SGND_UI_INVALID}NOT ACCEPTED${RESET}"
        )"

        SGND_LICENSE_ACCEPTED=$isaccepted
    }
    # fn: _boot_fail - Report a bootstrap failure safely
        # . Purpose
        #   Report a bootstrap-stage failure without depending on later UI initialization.
        #
        # . Parameters
        #   $1 Failure message.
        #   $2 Return status.
        #
        # . Returns
        #   Returns the supplied status, defaulting to 1.
        #
        # . Usage
        #   _boot_fail "Failed to load core libraries" 126
    _boot_fail() {
        local message="${1:-Bootstrap failed}"
        local rc="${2:-1}"

        if declare -F sayfail >/dev/null 2>&1; then
            sayfail "$message"
        else
            printf 'FATAL: %s\n' "$message" >&2
        fi

        return "$rc"
    }

    # fn: sgnd_load_ui_style - Load ui style
        # . Purpose
        #   Load the configured SolidGroundUX UI palette and style files.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_load_ui_style
    sgnd_load_ui_style() {
        local style_path="${SGND_UI_STYLE:-00-style-default.sh}"
        local palette_path="$SGND_UI_PALETTE"
        local style_name=""
        local resolved_style=""
        local resolved_style_dir=""

        if sgnd_framework_resolve_path "usr/local/lib/solidgroundux/styles" resolved_style_dir; then
            SGND_STYLE_DIR="$resolved_style_dir"
        fi


        if [[ "$style_path" != */* ]]; then
            if [[ -r "$SGND_STYLE_DIR/$style_path" ]]; then
                style_path="$SGND_STYLE_DIR/$style_path"
            else
                style_name="${style_path%.sh}"
                style_name="${style_name#style-}"
                [[ "$style_name" == "default-ui-style" ]] && style_name="default"

                while IFS= read -r resolved_style; do
                    style_path="$SGND_STYLE_DIR/$resolved_style"
                    SGND_UI_STYLE="$resolved_style"
                    break
                done < <(
                    find "$SGND_STYLE_DIR" -maxdepth 1 -type f \
                        -name "[0-9][0-9]-style-${style_name}.sh" \
                        -printf '%f\n' | LC_ALL=C sort
                )
            fi
        fi

        if [[ "$palette_path" != */* ]]; then
            palette_path="$SGND_STYLE_DIR/$palette_path"
        elif [[ ! -r "$palette_path" && "$SGND_FRAMEWORK_ROOT" != "/" ]]; then
            local framework_style_dir="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/styles"
            if [[ "$palette_path" == "$framework_style_dir/"* ]]; then
                palette_path="${SGND_STYLE_DIR%/}/${palette_path##*/}"
            fi
        fi

        [[ -r "$palette_path" ]] || { saywarning "Palette not found: $palette_path"; return 1; }
        [[ -r "$style_path"   ]] || { saywarning "Style not found: $style_path";   return 1; }

        # shellcheck source=/dev/null
        source "$palette_path"
        # shellcheck source=/dev/null
        source "$style_path"
    }
    # fn: sgnd_bootstrap - Bootstrap
        # . Purpose
        #   Bootstrap the SolidGroundUX framework for an executable script.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_bootstrap --state --log normal
    sgnd_bootstrap() {
        # Definitions
            : "${SGND_UI_COMMIT:=$(printf '\e[38;5;214m')}"
            : "${SGND_UI_DRYRUN:=$(printf '\e[38;5;214m')}"
            : "${RESET:=$(printf '\e[0m')}"
            : "${RUN_MODE:="${SGND_UI_COMMIT}COMMIT${RESET}"}"
            : "${FLAG_DRYRUN:=0}"
            : "${FLAG_STATERESET:=0}"
            : "${FLAG_INIT_CONFIG:=0}"
            : "${FLAG_HELP:=0}"
            : "${ARG_SHOW:=}"
            : "${ARG_LOGLEVEL:=}"

            _parse_bootstrap_args "$@" || { local rc=$?; _boot_fail "Failed parsing bootstrap arguments" "$rc"; return "$rc"; }

            saystart "Initializing framework"

            if ! declare -p SGND_SCRIPT_GLOBALS >/dev/null 2>&1; then
                declare -ag SGND_SCRIPT_GLOBALS=()
            fi
            
            if ! declare -p SGND_STATE_VARIABLES >/dev/null 2>&1; then
                declare -ag SGND_STATE_VARIABLES=()
            fi

            if ! declare -p SGND_ON_EXIT_HANDLERS >/dev/null 2>&1; then
                declare -ag SGND_ON_EXIT_HANDLERS=()
            fi

        # Basic initialization - Defaults
            sayinfo "Initializing bootstrap..."
            _init_bootstrap || { local rc=$?; _boot_fail "Failed to initialize bootstrapper" "$rc"; return "$rc"; }

            _source_corelibs || { local rc=$?; _boot_fail "Failed to load core libraries" "$rc"; return "$rc"; }

            if [[ -r "$SGND_COMMON_LIB/sgnd-exe-common.sh" ]]; then
                sgnd_module_init_metadata "$SGND_COMMON_LIB/sgnd-exe-common.sh"
            fi

            _source_usinglibs || { local rc=$?; _boot_fail "Failed to load optional libraries" "$rc"; return "$rc"; }
        # Load Framework globals
            sayinfo "Loading framework globals"
            sgnd_cfg_domain_apply "Framework" "$SGND_FRAMEWORK_SYSCFG_FILE" "$SGND_FRAMEWORK_USRCFG_FILE" "SGND_FRAMEWORK_GLOBALS" "framework" \
                || { local rc=$?; _boot_fail "Framework cfg load failed" "$rc"; return "$rc"; }
        # Load shared framework state
            SGND_FRAMEWORK_STATEFILE="$SGND_USRCFG_DIR/framework.state"
            sayinfo "Loading framework state"
            if [[ -f "$SGND_FRAMEWORK_STATEFILE" ]]; then
                sgnd_state_load_keys \
                    --file "$SGND_FRAMEWORK_STATEFILE" \
                    --array SGND_FRAMEWORK_STATE \
                    || { local rc=$?; _boot_fail "Framework state load failed" "$rc"; return "$rc"; }
            else
                sgnd_state_save_keys \
                    --file "$SGND_FRAMEWORK_STATEFILE" \
                    --array SGND_FRAMEWORK_STATE \
                    || { local rc=$?; _boot_fail "Framework state creation failed" "$rc"; return "$rc"; }
            fi

        # Load UI style
            sayinfo "Loading UI style"
            sgnd_load_ui_style || { local rc=$?; _boot_fail "Failed to load UI style" "$rc"; return "$rc"; }
        # Parse builtin arguments early. Consume builtins wherever they appear while
        # preserving script-specific options and positionals in their original order.
            saydebug "Processing builtin arguments."
            local -a _sgnd_script_args
            local -a _sgnd_after_builtins
            local _sgnd_prev_args_source="${SGND_ARGS_SOURCE-}"
                _sgnd_script_args=( "${SGND_BOOTSTRAP_REST[@]}" )

            saydebug "Parsing builtin arguments from: ${_sgnd_script_args[*]}"
            SGND_ARGS_SOURCE="builtins"
            sgnd_parse_args --preserve-unknown "${_sgnd_script_args[@]}" \
                || { local rc=$?; SGND_ARGS_SOURCE="$_sgnd_prev_args_source"; _boot_fail "Error parsing builtins" "$rc"; return "$rc"; }
            SGND_ARGS_SOURCE="$_sgnd_prev_args_source"

            _sgnd_after_builtins=( "${SGND_POSITIONAL[@]}" )
        
        # If provided CLI log level, should override framework configuration.
            if [[ -n "${ARG_LOGLEVEL:-}" ]]; then
                SGND_CONSOLE_LOG_LEVEL="$ARG_LOGLEVEL"
            fi

        # Final basic settings
            saydebug "Finalizing initial settings"
            sgnd_update_runmode || { local rc=$?; _boot_fail "Error setting RUN_MODE" "$rc"; return "$rc"; }

        sayinfo "Applying bootstrap options"

        # Root checks (after libs so need_root exists)
            if (( exe_root == 1 )); then
                sgnd_need_root "${_sgnd_script_args[@]}" \
                    || { local rc=$?; _boot_fail "Failed to enable need_root" "$rc"; return "$rc"; }
            fi

            if (( exe_root == 2 )); then
                sgnd_cannot_root "${_sgnd_script_args[@]}" \
                    || { local rc=$?; _boot_fail "Failed to enable cannot_root" "$rc"; return "$rc"; }
            fi

        # Now the root/non-root debate has been settled, check license acceptance.
            sgnd_check_license
            case $? in
                0) : ;;
                2) return 2 ;;
                *) { _boot_fail "License acceptance check failed" 1; return 1; } ;;
            esac
        
        # Now that we know we won't re-exec, continue with the remainder of the arguments
        SGND_BOOTSTRAP_REST=( "${_sgnd_after_builtins[@]}" )

        # Reset statefile before it's loaded if requested
        if [[ "${FLAG_STATERESET:-0}" -eq 1 ]]; then
            sgnd_state_reset
            sayinfo "State file reset as requested."
        fi

        # Load state and parse *script* args
        if (( exe_state > 0 )); then
            saydebug "Installing on exit handler"
            sgnd_on_exit_install

            saydebug "Loading state file."
            sgnd_state_load || { local rc=$?; _boot_fail "Failed to load state" "$rc"; return "$rc"; }
        fi

        if (( exe_state == 2 )); then
            saydebug "Registering save state"
            sgnd_on_exit_add "_sgnd_save_state_dispatch"
        fi
        
        if (( ${#SGND_SCRIPT_GLOBALS[@]} > 0 )); then
            saydebug "Processing CFG."
            sgnd_cfg_domain_apply "Script" "$SGND_SYSCFG_FILE" "$SGND_USRCFG_FILE" "SGND_SCRIPT_GLOBALS" \
                || { local rc=$?; _boot_fail "Script cfg load failed" "$rc"; return "$rc"; }
        fi

        # Parse script arguments after state/config have loaded. Initialize script
        # defaults once, then let explicit CLI values override restored state.
        if (( ${#SGND_ARGS_SPEC[@]} > 0 )); then
            saydebug "Parsing script arguments ${SGND_BOOTSTRAP_REST[*]}"
            local _sgnd_prev_args_source="${SGND_ARGS_SOURCE-}"
            SGND_ARGS_SOURCE="script"
            sgnd_parse_args "${SGND_BOOTSTRAP_REST[@]}" \
                || { local rc=$?; SGND_ARGS_SOURCE="$_sgnd_prev_args_source"; _boot_fail "Error parsing script args" "$rc"; return "$rc"; }
            SGND_ARGS_SOURCE="$_sgnd_prev_args_source"
            SGND_BOOTSTRAP_REST=( "${SGND_POSITIONAL[@]}" )
            saydebug "Parsed script arguments ${SGND_BOOTSTRAP_REST[*]} remaining"
        fi

        saydebug "Update loadmode"
        sgnd_update_runmode || { local rc=$?; _boot_fail "Error updating RUN_MODE" "$rc"; return "$rc"; }

        if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
            sayinfo "Running in $RUN_MODE mode (no changes will be made)."
        else
            sayinfo "Running in $RUN_MODE mode (changes will be applied)."
        fi
        sayend "Finished bootstrap"
        return 0
    }






         
