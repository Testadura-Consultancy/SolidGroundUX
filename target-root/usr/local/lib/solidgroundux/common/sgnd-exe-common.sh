# ==================================================================================
# SolidGroundUX - Executable Runtime Support
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
#   Checksum    : 88f89bc43636396d1f7ebc76af70c173e6724284fd571edcf6a1ebfe6b0e3957
#   Source      : sgnd-exe-common.sh
#   Type        : library
#   Group       : Bootstrap
#   Purpose     : Provide shared startup helpers for SolidGroundUX executable scripts
#
# Description:
#   Provides executable-level runtime support used after the framework has been
#   located but before the full SolidGroundUX runtime has been bootstrapped.
#
#   The library:
#     - Provides minimal pre-bootstrap UI output helpers
#     - Resolves and loads the framework bootstrap library
#     - Provides the standard executable startup sequence through sgnd_exe_start
#     - Keeps executable templates small and consistent
#
# Design principles:
#   - Keep executable scripts focused on script-specific behavior
#   - Centralize shared executable startup mechanics
#   - Remain safe to source before the full framework is loaded
#   - Allow executable scripts to override helpers when needed
#
# Role in framework:
#   - Executable runtime support layer
#   - Loaded by executable templates after framework root resolution
#   - Bridges executable startup and full framework bootstrap
#
# Non-goals:
#   - Framework root discovery
#   - Application-specific behavior
#   - Full UI rendering after ui-say.sh has loaded
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
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
# - Minimal UI----------------------------------------------------------------------
    # var$ Minimal message colors
        # ANSI color constants used by the fallback UI functions before the full
        # framework bootstrap has been loaded.
    MSG_CLR_INFO=$'\e[38;5;250m'
    MSG_CLR_STRT=$'\e[38;5;82m'
    MSG_CLR_OK=$'\e[38;5;82m'
    MSG_CLR_WARN=$'\e[1;38;5;208m'
    MSG_CLR_FAIL=$'\e[38;5;196m'
    MSG_CLR_CNCL=$'\e[0;33m'
    MSG_CLR_END=$'\e[38;5;82m'
    MSG_CLR_EMPTY=$'\e[2;38;5;250m'
    MSG_CLR_DEBUG=$'\e[1;35m'

    # var$ Minimal terminal colors
        # Additional ANSI constants used by template/fallback output helpers.
    SGND_UI_COMMIT=$'\e[2;37m'
    RESET=$'\e[0m'

    # fn: _sgnd_minimal_say_normalize_log_level - Normalize a minimal bootstrap log level
        # . Purpose
        #   Convert aliases and legacy log-level names into a canonical SolidGroundUX
        #   log-level value before the full UI layer is available.
        #
        # . Parameters
        #   $1 Requested log level.
        #
        # . Output
        #   Writes the normalized log-level name to stdout.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _sgnd_minimal_say_normalize_log_level "example"
    _sgnd_minimal_say_normalize_log_level() {
        case "${1,,}" in
            off|none|silent) printf '%s\n' 'silent' ;;
            warn|quiet)      printf '%s\n' 'quiet' ;;
            normal|'')       printf '%s\n' 'normal' ;;
            verbose)         printf '%s\n' 'verbose' ;;
            debug)           printf '%s\n' 'debug' ;;
            trace|all)       printf '%s\n' 'trace' ;;
            *)               printf '%s\n' 'silent' ;;
        esac
    }

    # fn: _sgnd_minimal_say_should_print_console - Determine minimal bootstrap console visibility
        # . Purpose
        #   Determine whether a bootstrap message should be written before the full
        #   SolidGroundUX UI layer is loaded.
        #
        # . Parameters
        #   $1 Message type.
        #
        # . Globals (read)
        #   SGND_LOG_LEVEL
        #
        # . Returns
        #   0 if the message should be displayed.
        #   1 if the message should be suppressed.
        #
        # . Usage
        #   _sgnd_minimal_say_should_print_console "example"
    _sgnd_minimal_say_should_print_console() {
        local type="${1^^}"
        local level=""

        level="$(_sgnd_minimal_say_normalize_log_level "${SGND_LOG_LEVEL:-silent}")"

        case "$level" in
            silent)
                return 1
                ;;
            quiet)
                case "$type" in
                    WARN|WARNING|FAIL|ERROR) return 0 ;;
                    *)                       return 1 ;;
                esac
                ;;
            normal)
                case "$type" in
                    START|STRT|OK|WARN|WARNING|FAIL|ERROR|CANCEL|CNCL|END) return 0 ;;
                    *)                                                     return 1 ;;
                esac
                ;;
            verbose)
                case "$type" in
                    DEBUG|TRACE) return 1 ;;
                    *)           return 0 ;;
                esac
                ;;
            debug)
                case "$type" in
                    TRACE) return 1 ;;
                    *)     return 0 ;;
                esac
                ;;
            trace)
                return 0
                ;;
        esac

        return 1
    }

    # fn: say - Emit a minimal bootstrap message
        # . Purpose
        #   Emit a status message before the full SolidGroundUX UI layer is loaded.
        #
        # . Parameters
        #   $1 Message type.
        #   $@ Message text after the type.
        #
        # . Globals (read)
        #   SGND_LOG_LEVEL, MSG_CLR_*, RESET
        #
        # . Output
        #   Writes a formatted message to stderr when allowed by SGND_LOG_LEVEL.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   say "example"
    say() {
        local type="${1^^}"
        local label=""
        local color=""

        shift || true

        _sgnd_minimal_say_should_print_console "$type" || return 0

        case "$type" in
            START|STRT)   label="START";  color="${MSG_CLR_STRT-}" ;;
            INFO)         label="INFO";   color="${MSG_CLR_INFO-}" ;;
            OK)           label="OK";     color="${MSG_CLR_OK-}" ;;
            WARN|WARNING) label="WARN";   color="${MSG_CLR_WARN-}" ;;
            FAIL|ERROR)   label="FAIL";   color="${MSG_CLR_FAIL-}" ;;
            DEBUG)        label="DEBUG";  color="${MSG_CLR_DEBUG-}" ;;
            TRACE)        label="TRACE";  color="${MSG_CLR_DEBUG-}" ;;
            CANCEL|CNCL)  label="CANCEL"; color="${MSG_CLR_CNCL-}" ;;
            END)          label="END";    color="${MSG_CLR_END-}" ;;
            *)            label="$type";  color="${MSG_CLR_EMPTY-}" ;;
        esac

        printf '%s%-6s%s\t%s\n' "$color" "$label" "${RESET-}" "$*" >&2
    }

    # saystart
        # . Purpose
        #   Saystart.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   saystart "Starting SolidGroundUX example"
    saystart()   { say START "$@"; }
    # sayinfo
        # . Purpose
        #   Sayinfo.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   sayinfo "SolidGroundUX example"
    sayinfo()    { say INFO "$@"; }
    # sayok
        # . Purpose
        #   Sayok.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   sayok "Operation completed"
    sayok()      { say OK "$@"; }
    # saywarning
        # . Purpose
        #   Saywarning.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   saywarning "Example warning"
    saywarning() { say WARN "$@"; }
    # sayfail
        # . Purpose
        #   Sayfail.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   sayfail "Example failure"
    sayfail()    { say FAIL "$@"; }
    # saydebug
        # . Purpose
        #   Saydebug.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   saydebug "Example debug message"
    saydebug()   { say DEBUG "$@"; }
    # saycancel
        # . Purpose
        #   Saycancel.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   saycancel "Operation cancelled"
    saycancel()  { say CANCEL "$@"; }
    # sayend
        # . Purpose
        #   Sayend.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   sayend "SolidGroundUX example complete"
    sayend()     { say END "$@"; }

# - Framework path resolution --------------------------------------------------------
    # fn: sgnd_framework_resolve_path - Resolve a Framework-owned path with installed fallback
        # . Purpose
        #   Resolve a Framework-owned file or directory from the active development tree,
        #   falling back to the installed Framework when the active tree does not provide it.
        #
        # . Parameters
        #   $1 Framework-relative path, without a leading slash.
        #   $2 Output variable receiving the resolved absolute path.
        #
        # . Behavior
        #   - Tries SGND_FRAMEWORK_ROOT first.
        #   - When the path is absent and SGND_FRAMEWORK_ROOT is not /, tries /.
        #   - Does not change SGND_FRAMEWORK_ROOT.
        #
        # . Returns
        #   0 when the path exists.
        #   126 when the path cannot be resolved.
        #
        # . Usage
        #   sgnd_framework_resolve_path "usr/local/lib/solidgroundux/common/sgnd-bootstrap.sh" resolved_path
    sgnd_framework_resolve_path() {
        local relative_path="${1#/}"
        local out_var="$2"
        local candidate=""

        if [[ "$SGND_FRAMEWORK_ROOT" == "/" ]]; then
            candidate="/$relative_path"
        elif [[ -e "${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh" ]]; then
            candidate="${SGND_FRAMEWORK_ROOT%/}/$relative_path"
            [[ -e "$candidate" ]] || candidate="/$relative_path"
        else
            candidate="/$relative_path"
        fi

        [[ -e "$candidate" ]] || return 126
        printf -v "$out_var" '%s' "$candidate"
    }

# - Local helpers -------------------------------------------------------------------
    # fn: _load_bootstrapper - Load the SolidGroundUX bootstrap library
        # . Purpose
        #   Resolve and source the main SolidGroundUX bootstrap library.
        #
        # . Behavior
        #   - Uses SGND_FRAMEWORK_ROOT resolved by the executable template.
        #   - Builds the path to sgnd-bootstrap.sh.
        #   - Verifies that the bootstrap library is readable.
        #   - Sources sgnd-bootstrap.sh into the current shell.
        #
        # . Globals (read)
        #   SGND_FRAMEWORK_ROOT
        #
        # . Output
        #   Writes a fatal message to stderr when the bootstrap library cannot be read.
        #
        # . Returns
        #   0 when the bootstrap library was sourced.
        #   126 when the bootstrap library is unreadable.
        #
        # . Usage
        #   _load_bootstrapper || return $?
    _load_bootstrapper(){
        local bootstrap=""

        sgnd_framework_resolve_path \
            "usr/local/lib/solidgroundux/common/sgnd-bootstrap.sh" \
            bootstrap || {
                printf '%s\n' "FATAL: Cannot resolve SolidGroundUX bootstrap library"
                return 126
            }

        [[ -r "$bootstrap" ]] || {
            printf '%s\n' "FATAL: Cannot read bootstrap: $bootstrap"
            return 126
        }
                 
        # shellcheck source=/dev/null
        source "$bootstrap"
    }

# - Public API -------------------------------------------------------------------
    # fn: sgnd_exe_start - Start a SolidGroundUX executable script
        # . Purpose
        #   Run the standard SolidGroundUX executable startup sequence.
        #
        # . Arguments
        #   $@  Command-line arguments passed from the executable main function.
        #
        # . Options
        #   --no-title
        #       Suppress automatic rendering of the standard SolidGroundUX title bar.
        #
        # . Behavior
        #   - Processes executable-runtime options before framework bootstrap.
        #   - Loads the framework bootstrapper.
        #   - Calls sgnd_bootstrap with the remaining supplied arguments.
        #   - Exits when bootstrap fails.
        #   - Handles built-in framework arguments.
        #   - Updates the run mode.
        #   - Prints the standard title bar unless --no-title was supplied.
        #
        # . Side effects
        #   Sources framework libraries, initializes runtime globals, may exit for
        #   info-only built-ins such as --help or --show, and may write the standard
        #   title bar to the terminal.
        #
        # . Returns
        #   0 when startup completed and script-specific logic may continue.
        #
        # . Usage
        #   sgnd_exe_start "$@"
        #   sgnd_exe_start --no-title "$@"
    sgnd_exe_start() {
        local rc=0
        local show_title=1
        local clear_on_start=1
        local -a bootstrap_args=()

        while (($#)); do
            case "$1" in
                --no-title)
                    show_title=0
                    shift
                    ;;
                --no-clear)
                    clear_on_start=0
                    shift
                    ;;
                *)
                    bootstrap_args+=("$1")
                    shift
                    ;;
            esac
        done

        _load_bootstrapper || exit $?

        sgnd_bootstrap "${bootstrap_args[@]}"
        rc=$?

        saydebug "After bootstrap: $rc"
        (( rc != 0 )) && exit "$rc"
        sgnd_builtinarg_handler
        sgnd_update_runmode


        [[ -t 0 && -t 1 ]] && (( clear_on_start )) && sgnd_clear

        (( show_title )) && sgnd_print_titlebar

        return 0
    }


