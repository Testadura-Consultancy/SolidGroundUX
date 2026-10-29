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
# - Public API ---------------------------------------------------------------------
    # -- Runtime requirements ----------------------------------------------------------
        # fn: sgnd_have - Have
            # . Purpose
            #   Check whether a command is available on PATH.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_have "bash" && printf 'bash is available\n'
        sgnd_have() { command -v "$1" >/dev/null 2>&1; }
        # fn: sgnd_need_cmd - Need cmd
            # . Purpose
            #   Require a command to exist or terminate the current script.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
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
            #   sgnd_need_cmd "bash"
        sgnd_need_cmd() { sgnd_have "$1" || { printf 'Missing required command: %s\n' "$1" >&2; exit 1; }; }
        # fn: sgnd_need_bash - Need bash
            # . Purpose
            #   Require a minimum Bash major version.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  4 - Positional value used by this function.
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
            #   sgnd_need_bash "${4}"
        sgnd_need_bash() { (( BASH_VERSINFO[0] >= ${1:-4} )) || { printf 'Bash %s+ required.\n' "${1:-4}" >&2; exit 1; }; }
        # fn: sgnd_need_tty - Need tty
            # . Purpose
            #   Require stdout to be attached to a terminal.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
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
            #   sgnd_need_tty
        sgnd_need_tty() { [[ -t 1 ]] || { printf 'No TTY attached.\n' >&2; return 1; }; }
    # -- Filesystem and paths ----------------------------------------------------------
        # fn: sgnd_can_append - Can append
            # . Purpose
            #   Check whether a file can be appended to, creating its parent path if needed.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  F - Positional value used by this function.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success.
            #   Non-zero when validation, resolution, user cancellation, or execution fails.
            #
            # . Usage
            #   sgnd_can_append "example" && printf 'Success\n' || printf 'Failed\n'
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
        # fn: sgnd_ensure_dir - Ensure dir
            # . Purpose
            #   Create a directory when it does not already exist.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  DIR - Directory path.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_ensure_dir "/tmp/sgnd-example"
        sgnd_ensure_dir() {
            local dir="${1:-}"
            [[ -n "$dir" ]] || return 2
            [[ -d "$dir" ]] || mkdir -p -- "$dir"
        }
        # fn: sgnd_abs_path - Abs path
            # . Purpose
            #   Resolve a path to an absolute path.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_abs_path "/tmp"
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
        # fn: sgnd_mktemp_dir - Mktemp dir
            # . Purpose
            #   Create and print a temporary directory path.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_mktemp_dir
        sgnd_mktemp_dir() { mktemp -d 2>/dev/null || TMPDIR=${TMPDIR:-/tmp} mktemp -d "${TMPDIR%/}/XXXXXX"; }
        # fn: sgnd_mktemp_file - Mktemp file
            # . Purpose
            #   Create and print a temporary file path.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   temp_file="$(sgnd_mktemp_file)"; printf '%s\n' "$temp_file"
        sgnd_mktemp_file() { TMPDIR=${TMPDIR:-/tmp} mktemp "${TMPDIR%/}/XXXXXX"; }
    # -- Values and variables ---------------------------------------------------------
        # fn: sgnd_slugify - Slugify
            # . Purpose
            #   Convert text to a lowercase filesystem-friendly slug.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  S - Positional value used by this function.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_slugify "solidgroundux-example"
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
        # fn: sgnd_hash_sha256_file - Hash sha256 file
            # . Purpose
            #   Calculate the SHA-256 hash of a file.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  FILE - File path.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_hash_sha256_file "/tmp/sgnd-example.txt" "/tmp/sgnd-example.txt" && printf 'Success\n' || printf 'Failed\n'
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
        # fn: sgnd_safe_replace_file - Safe replace file
            # . Purpose
            #   Atomically replace a target file with a prepared temporary file.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  SRC - Source path.
            #   $2  DST - Destination path.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success.
            #   Non-zero when validation, resolution, user cancellation, or execution fails.
            #
            # . Usage
            #   sgnd_safe_replace_file "/tmp/sgnd-example.txt" "/tmp/sgnd-example.txt"
        sgnd_safe_replace_file() {
            local src="${1:?missing source}"
            local dst="${2:?missing destination}"

            [[ -e "$src" ]] || return 1
            [[ -e "$dst" ]] || return 1

            chmod --reference="$dst" "$src" || return 1
            mv "$src" "$dst" || return 1
        }    
        # fn: sgnd_is_set - Is set
            # . Purpose
            #   Check whether a shell variable is set.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   SGND_EXAMPLE="enabled"; sgnd_is_set "SGND_EXAMPLE" && printf 'Variable is set\n'
        sgnd_is_set() { [[ -v "$1" ]]; }
        # fn: sgnd_default - Default
            # . Purpose
            #   Assign a default value to a shell variable when it is unset or empty.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  NAME - Variable, field, or item name.
            #   $2  DEFAULT - Default value.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_default "example" "example-2"
        sgnd_default() {
            local name="$1"
            local default="${2-}"
            local -n ref="$name"

            [[ -n "${ref:-}" ]] || ref="$default"
        }
        # fn: sgnd_is_number - Is number
            # . Purpose
            #   Check whether a value contains only digits.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_is_number "42" && printf 'Valid number\n'
        sgnd_is_number() { [[ "$1" =~ ^[0-9]+$ ]]; }
        # fn: sgnd_array_has_items - Array has items
            # . Purpose
            #   Check whether an indexed array contains at least one item.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success.
            #   Non-zero when validation, resolution, user cancellation, or execution fails.
            #
            # . Usage
            #   sgnd_array_has_items "example" && printf 'Success\n' || printf 'Failed\n'
        sgnd_array_has_items() {
            declare -p "$1" &>/dev/null || return 1
            local -n _arr="$1"
            (( ${#_arr[@]} > 0 ))
        }
        # fn: sgnd_is_true - Is true
            # . Purpose
            #   Interpret common true/false text values as a shell boolean.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Returns
            #   0 on success.
            #   Non-zero when validation, resolution, user cancellation, or execution fails.
            #
            # . Usage
            #   sgnd_is_true "yes" && printf 'Value is true\n'
        sgnd_is_true() {
            case "${1,,}" in
                y|yes|1|true) return 0 ;;
                *)            return 1 ;;
            esac
        }
    # -- Process and runtime ----------------------------------------------------------
        # fn: sgnd_proc_exists - Proc exists
            # . Purpose
            #   Check whether a process with the given executable name is running.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_proc_exists "sshd" && printf 'sshd is running\n'
        sgnd_proc_exists() { pgrep -x "$1" &>/dev/null; }
        # fn: sgnd_wait_for_exit - Wait for exit
            # . Purpose
            #   Wait for a named process to stop running.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  NAME - Variable, field, or item name.
            #   $2  INTERVAL - Positional value used by this function.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_wait_for_exit "sshd" 1
        sgnd_wait_for_exit() {
            local name="$1"
            local interval="${2:-0.5}"

            while sgnd_proc_exists "$name"; do
                sleep "$interval"
            done
        }
        # fn: sgnd_kill_if_running - Kill if running
            # . Purpose
            #   Terminate processes that match the supplied executable name.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_kill_if_running "sgnd-example-process"
        sgnd_kill_if_running() { pkill -x "$1" &>/dev/null || true; }
    # -- Diagnostics and execution ----------------------------------------------------
        # fn: sgnd_caller_id - Caller id
            # . Purpose
            #   Return the calling script/function identity for diagnostics.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  DEPTH - Positional value used by this function.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_caller_id "example"
        sgnd_caller_id() {
            local depth="${1:-1}"
            local file="${BASH_SOURCE[$depth]}"
            local func="${FUNCNAME[$depth]}"
            local line="${BASH_LINENO[$((depth-1))]}"

            printf '%s:%s (%s)' "${file##*/}" "$line" "$func"
        }
        # fn: sgnd_stack_trace - Stack trace
            # . Purpose
            #   Print a Bash call stack for diagnostics.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_stack_trace
        sgnd_stack_trace() {
            local i
            for (( i=1; i<${#FUNCNAME[@]}; i++ )); do
                printf '  at %s:%s (%s)\n' \
                    "${BASH_SOURCE[$i]##*/}" \
                    "${BASH_LINENO[$((i-1))]}" \
                    "${FUNCNAME[$i]}"
            done
        }
        # fn: sgnd_has_tty - Has tty
            # . Purpose
            #   Check whether /dev/tty can be read and written.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_has_tty
        sgnd_has_tty() { [[ -r /dev/tty && -w /dev/tty ]]; }
        # fn: sgnd_is_ui_mode - Is ui mode
            # . Purpose
            #   Check whether the current UI mode matches the supplied value.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Returns
            #   0 on success.
            #   Non-zero when validation, resolution, user cancellation, or execution fails.
            #
            # . Usage
            #   sgnd_is_ui_mode
        sgnd_is_ui_mode() {
            # Explicit overrides first (future-proof)
            (( ${FLAG_NOUI:-0} ))   && return 1
            (( ${FLAG_BATCH:-0} ))  && return 1
            (( ${FLAG_UI:-0} ))     && return 0

            # Fallback: interactive terminal
            [[ -t 0 && -t 1 ]]
        }
        # fn: sgnd_is_desktop_mode - Is desktop mode
            # . Purpose
            #   Check whether the framework is running in a desktop-capable UI mode.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Returns
            #   0 on success.
            #   Non-zero when validation, resolution, user cancellation, or execution fails.
            #
            # . Usage
            #   sgnd_is_desktop_mode
        sgnd_is_desktop_mode() {
            [[ -n "${DISPLAY:-}" ]] && return 0
            [[ -n "${WAYLAND_DISPLAY:-}" ]] && return 0
            return 1
        }
        # fn: sgnd_internal_call_guard - Internal call guard
            # . Purpose
            #   Reject calls to internal functions from outside allowed framework contexts.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  FUNC - Positional value used by this function.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_internal_call_guard "example" "example-2"
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
        # fn: sgnd_show_vars_by_prefix - Show vars by prefix
            # . Purpose
            #   Print variables whose names start with a supplied prefix.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
            #   - Uses framework UI/output conventions for terminal or dialog interaction.
            #
            # . Arguments
            #   $1  PREFIX - Variable prefix.
            #   $2  ASSUME_DEBUG - Positional value used by this function.
            #
            # . Returns
            #   0 on success.
            #   Non-zero when validation, resolution, user cancellation, or execution fails.
            #
            # . Usage
            #   sgnd_show_vars_by_prefix "example" "example-2"
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
        # fn: sgnd_version_ge - Version ge
            # . Purpose
            #   Compare two version strings and return success when the first is greater or equal.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
            #   $2  ARG2 - Positional value used by this function.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_version_ge "1.8.0" "1.7.9" && printf 'Version requirement met\n'
        sgnd_version_ge() { [[ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]; }
        # fn: sgnd_timestamp - Timestamp
            # . Purpose
            #   Print the current timestamp in SolidGroundUX log format.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_timestamp
        sgnd_timestamp() { date +"%Y-%m-%d %H:%M:%S"; }
        # fn: sgnd_retry - Retry
            # . Purpose
            #   Retry a command until it succeeds or the retry count is exhausted.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  N - Positional value used by this function.
            #   $2  D - Positional value used by this function.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success.
            #   Non-zero when validation, resolution, user cancellation, or execution fails.
            #
            # . Usage
            #   sgnd_retry "example" "example-2"
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
        # fn: sgnd_join - Join
            # . Purpose
            #   Join arguments using a delimiter.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  IFS - Positional value used by this function.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_join "example"
        sgnd_join() {
            local IFS="$1"
            shift
            printf '%s' "$*"
        }
        # fn: sgnd_array_union - Array union
            # . Purpose
            #   Build the union of two shell arrays.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  DEST_NAME - Variable, field, or item name.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success.
            #   Non-zero when validation, resolution, user cancellation, or execution fails.
            #
            # . Usage
            #   sgnd_array_union "example"
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
        # fn: sgnd_trim - Trim
            # . Purpose
            #   Trim leading and trailing whitespace from text.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_trim "   SolidGroundUX example   "
        sgnd_trim() {
            local v="${*:-}"
            v="${v#"${v%%[![:space:]]*}"}"
            printf '%s' "${v%"${v##*[![:space:]]}"}"
        }
        # fn: sgnd_string_repeat - String repeat
            # . Purpose
            #   Repeat a string a fixed number of times.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  S - Positional value used by this function.
            #   $2  N - Positional value used by this function.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_string_repeat "example" "example-2" "example-3"
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
        # fn: sgnd_fill_left - Fill left
            # . Purpose
            #   Pad text on the left to a target width.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  SOURCE - Source path or identifier.
            #   $2  MAXLENGTH - Positional value used by this function.
            #   $3  CHAR - Positional value used by this function.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_fill_left "/tmp/sgnd-example.txt" "example-2" "example-3"
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
        # fn: sgnd_fill_right - Fill right
            # . Purpose
            #   Pad text on the right to a target width.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  SOURCE - Source path or identifier.
            #   $2  MAXLENGTH - Positional value used by this function.
            #   $3  CHAR - Positional value used by this function.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_fill_right "/tmp/sgnd-example.txt" "example-2" "example-3"
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
        # fn: sgnd_fill_center - Fill center
            # . Purpose
            #   Center text in a target width.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  SOURCE - Source path or identifier.
            #   $2  MAXLENGTH - Positional value used by this function.
            #   $3  CHAR - Positional value used by this function.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_fill_center "/tmp/sgnd-example.txt" "example-2" "example-3"
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
        # fn: sgnd_visible_length - Visible length
            # . Purpose
            #   Return visible text length after stripping ANSI escape sequences.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  TEXT - Text value.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_visible_length "SolidGroundUX example"
        sgnd_visible_length() {
            local text="${1-}"

            text="$(printf '%s' "$text" | sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g')"
            printf '%s' "$text" | wc -m
        }
        # fn: sgnd_terminal_width - Terminal width
            # . Purpose
            #   Return the active terminal width or a configured fallback.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_terminal_width
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
        # fn: sgnd_padded_visible - Padded visible
            # . Purpose
            #   Pad styled text based on visible width rather than byte length.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  TEXT - Text value.
            #   $2  WIDTH - Target display width.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_padded_visible "SolidGroundUX example" 20
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
        # fn: sgnd_wrap_words - Wrap words
            # . Purpose
            #   Wrap text to a target visible width.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
            #   $2  ARG2 - Positional value used by this function.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_wrap_words "example" "example-2"
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
    # fn: sgnd_validate_ipv4 - Validate ipv4
        # . Purpose
        #   Validate an IPv4 address.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  IP - Positional value used by this function.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_validate_ipv4 "192.168.0.10" && printf 'Success\n' || printf 'Failed\n'
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
    # fn: sgnd_validate_yesno - Validate yesno
        # . Purpose
        #   Validate a single-character yes/no response.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   sgnd_validate_yesno "yes" && printf 'Valid yes/no value\n'
    sgnd_validate_yesno() { [[ "$1" =~ ^[YyNn]$ ]]; }
    # fn: sgnd_validate_int - Validate int
        # . Purpose
        #   Validate a signed integer.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   sgnd_validate_int "42" && printf 'Valid integer\n'
    sgnd_validate_int() { [[ "$1" =~ ^-?[0-9]+$ ]]; }
    # fn: sgnd_validate_numeric - Validate numeric
        # . Purpose
        #   Validate a signed integer or decimal number.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   sgnd_validate_numeric "42.5" && printf 'Valid numeric value\n'
    sgnd_validate_numeric() { [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; }
    # fn: sgnd_validate_text - Validate text
        # . Purpose
        #   Validate that text is not empty.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   sgnd_validate_text "SolidGroundUX" && printf 'Valid text\n'
    sgnd_validate_text() { [[ -n "$1" ]]; }
    # fn: sgnd_validate_bool - Validate bool
        # . Purpose
        #   Validate a common boolean value.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_validate_bool "true" && printf 'Valid Boolean\n'
    sgnd_validate_bool() {
        case "${1,,}" in
            y|yes|n|no|true|false|1|0) return 0 ;;
            *) return 1 ;;
        esac
    }
    # fn: sgnd_validate_date - Validate date
        # . Purpose
        #   Validate a date string in YYYY-MM-DD form.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   sgnd_validate_date "2026-07-31" && printf 'Valid date\n'
    sgnd_validate_date() { [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; }
    # fn: sgnd_validate_cidr - Validate cidr
        # . Purpose
        #   Validate a CIDR prefix length.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   sgnd_validate_cidr "192.168.0.0/24" && printf 'Valid CIDR\n'
    sgnd_validate_cidr() { [[ "$1" =~ ^([0-9]|[12][0-9]|3[0-2])$ ]]; }
    # fn: sgnd_validate_slug - Validate slug
        # . Purpose
        #   Validate a lowercase slug suitable for identifiers or paths.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   sgnd_validate_slug "solidgroundux-example" && printf 'Valid slug\n'
    sgnd_validate_slug() { [[ "$1" =~ ^[a-z0-9._-]+$ ]]; }
    # fn: sgnd_validate_fs_name - Validate fs name
        # . Purpose
        #   Validate a conservative filesystem name.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   sgnd_validate_fs_name "solidgroundux-example" && printf 'Valid filesystem name\n'
    sgnd_validate_fs_name() { [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]; }
    # fn: sgnd_validate_file_exists - Validate file exists
        # . Purpose
        #   Validate that a file exists.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  PATH - Filesystem path.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   sgnd_validate_file_exists "/tmp/sgnd-example" && printf 'Success\n' || printf 'Failed\n'
    sgnd_validate_file_exists() {
        local path="$1"
        [[ -f "$path" ]]
    }
    # fn: sgnd_validate_path_exists - Validate path exists
        # . Purpose
        #   Validate that a filesystem path exists.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   sgnd_validate_path_exists "/tmp" && printf 'Path exists\n'
    sgnd_validate_path_exists() { [[ -e "$1" ]]; }
    # fn: sgnd_validate_dir_exists - Validate dir exists
        # . Purpose
        #   Validate that a directory exists.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   sgnd_validate_dir_exists "/tmp" && printf 'Directory exists\n'
    sgnd_validate_dir_exists() { [[ -d "$1" ]]; }
    # fn: sgnd_validate_executable - Validate executable
        # . Purpose
        #   Validate that a path exists and is executable.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   sgnd_validate_executable "/bin/bash" && printf 'Executable found\n'
    sgnd_validate_executable() { [[ -x "$1" ]]; }
    # fn: sgnd_validate_file_not_exists - Validate file not exists
        # . Purpose
        #   Validate that a file does not already exist.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #
        # . Returns
        #   0 when the value is valid.
        #   1 when the value is invalid.
        #
        # . Usage
        #   sgnd_validate_file_not_exists "/tmp/sgnd-new-file" && printf 'Path is available\n'
    sgnd_validate_file_not_exists() { [[ ! -f "$1" ]]; }
