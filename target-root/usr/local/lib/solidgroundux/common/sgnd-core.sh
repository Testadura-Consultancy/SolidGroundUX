# =====================================================================================
# SolidGroundUX - Core Utilities
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
#   Checksum    : d3177e6e8b58185b46dff63b47b6d61c080c2cf6ab8b4147ba9730bac0640246
#   Source      : sgnd-core.sh
#   Type        : library
#   Group       : Common Core
#   Purpose     : Provide foundational utility functions and shared primitives
#
# Description:
#   Contains the lowest-level generic helpers used throughout the SolidGroundUX
#   framework.
#
#   The library:
#     - Defines generic reusable helper functions
#     - Provides string, array, and low-level utility primitives
#     - Implements shared conventions and diagnostics helpers
#     - Avoids system-, UI-, and business-specific behavior where possible
#
# Design principles:
#   - Keep utilities generic and broadly reusable
#   - Avoid domain-specific logic in core helpers
#   - Prefer clarity and predictability over cleverness
#   - Minimize dependencies to keep the core lightweight
#
# Role in framework:
#   - Foundational layer used by nearly all other libraries
#   - Supports argument parsing, configuration, UI, and script logic
#   - Acts as the lowest-level shared functionality layer
#
# Non-goals:
#   - Business logic or application-specific behavior
#   - UI rendering or user interaction handling
#   - System administration and host/runtime operations (handled in sgnd-system)
#   - Configuration or state management (handled in dedicated modules)
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
        #   ```bash
        #   _sgnd_lib_guard
        #   ```
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
# - Public API ---------------------------------------------------------------------
    # -- Runtime requirements ----------------------------------------------------------
        # fn: sgnd_have - Check whether a command is available on PATH.
            # . Purpose
            #   Check whether a command is available on PATH.
            #
            # . Arguments
            #   $1  Command name.
            #
            # . Returns
            #   0 if the command is found; nonzero otherwise.
            #
            # . Usage
            #   ```bash
            #   sgnd_have bash
            #   ```
        sgnd_have() { command -v "$1" >/dev/null 2>&1; }
        # fn: sgnd_need_cmd - Require a command or exit the current shell script.
            # . Purpose
            #   Require a command or exit the current shell script.
            #
            # . Arguments
            #   $1  Command name.
            #
            # . Side effects
            #   Prints a diagnostic to stderr and exits when missing.
            #
            # . Returns
            #   0 if found; exits with status 1 if missing.
            #
            # . Usage
            #   ```bash
            #   sgnd_need_cmd bash
            #   ```
        sgnd_need_cmd() { sgnd_have "$1" || { printf 'Missing required command: %s\n' "$1" >&2; exit 1; }; }
        # fn: sgnd_need_bash - Require a minimum Bash major version or exit.
            # . Purpose
            #   Require a minimum Bash major version or exit.
            #
            # . Arguments
            #   $1  Optional minimum major version (default 4).
            #
            # . Side effects
            #   Writes a version error to stderr when the requirement is not met.
            #
            # . Returns
            #   0 when Bash meets the requirement; exits with status 1 otherwise.
            #
            # . Usage
            #   ```bash
            #   sgnd_need_bash 4
            #   ```
        sgnd_need_bash() { (( BASH_VERSINFO[0] >= ${1:-4} )) || { printf 'Bash %s+ required.\n' "${1:-4}" >&2; exit 1; }; }
        # fn: sgnd_need_tty - Require standard output to be a terminal.
            # . Purpose
            #   Require standard output to be a terminal.
            #
            # . Side effects
            #   Prints an error to stderr when no stdout TTY is attached.
            #
            # . Returns
            #   0 if stdout is a TTY; 1 otherwise.
            #
            # . Usage
            #   ```bash
            #   sgnd_need_tty
            #   ```
        sgnd_need_tty() { [[ -t 1 ]] || { printf 'No TTY attached.\n' >&2; return 1; }; }
    # -- Filesystem and paths ----------------------------------------------------------
        # fn: sgnd_can_append - Check whether an existing file is writable or a new file can be created.
            # . Purpose
            #   Check whether an existing file is writable or a new file can be created.
            #
            # . Arguments
            #   $1  Target file path.
            #
            # . Side effects
            #   May create missing parent directories during the writability check.
            #
            # . Returns
            #   0 for a writable file/parent; 1 when it cannot be made writable.
            #
            # . Usage
            #   ```bash
            #   sgnd_can_append "/tmp/sgnd-demo/log.txt"
            #   ```
        sgnd_can_append() {
            local f="$1"
            local d

            [[ -n "$f" ]] || return 1
            d="$(dirname -- "$f")"

            if [[ -e "$f" ]]; then
                [[ -f "$f" && -w "$f" ]] || return 1
                return 0
            fi

            if [[ -d "$d" ]]; then
                [[ -w "$d" ]] || return 1
                return 0
            fi

            mkdir -p -- "$d" 2>/dev/null || return 1
            [[ -w "$d" ]] || return 1
            return 0
        }
        # fn: sgnd_ensure_dir - Ensure a named directory exists.
            # . Purpose
            #   Ensure a named directory exists.
            #
            # . Arguments
            #   $1  Directory path.
            #
            # . Side effects
            #   Creates a missing directory and its parents.
            #
            # . Returns
            #   0 if present or created; 2 if the path is empty; otherwise mkdir status.
            #
            # . Usage
            #   ```bash
            #   sgnd_ensure_dir "/tmp/sgnd-demo"
            #   ```
        sgnd_ensure_dir() {
            local dir="${1:-}"
            [[ -n "$dir" ]] || return 2
            [[ -d "$dir" ]] || mkdir -p -- "$dir"
        }
        # fn: sgnd_abs_path - Resolve a path using readlink -f or realpath.
            # . Purpose
            #   Resolve a path using readlink -f or realpath.
            #
            # . Arguments
            #   $1  Path to resolve.
            #
            # . Output
            #   Prints the canonical absolute path.
            #
            # . Returns
            #   0 when resolved; 127 if neither utility is available; otherwise realpath status.
            #
            # . Usage
            #   ```bash
            #   sgnd_abs_path "/tmp/../tmp"
            #   ```
        sgnd_abs_path() {
            if sgnd_have readlink; then
                readlink -f -- "$1" 2>/dev/null && return 0
            fi

            if sgnd_have realpath; then
                realpath -- "$1"
                return $?
            fi

            return 127
        }
        # fn: sgnd_mktemp_dir - Create a unique temporary directory.
            # . Purpose
            #   Create a unique temporary directory.
            #
            # . Output
            #   Prints the new directory path.
            #
            # . Returns
            #   Status returned by mktemp.
            #
            # . Usage
            #   ```bash
            #   temp_dir="$(sgnd_mktemp_dir)"
            #   ```
        sgnd_mktemp_dir() { mktemp -d 2>/dev/null || TMPDIR=${TMPDIR:-/tmp} mktemp -d "${TMPDIR%/}/XXXXXX"; }
        # fn: sgnd_mktemp_file - Create a unique temporary file inside TMPDIR.
            # . Purpose
            #   Create a unique temporary file inside TMPDIR.
            #
            # . Output
            #   Prints the new file path.
            #
            # . Returns
            #   Status returned by mktemp.
            #
            # . Usage
            #   ```bash
            #   temp_file="$(sgnd_mktemp_file)"
            #   ```
        sgnd_mktemp_file() { TMPDIR=${TMPDIR:-/tmp} mktemp "${TMPDIR%/}/XXXXXX"; }
    # -- Values and variables ---------------------------------------------------------
        # fn: sgnd_slugify - Normalize arbitrary text into a lowercase filename slug.
            # . Purpose
            #   Normalize arbitrary text into a lowercase filename slug.
            #
            # . Description
            #   Whitespace becomes hyphens; repeated hyphens and leading/trailing hyphens are removed.
            #
            # . Arguments
            #   $1  Text to normalize.
            #
            # . Output
            #   Lowercase letters, digits, hyphen, underscore and dot; falls back to hub for empty results.
            #
            # . Returns
            #   0 after printing the slug.
            #
            # . Usage
            #   ```bash
            #   sgnd_slugify "My New Site"
            #   ```
        sgnd_slugify() {
            local s="${1:-}"

            s="${s,,}"
            s="$(printf '%s' "$s" | tr -s '[:space:]' '-')"
            s="$(printf '%s' "$s" | tr -cd 'a-z0-9-_.')"

            while [[ "$s" == *--* ]]; do
                s="${s//--/-}"
            done

            s="${s#-}"
            s="${s%-}"

            [[ -n "$s" ]] || s="hub"
            printf '%s' "$s"
        }
        # fn: sgnd_hash_sha256_file - Calculate the SHA-256 checksum of a readable file.
            # . Purpose
            #   Calculate the SHA-256 checksum of a readable file.
            #
            # . Arguments
            #   $1  File path.
            #
            # . Output
            #   Prints the hex digest followed by a newline.
            #
            # . Returns
            #   0 when hashed; 2 for unreadable file; 3 for hashing errors; 127 if hashing tools are missing.
            #
            # . Usage
            #   ```bash
            #   sgnd_hash_sha256_file "/tmp/sgnd-demo.cfg"
            #   ```
        sgnd_hash_sha256_file() {
            local file="$1"
            local out

            [[ -r "$file" ]] || return 2

            if sgnd_have sha256sum; then
                out="$(sha256sum "$file")" || return 3
                printf '%s\n' "${out%% *}"
                return 0
            fi

            if sgnd_have shasum; then
                out="$(shasum -a 256 "$file")" || return 3
                printf '%s\n' "${out%% *}"
                return 0
            fi

            return 127
        }
        # fn: sgnd_safe_replace_file - Replace a destination with a prepared file while retaining its mode.
            # . Purpose
            #   Replace a destination with a prepared file while retaining its mode.
            #
            # . Arguments
            #   $1  Prepared source file.
            #   $2  Existing destination file.
            #
            # . Side effects
            #   Copies the destination file mode onto the source and moves it over the destination.
            #
            # . Returns
            #   0 when moved; 1 if either file is absent or chmod/mv fails.
            #
            # . Usage
            #   ```bash
            #   sgnd_safe_replace_file "$temp_file" "$config_file"
            #   ```
        sgnd_safe_replace_file() {
            local src="${1:?missing source}"
            local dst="${2:?missing destination}"

            [[ -e "$src" ]] || return 1
            [[ -e "$dst" ]] || return 1

            chmod --reference="$dst" "$src" || return 1
            mv "$src" "$dst" || return 1
        }    
        # fn: sgnd_is_set - Test whether a named shell variable has been declared.
            # . Purpose
            #   Test whether a named shell variable has been declared.
            #
            # . Arguments
            #   $1  Variable name.
            #
            # . Returns
            #   0 if declared (even if empty); 1 otherwise.
            #
            # . Usage
            #   ```bash
            #   sgnd_is_set SGND_UI_STYLE
            #   ```
        sgnd_is_set() { [[ -v "$1" ]]; }
        # fn: sgnd_default - Set a named shell variable to a default when unset or empty.
            # . Purpose
            #   Set a named shell variable to a default when unset or empty.
            #
            # . Arguments
            #   $1  Name of shell variable.
            #   $2  Default value (optional).
            #
            # . Side effects
            #   Modifies the named shell variable using a nameref.
            #
            # . Returns
            #   0 after checking or assigning the value.
            #
            # . Usage
            #   ```bash
            #   sgnd_default SGND_UI_STYLE default
            #   ```
        sgnd_default() {
            local name="$1"
            local default="${2-}"
            local -n ref="$name"

            [[ -n "${ref:-}" ]] || ref="$default"
        }
        # fn: sgnd_is_number - Test whether text contains digits only.
            # . Purpose
            #   Test whether text contains digits only.
            #
            # . Arguments
            #   $1  Text to validate.
            #
            # . Returns
            #   0 if it matches one or more digits; 1 otherwise.
            #
            # . Usage
            #   ```bash
            #   sgnd_is_number "42"
            #   ```
        sgnd_is_number() { [[ "$1" =~ ^[0-9]+$ ]]; }
        # fn: sgnd_array_has_items - Test whether a named array exists and is nonempty.
            # . Purpose
            #   Test whether a named array exists and is nonempty.
            #
            # . Arguments
            #   $1  Name of a declared array.
            #
            # . Returns
            #   0 if it contains at least one item; 1 otherwise.
            #
            # . Usage
            #   ```bash
            #   rows=("Ada|admin")
            #   sgnd_array_has_items rows
            #   ```
        sgnd_array_has_items() {
            declare -p "$1" &>/dev/null || return 1
            local -n _arr="$1"
            (( ${#_arr[@]} > 0 ))
        }
        # fn: sgnd_is_true - Interpret common affirmative values as true.
            # . Purpose
            #   Interpret common affirmative values as true.
            #
            # . Arguments
            #   $1  Value to check; case-insensitive.
            #
            # . Returns
            #   0 for y, yes, 1 or true; 1 for everything else.
            #
            # . Usage
            #   ```bash
            #   sgnd_is_true yes
            #   ```
        sgnd_is_true() {
            case "${1,,}" in
                y|yes|1|true) return 0 ;;
                *)            return 1 ;;
            esac
        }
    # -- Process and runtime ----------------------------------------------------------
        # fn: sgnd_proc_exists - Test for a running process with an exact executable name.
            # . Purpose
            #   Test for a running process with an exact executable name.
            #
            # . Arguments
            #   $1  Executable name as matched by pgrep -x.
            #
            # . Returns
            #   0 if found; nonzero otherwise.
            #
            # . Usage
            #   ```bash
            #   sgnd_proc_exists sshd
            #   ```
        sgnd_proc_exists() { pgrep -x "$1" &>/dev/null; }
        # fn: sgnd_wait_for_exit - Wait until no process has the specified executable name.
            # . Purpose
            #   Wait until no process has the specified executable name.
            #
            # . Arguments
            #   $1  Process executable name.
            #   $2  Optional poll interval in seconds (default 0.5).
            #
            # . Side effects
            #   Sleeps between checks; there is no timeout.
            #
            # . Returns
            #   0 when the matching process is no longer running.
            #
            # . Usage
            #   ```bash
            #   sgnd_wait_for_exit sshd 1
            #   ```
        sgnd_wait_for_exit() {
            local name="$1"
            local interval="${2:-0.5}"

            while sgnd_proc_exists "$name"; do
                sleep "$interval"
            done
        }
        # fn: sgnd_kill_if_running - Send the default pkill signal to exact-name processes if present.
            # . Purpose
            #   Send the default pkill signal to exact-name processes if present.
            #
            # . Arguments
            #   $1  Executable name.
            #
            # . Side effects
            #   Calls pkill -x and ignores its error status.
            #
            # . Returns
            #   0 regardless of whether a match was found.
            #
            # . Usage
            #   ```bash
            #   sgnd_kill_if_running sgnd-example-process
            #   ```
        sgnd_kill_if_running() { pkill -x "$1" &>/dev/null || true; }
    # -- Diagnostics and execution ----------------------------------------------------
        # fn: sgnd_caller_id - Format caller location information for diagnostics.
            # . Purpose
            #   Format caller location information for diagnostics.
            #
            # . Arguments
            #   $1  Optional call-stack depth (default 1).
            #
            # . Output
            #   Prints basename:line (function).
            #
            # . Returns
            #   0 after printing the identity.
            #
            # . Usage
            #   ```bash
            #   sgnd_caller_id 1
            #   ```
        sgnd_caller_id() {
            local depth="${1:-1}"
            local file="${BASH_SOURCE[$depth]}"
            local func="${FUNCNAME[$depth]}"
            local line="${BASH_LINENO[$((depth-1))]}"

            printf '%s:%s (%s)' "${file##*/}" "$line" "$func"
        }
        # fn: sgnd_stack_trace - Print the current Bash function call stack.
            # . Purpose
            #   Print the current Bash function call stack.
            #
            # . Output
            #   Writes one at file:line (function) entry per stack frame.
            #
            # . Returns
            #   0 after printing.
            #
            # . Usage
            #   ```bash
            #   sgnd_stack_trace
            #   ```
        sgnd_stack_trace() {
            local i
            for (( i=1; i<${#FUNCNAME[@]}; i++ )); do
                printf '  at %s:%s (%s)\n' \
                    "${BASH_SOURCE[$i]##*/}" \
                    "${BASH_LINENO[$((i-1))]}" \
                    "${FUNCNAME[$i]}"
            done
        }
        # fn: sgnd_has_tty - Check whether the controlling terminal is readable and writable.
            # . Purpose
            #   Check whether the controlling terminal is readable and writable.
            #
            # . Returns
            #   0 when /dev/tty is accessible for both operations; 1 otherwise.
            #
            # . Usage
            #   ```bash
            #   sgnd_has_tty
            #   ```
        sgnd_has_tty() { [[ -r /dev/tty && -w /dev/tty ]]; }
        # fn: sgnd_is_ui_mode - Check whether interactive UI mode is permitted and available.
            # . Purpose
            #   Check whether interactive UI mode is permitted and available.
            #
            # . Description
            #   FLAG_NOUI and FLAG_BATCH take priority over FLAG_UI; otherwise checks both stdin and stdout TTYs.
            #
            # . Returns
            #   0 for enabled UI or interactive stdin/stdout; 1 when disabled or batch.
            #
            # . Usage
            #   ```bash
            #   sgnd_is_ui_mode
            #   ```
        sgnd_is_ui_mode() {
            # Explicit overrides first (future-proof)
            (( ${FLAG_NOUI:-0} ))   && return 1
            (( ${FLAG_BATCH:-0} ))  && return 1
            (( ${FLAG_UI:-0} ))     && return 0

            # Fallback: interactive terminal
            [[ -t 0 && -t 1 ]]
        }
        # fn: sgnd_is_desktop_mode - Check whether DISPLAY or WAYLAND_DISPLAY is set.
            # . Purpose
            #   Check whether DISPLAY or WAYLAND_DISPLAY is set.
            #
            # . Returns
            #   0 when either variable is nonempty; 1 otherwise.
            #
            # . Usage
            #   ```bash
            #   sgnd_is_desktop_mode
            #   ```
        sgnd_is_desktop_mode() {
            [[ -n "${DISPLAY:-}" ]] && return 0
            [[ -n "${WAYLAND_DISPLAY:-}" ]] && return 0
            return 1
        }
        # fn: sgnd_internal_call_guard - Warn when an internal helper is called outside the framework API.
            # . Purpose
            #   Warn when an internal helper is called outside the framework API.
            #
            # . Arguments
            #   $1  Name of the internal function.
            #
            # . Side effects
            #   Prints a warning to stderr for callers outside sgnd_* and _* functions; does not block the call.
            #
            # . Returns
            #   0 for allowed callers; the warning branch also returns successfully.
            #
            # . Usage
            #   ```bash
            #   sgnd_internal_call_guard _sgnd_internal_helper
            #   ```
        sgnd_internal_call_guard() {
            local func="${1:?missing function name}"

            case "${FUNCNAME[1]}" in
                sgnd_*) return 0 ;;   # called from public function → OK
                _*)     return 0 ;;   # called from another internal → OK
                *)
                    printf "WARN: Internal function '%s' called from outside API\n" "$func" >&2
                    ;;
            esac
        }
        # fn: sgnd_show_vars_by_prefix - Log shell variables whose names start with a supplied prefix.
            # . Purpose
            #   Log shell variables whose names start with a supplied prefix.
            #
            # . Arguments
            #   $1  Nonempty variable-name prefix.
            #   $2  Optional flag to also print through sayinfo when debug is disabled.
            #
            # . Side effects
            #   Uses saydebug and optionally sayinfo to emit matching variable names/values.
            #
            # . Returns
            #   0 after logging; 1 when the prefix is missing.
            #
            # . Usage
            #   ```bash
            #   sgnd_show_vars_by_prefix SGND_DT_ 1
            #   ```
        sgnd_show_vars_by_prefix() {
            local prefix="${1:-}"
            local assume_debug="${2:-0}"

            [[ -n "$prefix" ]] || {
                sayerror "No prefix provided"
                return 1
            }

            local var

            while read -r var; do
                saydebug "$var = ${!var}"

                if [[ "${SGND_LOG_LEVEL:-normal}" != "debug" ]] && (( assume_debug )); then
                    sayinfo "$var = ${!var}"
                fi
            done < <(compgen -v | grep -E "^${prefix}")

            return 0
        }
        # fn: sgnd_version_ge - Test whether the first version sorts at or above the second.
            # . Purpose
            #   Test whether the first version sorts at or above the second.
            #
            # . Arguments
            #   $1  Current version.
            #   $2  Minimum required version.
            #
            # . Returns
            #   0 if the first version is greater or equal according to sort -V; 1 otherwise.
            #
            # . Usage
            #   ```bash
            #   sgnd_version_ge "2.2" "2.1"
            #   ```
        sgnd_version_ge() { [[ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]; }
        # fn: sgnd_timestamp - Print the current local timestamp in log format.
            # . Purpose
            #   Print the current local timestamp in log format.
            #
            # . Output
            #   Prints YYYY-MM-DD HH:MM:SS.
            #
            # . Returns
            #   0 on success; otherwise date command status.
            #
            # . Usage
            #   ```bash
            #   sgnd_timestamp
            #   ```
        sgnd_timestamp() { date +"%Y-%m-%d %H:%M:%S"; }
        # fn: sgnd_retry - Retry a command a fixed number of times with a delay.
            # . Purpose
            #   Retry a command a fixed number of times with a delay.
            #
            # . Arguments
            #   $1  Maximum attempts (at least 1).
            #   $2  Delay between attempts, in seconds.
            #   $3...  Executable command and its arguments.
            #
            # . Side effects
            #   Executes the command up to the specified limit and sleeps between failed attempts.
            #
            # . Returns
            #   0 when the command succeeds; 1 when all attempts fail; 2 for invalid count or missing command.
            #
            # . Usage
            #   ```bash
            #   sgnd_retry 3 1 test -f "/tmp/ready.flag"
            #   ```
        sgnd_retry() {
            local n="$1"
            local d="$2"
            local i

            shift 2
            (( n >= 1 )) || return 2
            (( $# >= 1 )) || return 2

            for (( i=1; i<=n; i++ )); do
                "$@" && return 0
                (( i < n )) && sleep "$d"
            done

            return 1
        }
    # -- Collections and strings ------------------------------------------------------
        # fn: sgnd_join - Join positional arguments with a literal delimiter.
            # . Purpose
            #   Join positional arguments with a literal delimiter.
            #
            # . Arguments
            #   $1  Delimiter.
            #   $2...  Values to join.
            #
            # . Output
            #   Writes the joined values without a newline.
            #
            # . Returns
            #   0 after printing.
            #
            # . Usage
            #   ```bash
            #   sgnd_join "," alpha beta gamma
            #   ```
        sgnd_join() {
            local IFS="$1"
            shift
            printf '%s' "$*"
        }
        # fn: sgnd_array_union - Populate a named destination array with unique items from source arrays.
            # . Purpose
            #   Populate a named destination array with unique items from source arrays.
            #
            # . Arguments
            #   $1  Name of destination array.
            #   $2...  Names of one or more source arrays.
            #
            # . Side effects
            #   Resets the destination array and inserts first occurrences only.
            #
            # . Returns
            #   0 after combining arrays; 1 if no destination or source argument is given.
            #
            # . Usage
            #   ```bash
            #   left=(alpha beta)
            #   right=(beta gamma)
            #   combined=()
            #   sgnd_array_union combined left right
            #   ```
        sgnd_array_union() {
            local dest_name="$1"
            local src_name
            local item
            local -A _seen=()

            shift || true
            [[ -n "${dest_name:-}" && $# -ge 1 ]] || return 1

            local -n _dest="$dest_name"
            _dest=()

            for src_name in "$@"; do
                [[ -n "${src_name:-}" ]] || continue
                declare -p "$src_name" >/dev/null 2>&1 || continue

                local -n _src="$src_name"
                for item in "${_src[@]:-}"; do
                    [[ -n "${item:-}" ]] || continue
                    if [[ -z "${_seen[$item]+x}" ]]; then
                        _dest+=( "$item" )
                        _seen["$item"]=1
                    fi
                done
            done

            return 0
        }
        # fn: sgnd_trim - Trim whitespace from both ends of a string.
            # . Purpose
            #   Trim whitespace from both ends of a string.
            #
            # . Arguments
            #   $@  Words to trim, joined by spaces.
            #
            # . Output
            #   Prints trimmed text without a newline.
            #
            # . Returns
            #   0 after printing.
            #
            # . Usage
            #   ```bash
            #   sgnd_trim "  hello world  "
            #   ```
        sgnd_trim() {
            local v="${*:-}"
            v="${v#"${v%%[![:space:]]*}"}"
            printf '%s' "${v%"${v##*[![:space:]]}"}"
        }
        # fn: sgnd_string_repeat - Repeat a string a specified number of times.
            # . Purpose
            #   Repeat a string a specified number of times.
            #
            # . Arguments
            #   $1  String to repeat (default a space).
            #   $2  Repeat count (default 0).
            #
            # . Output
            #   Writes the repeated string without a newline.
            #
            # . Returns
            #   0 after printing.
            #
            # . Usage
            #   ```bash
            #   sgnd_string_repeat "-" 5
            #   ```
        sgnd_string_repeat() {
            local s="${1- }"
            local n="${2-0}"
            local out=""
            local i=0

            (( n > 0 )) || { printf '%s' ""; return 0; }

            for (( i=0; i<n; i++ )); do
                out+="$s"
            done

            printf '%s' "$out"
        }
        # fn: sgnd_fill_left - Left-pad text with a character to a minimum width.
            # . Purpose
            #   Left-pad text with a character to a minimum width.
            #
            # . Arguments
            #   $1  Text.
            #   $2  Target width (default 20).
            #   $3  Pad string (default space).
            #
            # . Output
            #   Writes padded text without a newline.
            #
            # . Returns
            #   0 after printing.
            #
            # . Usage
            #   ```bash
            #   sgnd_fill_left "42" 5 "0"
            #   ```
        sgnd_fill_left() {
            local source="${1-}"
            local maxlength="${2-20}"
            local char="${3- }"
            local padcount=$(( maxlength - ${#source} ))
            local pad

            (( padcount > 0 )) || { printf '%s' "$source"; return 0; }
            pad="$(sgnd_string_repeat "$char" "$padcount")"
            printf '%s%s' "$pad" "$source"
        }
        # fn: sgnd_fill_right - Right-pad text with a character to a minimum width.
            # . Purpose
            #   Right-pad text with a character to a minimum width.
            #
            # . Arguments
            #   $1  Text.
            #   $2  Target width (default 20).
            #   $3  Pad string (default space).
            #
            # . Output
            #   Writes padded text without a newline.
            #
            # . Returns
            #   0 after printing.
            #
            # . Usage
            #   ```bash
            #   sgnd_fill_right "Ada" 8 "."
            #   ```
        sgnd_fill_right() {
            local source="${1-}"
            local maxlength="${2-20}"
            local char="${3- }"
            local padcount=$(( maxlength - ${#source} ))
            local pad

            (( padcount > 0 )) || { printf '%s' "$source"; return 0; }
            pad="$(sgnd_string_repeat "$char" "$padcount")"
            printf '%s%s' "$source" "$pad"
        }
        # fn: sgnd_fill_center - Center text to a minimum width using a padding string.
            # . Purpose
            #   Center text to a minimum width using a padding string.
            #
            # . Arguments
            #   $1  Text.
            #   $2  Target width (default 20).
            #   $3  Pad string (default space).
            #
            # . Output
            #   Writes padded text without a newline.
            #
            # . Returns
            #   0 after printing.
            #
            # . Usage
            #   ```bash
            #   sgnd_fill_center "Title" 15 "-"
            #   ```
        sgnd_fill_center() {
            local source="${1-}"
            local maxlength="${2-20}"
            local char="${3- }"
            local padcount=$(( maxlength - ${#source} ))
            local left
            local right
            local pad_left
            local pad_right

            (( padcount > 0 )) || { printf '%s' "$source"; return 0; }

            left=$(( padcount / 2 ))
            right=$(( padcount - left ))
            pad_left="$(sgnd_string_repeat "$char" "$left")"
            pad_right="$(sgnd_string_repeat "$char" "$right")"

            printf '%s%s%s' "$pad_left" "$source" "$pad_right"
        }
    # -- Terminal text layout ---------------------------------------------------------
        # fn: sgnd_visible_length - Count display characters after removing ANSI SGR escapes.
            # . Purpose
            #   Count display characters after removing ANSI SGR escapes.
            #
            # . Arguments
            #   $1  Text, potentially containing ANSI styling.
            #
            # . Output
            #   Writes the count to stdout.
            #
            # . Returns
            #   0 after counting.
            #
            # . Usage
            #   ```bash
            #   sgnd_visible_length "$colored_text"
            #   ```
        sgnd_visible_length() {
            local text="${1-}"

            text="$(printf '%s' "$text" | sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g')"
            printf '%s' "$text" | wc -m
        }
        # fn: sgnd_terminal_width - Compute the effective terminal render width.
            # . Purpose
            #   Compute the effective terminal render width.
            #
            # . Description
            #   Uses tput cols when available and falls back to 80 when no valid result is returned.
            #
            # . Output
            #   Writes a number clamped between 40 and SGND_MAX_RENDER_WIDTH (default 140).
            #
            # . Returns
            #   0 after printing the width.
            #
            # . Usage
            #   ```bash
            #   sgnd_terminal_width
            #   ```
        sgnd_terminal_width() {
            local term_width=80
            local max_render_width="${SGND_MAX_RENDER_WIDTH:-140}"

            if sgnd_have tput; then
                term_width="$(tput cols 2>/dev/null || printf '80')"
            fi
            [[ "$term_width" =~ ^[0-9]+$ ]] || term_width=80

            (( term_width > max_render_width )) && term_width="$max_render_width"
            (( term_width < 40 )) && term_width=40

            printf '%s\n' "$term_width"
        }
        # fn: sgnd_padded_visible - Right-pad styled text using its visible character width.
            # . Purpose
            #   Right-pad styled text using its visible character width.
            #
            # . Arguments
            #   $1  Text, possibly ANSI-colored.
            #   $2  Minimum visible width.
            #
            # . Output
            #   Writes text plus trailing spaces without a newline.
            #
            # . Returns
            #   0 after writing the string.
            #
            # . Usage
            #   ```bash
            #   sgnd_padded_visible "$colored_label" 20
            #   ```
        sgnd_padded_visible() {
            local text="${1-}"
            local width="${2:-0}"
            local visible_len=0
            local pad_len=0

            visible_len="$(sgnd_visible_length "$text")"
            pad_len=$(( width - visible_len ))
            (( pad_len < 0 )) && pad_len=0

            printf '%s%*s' "$text" "$pad_len" ""
        }
        # fn: sgnd_wrap_words - Wrap a string into lines of a given display width.
            # . Purpose
            #   Wrap a string into lines of a given display width.
            #
            # . Arguments
            #   --width N  Target width (default 80).
            #   --text TEXT  Text to wrap.
            #
            # . Output
            #   Writes one or more text lines to stdout.
            #
            # . Returns
            #   0 after printing; 2 on unknown argument.
            #
            # . Usage
            #   ```bash
            #   sgnd_wrap_words --width 40 --text "A rather long message to be wrapped"
            #   ```
        sgnd_wrap_words() {
            local width=80
            local text=""
            local line=""
            local word=""

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --width) width="$2"; shift 2 ;;
                    --text)  text="$2"; shift 2 ;;
                    --) shift; break ;;
                    *) return 2 ;;
                esac
            done

            [[ -z "$text" ]] && return 0
            (( width < 1 )) && printf '%s\n' "$text" && return 0

            while read -r word; do
                if [[ -z "$line" ]]; then
                    line="$word"
                elif (( ${#line} + 1 + ${#word} <= width )); then
                    line+=" $word"
                else
                    printf '%s\n' "$line"
                    line="$word"
                fi
            done < <(printf '%s\n' "$text" | tr -s '[:space:]' '\n')

            [[ -n "$line" ]] && printf '%s\n' "$line"
        }
    # -- Validation -------------------------------------------------------------------
    # fn: sgnd_validate_ipv4 - Check IPv4 dotted-quad syntax and octet ranges.
        # . Purpose
        #   Check IPv4 dotted-quad syntax and octet ranges.
        #
        # . Arguments
        #   $1  Candidate IPv4 address.
        #
        # . Returns
        #   0 for exactly four decimal octets between 0 and 255; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_ipv4 "192.168.0.10"
        #   ```
    sgnd_validate_ipv4() {
        local ip="$1"
        local IFS='.'
        local octets
        local o

        read -r -a octets <<<"$ip"
        [[ ${#octets[@]} -eq 4 ]] || return 1

        for o in "${octets[@]}"; do
            [[ "$o" =~ ^[0-9]+$ ]] || return 1
            (( o >= 0 && o <= 255 )) || return 1
        done

        return 0
    }
    # fn: sgnd_validate_yesno - Validate a one-character Y or N choice.
        # . Purpose
        #   Validate a one-character Y or N choice.
        #
        # . Arguments
        #   $1  Candidate value.
        #
        # . Returns
        #   0 for Y/y/N/n; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_yesno y
        #   ```
    sgnd_validate_yesno() { [[ "$1" =~ ^[YyNn]$ ]]; }
    # fn: sgnd_validate_int - Test whether a string is a signed integer.
        # . Purpose
        #   Test whether a string is a signed integer.
        #
        # . Arguments
        #   $1  Candidate value.
        #
        # . Returns
        #   0 for an optional minus sign followed by digits; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_int "-42"
        #   ```
    sgnd_validate_int() { [[ "$1" =~ ^-?[0-9]+$ ]]; }
    # fn: sgnd_validate_numeric - Test whether a string is a signed integer or decimal.
        # . Purpose
        #   Test whether a string is a signed integer or decimal.
        #
        # . Arguments
        #   $1  Candidate numeric value.
        #
        # . Returns
        #   0 for digits with an optional preceding minus and optional decimal fraction; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_numeric "-42.5"
        #   ```
    sgnd_validate_numeric() { [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; }
    # fn: sgnd_validate_text - Check that a string is not empty.
        # . Purpose
        #   Check that a string is not empty.
        #
        # . Arguments
        #   $1  Candidate text.
        #
        # . Returns
        #   0 if nonempty (including whitespace-only strings); 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_text "Hello"
        #   ```
    sgnd_validate_text() { [[ -n "$1" ]]; }
    # fn: sgnd_validate_bool - Validate a recognized textual boolean token.
        # . Purpose
        #   Validate a recognized textual boolean token.
        #
        # . Description
        #   This validates both affirmative and negative values; use sgnd_is_true to test truthiness.
        #
        # . Arguments
        #   $1  Candidate token, case-insensitive.
        #
        # . Returns
        #   0 for y/yes/n/no/true/false/1/0; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_bool "false"
        #   ```
    sgnd_validate_bool() {
        case "${1,,}" in
            y|yes|n|no|true|false|1|0) return 0 ;;
            *) return 1 ;;
        esac
    }
    # fn: sgnd_validate_date - Validate the shape of an ISO calendar date.
        # . Purpose
        #   Validate the shape of an ISO calendar date.
        #
        # . Description
        #   Checks the string pattern only; does not verify that the date exists.
        #
        # . Arguments
        #   $1  Candidate YYYY-MM-DD string.
        #
        # . Returns
        #   0 for a syntactically matching date string; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_date "2026-10-29"
        #   ```
    sgnd_validate_date() { [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; }
    # fn: sgnd_validate_cidr - Validate a CIDR prefix length, not a network address.
        # . Purpose
        #   Validate a CIDR prefix length, not a network address.
        #
        # . Arguments
        #   $1  Prefix length in decimal notation.
        #
        # . Returns
        #   0 for a number from 0 to 32; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_cidr 24
        #   ```
    sgnd_validate_cidr() { [[ "$1" =~ ^([0-9]|[12][0-9]|3[0-2])$ ]]; }
    # fn: sgnd_validate_slug - Check a lowercase slug against allowed characters.
        # . Purpose
        #   Check a lowercase slug against allowed characters.
        #
        # . Arguments
        #   $1  Slug.
        #
        # . Returns
        #   0 for one or more lowercase ASCII letters, digits, periods, underscores or hyphens; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_slug sgnd-docs
        #   ```
    sgnd_validate_slug() { [[ "$1" =~ ^[a-z0-9._-]+$ ]]; }
    # fn: sgnd_validate_fs_name - Check a conservative single filesystem component.
        # . Purpose
        #   Check a conservative single filesystem component.
        #
        # . Description
        #   This checks allowed characters only, not special names or path traversal safety.
        #
        # . Arguments
        #   $1  Candidate name.
        #
        # . Returns
        #   0 for one or more ASCII letters, digits, periods, underscores or hyphens; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_fs_name Framework_2.2
        #   ```
    sgnd_validate_fs_name() { [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]; }
    # fn: sgnd_validate_file_exists - Test whether a path refers to an existing regular file.
        # . Purpose
        #   Test whether a path refers to an existing regular file.
        #
        # . Arguments
        #   $1  Path to test.
        #
        # . Returns
        #   0 for an existing regular file; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_file_exists "/etc/hosts"
        #   ```
    sgnd_validate_file_exists() {
        local path="$1"
        [[ -f "$path" ]]
    }
    # fn: sgnd_validate_path_exists - Test whether a filesystem path exists.
        # . Purpose
        #   Test whether a filesystem path exists.
        #
        # . Arguments
        #   $1  Path to test.
        #
        # . Returns
        #   0 when -e matches; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_path_exists "/tmp"
        #   ```
    sgnd_validate_path_exists() { [[ -e "$1" ]]; }
    # fn: sgnd_validate_dir_exists - Test whether a path is an existing directory.
        # . Purpose
        #   Test whether a path is an existing directory.
        #
        # . Arguments
        #   $1  Directory to test.
        #
        # . Returns
        #   0 when -d matches; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_dir_exists "/tmp"
        #   ```
    sgnd_validate_dir_exists() { [[ -d "$1" ]]; }
    # fn: sgnd_validate_executable - Test whether a filesystem path is executable.
        # . Purpose
        #   Test whether a filesystem path is executable.
        #
        # . Arguments
        #   $1  Path to test.
        #
        # . Returns
        #   0 when the path is executable; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_executable "/bin/bash"
        #   ```
    sgnd_validate_executable() { [[ -x "$1" ]]; }
    # fn: sgnd_validate_file_not_exists - Check that a regular file does not already exist.
        # . Purpose
        #   Check that a regular file does not already exist.
        #
        # . Arguments
        #   $1  Path to test.
        #
        # . Returns
        #   0 when the path is not an existing regular file; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_validate_file_not_exists "/tmp/sgnd-new-file"
        #   ```
    sgnd_validate_file_not_exists() { [[ ! -f "$1" ]]; }
