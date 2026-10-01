# =====================================================================================
# SolidGroundUX - Configuration Management
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627412
#   Checksum    : a086436cf66ce5edf2ddfc22c230a9733182ff9437cabec780e7fce8bf8e823e
#   Source      : sgnd-cfg.sh
#   Type        : library
#   Group       : Common Core
#   Purpose     : Load, manage, and persist configuration settings
#
# Description:
#   Provides configuration handling for the SolidGroundUX framework.
#
#   The library:
#     - Loads configuration from system and user locations
#     - Resolves effective configuration using precedence rules
#     - Supports reading and writing key-value configuration files
#     - Ensures required configuration values are present
#     - Provides helper functions for accessing configuration values
#     - Integrates with bootstrap and runtime state handling
#
# Design principles:
#   - Clear separation between system-level and user-level configuration
#   - Deterministic resolution of configuration values
#   - Minimal and transparent configuration format
#   - Safe defaults with optional overrides
#
# Role in framework:
#   - Central configuration layer used during bootstrap and runtime
#   - Supplies paths, settings, and environment-specific values
#   - Supports scripts and modules requiring persistent configuration
#
# Non-goals:
#   - Complex hierarchical configuration systems
#   - External configuration formats (JSON, YAML, etc.)
#   - Runtime hot-reloading of configuration
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
# - Internal helpers ----------------------------------------------------------------
    # fn: _sgnd_is_ident - Is ident
        # . Purpose
        #   Internal helper for is ident.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #
        # . Arguments
        #   $1  ARG1 - Positional value used by this function.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_is_ident "example" && printf 'Success\n' || printf 'Failed\n'
    _sgnd_is_ident() {
            [[ "${1:-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
    }
    # fn: _sgnd_kv_load_file - Kv load file
        # . Purpose
        #   Load kv file into the current shell context.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
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
        #   _sgnd_kv_load_file "/tmp/sgnd-example.txt"
    _sgnd_kv_load_file() {
        local file="$1"
        [[ -f "$file" ]] || return 0

        local line key val
        while IFS= read -r line || [[ -n "$line" ]]; do
            # strip leading/trailing whitespace
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"

            # skip blanks / comments
            [[ -z "$line" ]] && continue
            [[ "$line" == \#* ]] && continue

            # accept KEY=VALUE only
            [[ "$line" == *"="* ]] || continue

            key="${line%%=*}"
            val="${line#*=}"

            # trim whitespace around key only
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"

            # validate key name
            if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                continue
            fi

            # If value starts with a space, keep it; we store exactly after '='.
            printf -v "$key" '%s' "$val"
        done < "$file"
    }
    # fn: _sgnd_kv_set - Kv set
        # . Purpose
        #   Internal helper for kv set.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #
        # . Arguments
        #   $1  FILE - File path.
        #   $2  ARG2 - Positional value used by this function.
        #   $3  ARG3 - Positional value used by this function.
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
        #   _sgnd_kv_set "/tmp/sgnd-example.txt" "example-2" "example-3"
    _sgnd_kv_set() {
        local file="$1" key="$2" val="$3"
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1

        local dir
        dir="$(dirname -- "$file")" || return 1

        # Decide who should own the file
        local uid gid
        if [[ ${EUID:-0} -eq 0 && -n "${SUDO_UID:-}" && -n "${SUDO_GID:-}" ]]; then
            uid="$SUDO_UID"
            gid="$SUDO_GID"
        else
            uid="$(id -u)"
            gid="$(id -g)"
        fi

        # Ensure directory exists (state dir should typically be private)
        mkdir -p -- "$dir" || return 1

        local tmp
        tmp="$(mktemp)" || return 1

        if [[ -f "$file" ]]; then
            grep -v -E "^[[:space:]]*${key}[[:space:]]*=" -- "$file" > "$tmp" || true
        fi

        printf "%s=%s\n" "$key" "$val" >> "$tmp" || { rm -f -- "$tmp"; return 1; }

        if [[ ${EUID:-0} -eq 0 && -n "${SUDO_UID:-}" && -n "${SUDO_GID:-}" ]]; then
            # Create final file with correct owner/group/mode immediately
            install -o "$uid" -g "$gid" -m 600 -T -- "$tmp" "$file" || { rm -f -- "$tmp"; return 1; }
            # Also ensure directory is owned by the user (optional but usually desired)
            chown "$uid:$gid" -- "$dir" || true
            chmod 700 -- "$dir" || true
        else
            # Normal user path
            install -m 600 -T -- "$tmp" "$file" || { rm -f -- "$tmp"; return 1; }
            chmod 700 -- "$dir" || true
        fi

        rm -f -- "$tmp"
        return 0
    }
    # fn: _sgnd_kv_unset - Kv unset
        # . Purpose
        #   Internal helper for kv unset.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #
        # . Arguments
        #   $1  FILE - File path.
        #   $2  ARG2 - Positional value used by this function.
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
        #   _sgnd_kv_unset "/tmp/sgnd-example.txt" "example-2"
    _sgnd_kv_unset() {
        local file="$1" key="$2"
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1
        [[ -f "$file" ]] || return 0

        local tmp
        tmp="$(mktemp)"
        grep -v -E "^[[:space:]]*${key}[[:space:]]*=" "$file" > "$tmp" || true

        # If file becomes empty (or only whitespace/comments were removed earlier), keep it simple:
        if [[ ! -s "$tmp" ]]; then
            rm -f "$tmp"
            rm -f "$file"
            return 0
        fi

        cat -- "$tmp" > "$file"
        rm -f -- "$tmp"
    }

    # fn: _sgnd_kv_reset_file
        # . Purpose
        #   Hard-delete a KEY=VALUE file.
        #
        # . Arguments
        #   $1  File path.
        #
        # . Side effects
        #   Removes the file if present.
        #
        # . Returns
        #   0 always (rm -f semantics).
        #
        # . Usage
        #   _sgnd_kv_reset_file "/tmp/sgnd-example.txt" "/tmp/sgnd-example.txt"
    _sgnd_kv_reset_file() {
        local file="$1"
        rm -f "$file"
    }
    # fn: _sgnd_kv_get - Kv get
        # . Purpose
        #   Internal helper for kv get.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #
        # . Arguments
        #   $1  FILE - File path.
        #   $2  ARG2 - Positional value used by this function.
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
        #   _sgnd_kv_get "/tmp/sgnd-example.txt" "example-2"
    _sgnd_kv_get() {
        local file="$1" key="$2"

        [[ -n "$file" && -n "$key" ]] || return 2
        _sgnd_is_ident "$key"        || return 2
        [[ -r "$file" ]]            || return 2

        local line
        line="$(grep -m1 -E "^[[:space:]]*${key}[[:space:]]*=" -- "$file" 2>/dev/null)" || true
        [[ -n "$line" ]] || return 1

        printf '%s' "${line#*=}"
        return 0
    }

    # fn: _sgnd_kv_has
        # . Purpose
        #   Test whether a KEY exists in a KEY=VALUE file (even if empty).
        #
        # . Arguments
        #   $1  File path.
        #   $2  Key (must be a valid identifier).
        #
        # . Returns
        #   0 if present,
        #   1 if not present,
        #   2 on argument/read error.
        #
        # . Usage
        #   _sgnd_kv_has "/tmp/sgnd-example.txt" "example-2" && printf 'Success\n' || printf 'Failed\n'
    _sgnd_kv_has() {
        local file="$1" key="$2"

        [[ -n "$file" && -n "$key" ]] || return 2
        _sgnd_is_ident "$key" || return 2
        [[ -r "$file" ]] || return 2

        grep -q -E "^[[:space:]]*${key}[[:space:]]*=" -- "$file" 2>/dev/null
    }
    # fn: _sgnd_kv_list_keys - Kv list keys
        # . Purpose
        #   Internal helper for kv list keys.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
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
        #   _sgnd_kv_list_keys "/tmp/sgnd-example.txt"
    _sgnd_kv_list_keys() {
        local file="$1"
        [[ -r "$file" ]] || return 1

        local line key val

        while IFS= read -r line || [[ -n "$line" ]]; do
            # skip blanks and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

            # split on first '=' only
            key="${line%%=*}"
            val="${line#*=}"

            # trim surrounding whitespace from key
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"

            # basic identifier sanity (optional but recommended)
            [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

            printf '%s|%s\n' "$key" "$val"
        done < "$file"
    }
# - Public API (CFG) ----------------------------------------------------------------   
    # fn: sgnd_cfg_load - Cfg load
        # . Purpose
        #   Load a configuration domain into shell variables.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Arguments
        #   $1  FILE - File path.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_cfg_load "/tmp/sgnd-example.txt" "example-2"
    sgnd_cfg_load() {
        local file="${1:-$SGND_CFG_FILE}"
        _sgnd_kv_load_file "$file"
    }
    # fn: sgnd_cfg_set - Cfg set
        # . Purpose
        #   Set a key in a configuration domain.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  KEY - Unique key or identifier.
        #   $2  ARG2 - Positional value used by this function.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_cfg_set "ui.style" "example-2"
    sgnd_cfg_set() {
        local key="$1" val="$2"
        _sgnd_is_ident "$key" || { saywarning "Skipping invalid cfg key: '$key'"; return 1; }
        local file
        file="${SGND_CFG_FILE}"
        _sgnd_kv_set "$file" "$key" "$val"
        printf -v "$key" '%s' "$val"
    }
    # fn: sgnd_cfg_unset - Cfg unset
        # . Purpose
        #   Remove a key from a configuration domain.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  KEY - Unique key or identifier.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_cfg_unset "ui.style"
    sgnd_cfg_unset() {
        local key="$1"
        _sgnd_is_ident "$key" || { saywarning "Skipping invalid cfg key: '$key'"; return 1; }
        local file
        file="${SGND_CFG_FILE}"
        _sgnd_kv_unset "$file" "$key"
        unset "$key" || true
    }
    # fn: sgnd_cfg_reset - Cfg reset
        # . Purpose
        #   Clear all keys from a configuration domain.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_cfg_reset "ui.style"
    sgnd_cfg_reset() {
        local file
        file="${SGND_CFG_FILE}"
        _sgnd_kv_reset_file "$file"
    }
    # fn: sgnd_cfg_get - Cfg get
        # . Purpose
        #   Read a key from a configuration domain.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  KEY - Unique key or identifier.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_cfg_get "ui.style"
    sgnd_cfg_get() {
        local key="$1"
        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid cfg key: '$key'"
            return 1
        }
        _sgnd_kv_get "$SGND_CFG_FILE" "$key"
    }
    # fn: sgnd_cfg_has - Cfg has
        # . Purpose
        #   Check whether a key exists in a configuration domain.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  KEY - Unique key or identifier.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_cfg_has "ui.style" && printf 'Success\n' || printf 'Failed\n'
    sgnd_cfg_has() {
        local key="$1"
        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid cfg key: '$key'"
            return 1
        }
        _sgnd_kv_has "$SGND_CFG_FILE" "$key"
    }
    # fn: sgnd_cfg_show_keys - Cfg show keys
        # . Purpose
        #   Print all keys stored in a configuration domain.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_cfg_show_keys
    sgnd_cfg_show_keys() {
        local key val

        sgnd_print_sectionheader --text "CFG" --pad 2 --padend 1

        for key in "$@"; do
            if sgnd_cfg_has "$key"; then
                val="$(sgnd_cfg_get "$key")" || val=""
                if [[ -z "$val" ]]; then
                    sgnd_print_fill --left "$key" --right '""' --pad 2
                else
                    sgnd_print_fill --left "$key" --right "$val" --pad 2
                fi
            else
                sgnd_print_fill --left "$key" --right "<unset>" --pad 2
            fi
        done

        sgnd_print
    }
    # fn: sgnd_cfg_has_audience - Cfg has audience
        # . Purpose
        #   Check whether the active script or framework metadata matches a configuration audience.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  SPEC_ARRAY_NAME - Variable, field, or item name.
        #   $2  WANT - Positional value used by this function.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_cfg_has_audience "example" "example-2" "example-3" && printf 'Success\n' || printf 'Failed\n'
    sgnd_cfg_has_audience() {
        local spec_array_name="${1:-}"
        local want="${2:-}"          # "system" or "user"
        [[ -n "$spec_array_name" && -n "$want" ]] || return 1

        local -n specs="$spec_array_name"

        local spec audience var desc extra
        for spec in "${specs[@]}"; do
            IFS='|' read -r audience var desc extra <<< "$spec"
            case "$audience" in
                "$want"|both) return 0 ;;
            esac
        done

        return 1
    }
        # fn: sgnd_cfg_write_skeleton_filtered
        # Purpose:
        #   Write an auto-generated cfg skeleton filtered by audience.
        #
        # Behavior:
        #   - Writes a commented KEY=VALUE config template.
        #   - Includes only specs matching the requested audience.
        #   - Includes specs marked "both" for either audience.
        #   - Uses current shell values as initial defaults where available.
        #   - Adds a standard auto-generated file header.
        #
        # Arguments:
        #   $1  FILE
        #       Target cfg file path.
        #   $2  AUDIENCE
        #       Audience filter: "system" or "user".
        #   $3  SPEC_ARRAY_NAME
        #       Name of the cfg specs array.
        #   $4  DOMAIN
        #       Optional logical domain name for header text.
        #       Default: configuration
        #
        # Side effects:
        #   - Creates or overwrites the target file.
        #
        # Returns:
        #   0 on success.
        #   1 on invalid arguments.
        #
        # Usage:
        #   sgnd_cfg_write_skeleton_filtered FILE AUDIENCE SPEC_ARRAY_NAME [DOMAIN]
        #
        # Examples:
        #   sgnd_cfg_write_skeleton_filtered "$SGND_USRCFG_FILE" "user" SGND_FRAMEWORK_GLOBALS "Framework"
        #
        #   sgnd_cfg_write_skeleton_filtered "$SGND_SYSCFG_FILE" "system" SGND_SCRIPT_GLOBALS "Script"
        #
    sgnd_cfg_write_skeleton_filtered() {
            local file="${1:-}"
            local audience_want="${2:-}"
            local spec_array_name="${3:-}"
            local domain="${4:-configuration}"

            [[ -n "$file" && -n "$audience_want" && -n "$spec_array_name" ]] || return 1

            local -n specs="$spec_array_name"

            {
                _sgnd_cfg_write_template_header "$domain" "$audience_want"

                local spec audience var desc extra val
                for spec in "${specs[@]}"; do
                    IFS='|' read -r audience var desc extra <<< "$spec"
                    [[ -n "$var" ]] || continue

                    case "$audience" in
                        "$audience_want"|both)
                            printf '# %s
    ' "${desc:-$var}"
                            val="${!var:-}"
                            printf '%s=%s

    ' "$var" "$val"
                            ;;
                    esac
                done
            } > "$file"

            return 0
    }    
    # fn: _sgnd_cfg_write_template_header - Cfg write template header
        # . Purpose
        #   Internal helper for cfg write template header.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #
        # . Arguments
        #   $1  DOMAIN - Configuration or state domain name.
        #   $2  AUDIENCE - Positional value used by this function.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   _sgnd_cfg_write_template_header "TESTADURA" "example-2"
    _sgnd_cfg_write_template_header() {
        local domain="${1:-configuration}"
        local audience="${2:-user}"
        local generated=""

        generated="$(date '+%Y-%m-%d %H:%M:%S')"

        printf '%s\n' \
            '# =====================================================================================' \
            "# SolidGroundUX - ${domain} configuration (${audience})" \
            '# -------------------------------------------------------------------------------------' \
            "# Generated   : ${generated}" \
            '#' \
            '# Description:' \
            '#   Auto-generated configuration template based on current defaults.' \
            '#' \
            '# Precedence:' \
            '#   - System configuration is loaded first when present' \
            '#   - User configuration is loaded after system configuration' \
            '#   - User values override system values' \
            '#' \
            '# Notes:' \
            '#   - This file may be edited safely' \
            '#   - Only KEY=VALUE lines are processed' \
            '#   - Missing values fall back to in-memory defaults' \
            '# =====================================================================================' \
            ''
    }
    # fn: sgnd_cfg_load_file - Cfg load file
        # . Purpose
        #   Load a SolidGroundUX key/value configuration file into shell variables.
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
        #   sgnd_cfg_load_file "/tmp/sgnd-example.txt"
    sgnd_cfg_load_file() {
        local file="${1:-}"
        [[ -r "$file" ]] || return 0

        local line key value
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Trim leading/trailing whitespace (basic)
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"

            [[ -n "$line" ]] || continue
            [[ "${line:0:1}" == "#" ]] && continue

            # Must contain '=' and a non-empty key
            [[ "$line" == *"="* ]] || continue
            key="${line%%=*}"
            value="${line#*=}"

            # Trim key whitespace
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"
            [[ -n "$key" ]] || continue

            # Validate key is a shell variable name
            [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

            # Set variable (value can be anything; keep literal)
            printf -v "$key" '%s' "$value"
        done < "$file"

        return 0
    }
    # fn: sgnd_cfg_create_missing_domain_files - Cfg create missing domain files
        # . Purpose
        #   Create missing configuration files for configured domains.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  DOMAIN - Configuration or state domain name.
        #   $2  SYSCFG - Positional value used by this function.
        #   $3  USRCFG - Positional value used by this function.
        #   $4  SPEC_ARRAY_NAME - Variable, field, or item name.
        #   $5  MODE - Operation mode.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_cfg_create_missing_domain_files "TESTADURA" "/tmp/sgnd-example.txt" "/tmp/sgnd-example.txt" "/tmp/sgnd-example.txt" "normal"
    sgnd_cfg_create_missing_domain_files() {
        local domain="${1:-}"
        local syscfg="${2:-}"
        local usrcfg="${3:-}"
        local spec_array_name="${4:-}"
        local mode="${5:-script}"

        [[ -n "$domain" && -n "$spec_array_name" ]] || return 1

        local is_root=0
        (( EUID == 0 )) && is_root=1

        if sgnd_cfg_has_audience "$spec_array_name" "system"; then
            if (( is_root )) && [[ -n "$syscfg" && ! -f "$syscfg" ]]; then
                sgnd_ensure_writable_dir "$(dirname -- "$syscfg")" || return 1
                sgnd_cfg_write_skeleton_filtered "$syscfg" "system" "$spec_array_name" "$domain" || return 1
                sayinfo "[$domain] created system cfg: $syscfg"
            fi
        fi

        if sgnd_cfg_has_audience "$spec_array_name" "user"; then
            if [[ -n "$usrcfg" && ! -f "$usrcfg" ]]; then
                sgnd_ensure_writable_dir "$(dirname -- "$usrcfg")" || return 1
                sgnd_cfg_write_skeleton_filtered "$usrcfg" "user" "$spec_array_name" "$domain" || return 1
                sayinfo "[$domain] created user cfg: $usrcfg"
            fi
        fi

        if sgnd_cfg_has_audience "$spec_array_name" "system" && [[ -n "$syscfg" && ! -f "$syscfg" ]] && (( ! is_root )); then
            saydebug "[$domain] system cfg missing but not created because current session is not root"
        fi

        return 0
    }
    # fn: sgnd_cfg_domain_apply - Cfg domain apply
        # . Purpose
        #   Apply default, system, user, and script configuration domains in precedence order.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  DOMAIN - Configuration or state domain name.
        #   $2  SYSCFG - Positional value used by this function.
        #   $3  USRCFG - Positional value used by this function.
        #   $4  SPEC_ARRAY_NAME - Variable, field, or item name.
        #   $5  MODE - Operation mode.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_cfg_domain_apply "TESTADURA" "example-2" "example-3" "example-4" "normal"
    sgnd_cfg_domain_apply() {
        local domain="${1:-}"
        local syscfg="${2:-}"
        local usrcfg="${3:-}"
        local spec_array_name="${4:-}"
        local mode="${5:-script}"   # "framework" or "script"

        [[ -n "$domain" && -n "$spec_array_name" ]] || return 1

        sgnd_cfg_create_missing_domain_files "$domain" "$syscfg" "$usrcfg" "$spec_array_name" "$mode" || return 1

        if sgnd_cfg_has_audience "$spec_array_name" "system"; then
            [[ -r "$syscfg" ]] && sgnd_cfg_load_file "$syscfg"
        fi

        if sgnd_cfg_has_audience "$spec_array_name" "user"; then
            [[ -r "$usrcfg" ]] && sgnd_cfg_load_file "$usrcfg"
        fi

        return 0
    }

# - Public API (STATE) -----------------------------------------------------------------
    # sgnd_state_load
        # Purpose:
        #   Load a state domain into the current shell.
        #
        # Behavior:
        #   - Loads all valid key/value pairs from the selected state file.
        #   - Uses SGND_STATE_FILE when no explicit filename is supplied.
        #
        # Options:
        #   --file FILE
        #       State file to load. Defaults to SGND_STATE_FILE.
        #
        # Side effects:
        #   Updates shell variables defined in the selected state file.
        #
        # Returns:
        #   0 on success unless the underlying loader returns a different status.
        #   1 when no state filename can be resolved.
        #
        # Usage:
        #   sgnd_state_load [--file FILE]
        #
        # . Usage
        #   sgnd_state_load "example" "example-2"
    sgnd_state_load() {
        local state_file="${SGND_STATE_FILE:-}"

        while (( $# )); do
            case "$1" in
                --file)
                    [[ $# -ge 2 ]] || {
                        saywarning "Missing value for --file"
                        return 1
                    }
                    state_file="$2"
                    shift 2
                    ;;
                *)
                    saywarning "Unknown sgnd_state_load option: '$1'"
                    return 1
                    ;;
            esac
        done

        [[ -n "$state_file" ]] || {
            saywarning "No state file specified"
            return 1
        }

        saydebug "Loading state from file $state_file"
        _sgnd_kv_load_file "$state_file"
    }

    # sgnd_state_set
        # Purpose:
        #   Store a key/value pair in a state domain and update the matching shell variable.
        #
        # Behavior:
        #   - Validates the key as a shell identifier.
        #   - Writes the value to the selected state file.
        #   - Uses SGND_STATE_FILE when no explicit filename is supplied.
        #   - Updates the shell variable named by KEY after a successful write.
        #
        # Options:
        #   --file FILE
        #       State file to update. Defaults to SGND_STATE_FILE.
        #
        # Arguments:
        #   KEY
        #       Shell variable name to store.
        #   VALUE
        #       Value to store.
        #
        # Outputs (globals):
        #   Updates the shell variable named by KEY.
        #
        # Side effects:
        #   Creates or updates the selected state file.
        #
        # Returns:
        #   0 on success.
        #   1 when the filename, key, or arguments are invalid, or the write fails.
        #
        # Usage:
        #   sgnd_state_set [--file FILE] KEY VALUE
        #
        # . Usage
        #   sgnd_state_set "ui.style" "example-2"
    sgnd_state_set() {
        local state_file="${SGND_STATE_FILE:-}"

        while (( $# )); do
            case "$1" in
                --file)
                    [[ $# -ge 2 ]] || {
                        saywarning "Missing value for --file"
                        return 1
                    }
                    state_file="$2"
                    shift 2
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    break
                    ;;
            esac
        done

        [[ -n "$state_file" ]] || {
            saywarning "No state file specified"
            return 1
        }

        [[ $# -ge 2 ]] || {
            saywarning "sgnd_state_set requires KEY and VALUE"
            return 1
        }

        local key="$1"
        local val="$2"

        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid state key: '$key'"
            return 1
        }

        saydebug "Setting state key '$key' to '$val' in file $state_file"

        _sgnd_kv_set "$state_file" "$key" "$val" || return $?
        printf -v "$key" '%s' "$val"
    }

    # sgnd_state_unset
        # Purpose:
        #   Remove a key from a state domain and unset the matching shell variable.
        #
        # Behavior:
        #   - Validates the key as a shell identifier.
        #   - Removes the key from the selected state file.
        #   - Uses SGND_STATE_FILE when no explicit filename is supplied.
        #   - Unsets the shell variable named by KEY after a successful update.
        #
        # Options:
        #   --file FILE
        #       State file to update. Defaults to SGND_STATE_FILE.
        #
        # Arguments:
        #   KEY
        #       Shell variable name to remove.
        #
        # Outputs (globals):
        #   Unsets the shell variable named by KEY.
        #
        # Side effects:
        #   Updates the selected state file.
        #
        # Returns:
        #   0 on success.
        #   1 when the filename or key is invalid, or the update fails.
        #
        # Usage:
        #   sgnd_state_unset [--file FILE] KEY
        #
        # . Usage
        #   sgnd_state_unset "ui.style" "example-2"
    sgnd_state_unset() {
        local state_file="${SGND_STATE_FILE:-}"

        while (( $# )); do
            case "$1" in
                --file)
                    [[ $# -ge 2 ]] || {
                        saywarning "Missing value for --file"
                        return 1
                    }
                    state_file="$2"
                    shift 2
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    break
                    ;;
            esac
        done

        [[ -n "$state_file" ]] || {
            saywarning "No state file specified"
            return 1
        }

        [[ $# -ge 1 ]] || {
            saywarning "sgnd_state_unset requires KEY"
            return 1
        }

        local key="$1"

        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid state key: '$key'"
            return 1
        }

        saydebug "Unsetting state key '$key' in file $state_file"

        _sgnd_kv_unset "$state_file" "$key" || return $?
        unset "$key" || true
    }

    # sgnd_state_reset
        # Purpose:
        #   Clear a state domain.
        #
        # Behavior:
        #   - Removes the selected state file through the state backend.
        #   - Uses SGND_STATE_FILE when no explicit filename is supplied.
        #   - Returns successfully when no filename is available.
        #
        # Options:
        #   --file FILE
        #       State file to clear. Defaults to SGND_STATE_FILE.
        #
        # Side effects:
        #   Deletes or clears the selected state file.
        #
        # Returns:
        #   0 when no state file is configured or the reset succeeds.
        #   Non-zero when the underlying reset operation fails.
        #
        # Usage:
        #   sgnd_state_reset [--file FILE]
        #
        # . Usage
        #   sgnd_state_reset "example" "example-2"
    sgnd_state_reset() {
        local state_file="${SGND_STATE_FILE:-}"

        while (( $# )); do
            case "$1" in
                --file)
                    [[ $# -ge 2 ]] || {
                        saywarning "Missing value for --file"
                        return 1
                    }
                    state_file="$2"
                    shift 2
                    ;;
                *)
                    saywarning "Unknown sgnd_state_reset option: '$1'"
                    return 1
                    ;;
            esac
        done

        [[ -n "$state_file" ]] || return 0

        saydebug "Deleting state file $state_file"
        _sgnd_kv_reset_file "$state_file"
    }

    # sgnd_state_get
        # Purpose:
        #   Read a key from a state domain.
        #
        # Behavior:
        #   - Validates the key as a shell identifier.
        #   - Reads from the selected state file.
        #   - Uses SGND_STATE_FILE when no explicit filename is supplied.
        #
        # Options:
        #   --file FILE
        #       State file to read. Defaults to SGND_STATE_FILE.
        #
        # Arguments:
        #   KEY
        #       Key to read.
        #
        # Output:
        #   Writes the stored value to stdout when the key exists.
        #
        # Returns:
        #   0 when the key exists and is read successfully.
        #   1 when the filename or key is invalid, or the key does not exist.
        #
        # Usage:
        #   sgnd_state_get [--file FILE] KEY
        #
        # . Usage
        #   sgnd_state_get "ui.style" "example-2"
    sgnd_state_get() {
        local state_file="${SGND_STATE_FILE:-}"

        while (( $# )); do
            case "$1" in
                --file)
                    [[ $# -ge 2 ]] || {
                        saywarning "Missing value for --file"
                        return 1
                    }
                    state_file="$2"
                    shift 2
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    break
                    ;;
            esac
        done

        [[ -n "$state_file" ]] || {
            saywarning "No state file specified"
            return 1
        }

        [[ $# -ge 1 ]] || {
            saywarning "sgnd_state_get requires KEY"
            return 1
        }

        local key="$1"

        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid state key: '$key'"
            return 1
        }

        _sgnd_kv_get "$state_file" "$key"
    }

    # sgnd_state_has
        # Purpose:
        #   Check whether a key exists in a state domain.
        #
        # Behavior:
        #   - Validates the key as a shell identifier.
        #   - Checks the selected state file.
        #   - Uses SGND_STATE_FILE when no explicit filename is supplied.
        #
        # Options:
        #   --file FILE
        #       State file to inspect. Defaults to SGND_STATE_FILE.
        #
        # Arguments:
        #   KEY
        #       Key to check.
        #
        # Returns:
        #   0 when the key exists.
        #   1 when the filename or key is invalid, or the key does not exist.
        #
        # Usage:
        #   sgnd_state_has [--file FILE] KEY
        #
        # . Usage
        #   sgnd_state_has "ui.style" "example-2" && printf 'Success\n' || printf 'Failed\n'
    sgnd_state_has() {
        local state_file="${SGND_STATE_FILE:-}"

        while (( $# )); do
            case "$1" in
                --file)
                    [[ $# -ge 2 ]] || {
                        saywarning "Missing value for --file"
                        return 1
                    }
                    state_file="$2"
                    shift 2
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    break
                    ;;
            esac
        done

        [[ -n "$state_file" ]] || {
            saywarning "No state file specified"
            return 1
        }

        [[ $# -ge 1 ]] || {
            saywarning "sgnd_state_has requires KEY"
            return 1
        }

        local key="$1"

        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid state key: '$key'"
            return 1
        }

        _sgnd_kv_has "$state_file" "$key"
    }

    # sgnd_state_save_keys
        # Purpose:
        #   Save selected shell variables to a state domain.
        #
        # Behavior:
        #   - Accepts keys directly and/or through a named indexed array.
        #   - Validates every key as a shell identifier.
        #   - Saves unset variables as empty values, preserving existing behavior.
        #   - Uses SGND_STATE_FILE when no explicit filename is supplied.
        #
        # Options:
        #   --file FILE
        #       State file to update. Defaults to SGND_STATE_FILE.
        #   --array ARRAY_NAME
        #       Named indexed array containing additional keys to save.
        #
        # Arguments:
        #   KEY...
        #       Optional additional shell variable names to save.
        #
        # Side effects:
        #   Creates or updates the selected state file.
        #
        # Returns:
        #   0 when all valid keys are saved successfully.
        #   1 when the filename, array name, or an underlying write is invalid.
        #
        # Usage:
        #   sgnd_state_save_keys [--file FILE] [--array ARRAY_NAME] [KEY...]
        #
        # Examples:
        #   sgnd_state_save_keys SGND_CONSOLE_LOG_LEVEL SGND_UI_STYLE
        #   sgnd_state_save_keys --file "$SGND_FRAMEWORK_STATE_FILE" --array SGND_FRAMEWORK_STATE
        #
        # . Usage
        #   sgnd_state_save_keys "example" "example-2"
    sgnd_state_save_keys() {
        local state_file="${SGND_STATE_FILE:-}"
        local array_name=""
        local key val
        local -a keys=()

        while (( $# )); do
            case "$1" in
                --file)
                    [[ $# -ge 2 ]] || {
                        saywarning "Missing value for --file"
                        return 1
                    }
                    state_file="$2"
                    shift 2
                    ;;
                --array)
                    [[ $# -ge 2 ]] || {
                        saywarning "Missing value for --array"
                        return 1
                    }
                    array_name="$2"
                    shift 2
                    ;;
                --)
                    shift
                    keys+=("$@")
                    break
                    ;;
                *)
                    keys+=("$1")
                    shift
                    ;;
            esac
        done

        [[ -n "$state_file" ]] || {
            saywarning "No state file specified"
            return 1
        }

        if [[ -n "$array_name" ]]; then
            _sgnd_is_ident "$array_name" || {
                saywarning "Invalid state key array name: '$array_name'"
                return 1
            }

            local -n state_keys="$array_name"
            keys+=("${state_keys[@]}")
        fi

        for key in "${keys[@]}"; do
            _sgnd_is_ident "$key" || {
                saywarning "Skipping invalid state key: '$key'"
                continue
            }

            val="${!key-}"
            sgnd_state_set --file "$state_file" "$key" "$val" || return $?
        done
    }

    # sgnd_state_load_keys
        # Purpose:
        #   Load selected state keys into shell variables.
        #
        # Behavior:
        #   - Accepts keys directly and/or through a named indexed array.
        #   - Validates every key as a shell identifier.
        #   - Leaves variables unchanged when their keys do not exist.
        #   - Uses SGND_STATE_FILE when no explicit filename is supplied.
        #
        # Options:
        #   --file FILE
        #       State file to read. Defaults to SGND_STATE_FILE.
        #   --array ARRAY_NAME
        #       Named indexed array containing additional keys to load.
        #
        # Arguments:
        #   KEY...
        #       Optional additional state keys to load.
        #
        # Outputs (globals):
        #   Updates shell variables matching keys found in the selected state file.
        #
        # Returns:
        #   0 after processing all valid keys.
        #   1 when the filename or array name is invalid.
        #
        # Usage:
        #   sgnd_state_load_keys [--file FILE] [--array ARRAY_NAME] [KEY...]
        #
        # Examples:
        #   sgnd_state_load_keys SGND_CONSOLE_LOG_LEVEL SGND_UI_STYLE
        #   sgnd_state_load_keys --file "$SGND_FRAMEWORK_STATE_FILE" --array SGND_FRAMEWORK_STATE
        #
        # . Usage
        #   sgnd_state_load_keys "example" "example-2"
    sgnd_state_load_keys() {
        local state_file="${SGND_STATE_FILE:-}"
        local array_name=""
        local key val
        local -a keys=()

        while (( $# )); do
            case "$1" in
                --file)
                    [[ $# -ge 2 ]] || {
                        saywarning "Missing value for --file"
                        return 1
                    }
                    state_file="$2"
                    shift 2
                    ;;
                --array)
                    [[ $# -ge 2 ]] || {
                        saywarning "Missing value for --array"
                        return 1
                    }
                    array_name="$2"
                    shift 2
                    ;;
                --)
                    shift
                    keys+=("$@")
                    break
                    ;;
                *)
                    keys+=("$1")
                    shift
                    ;;
            esac
        done

        [[ -n "$state_file" ]] || {
            saywarning "No state file specified"
            return 1
        }

        if [[ -n "$array_name" ]]; then
            _sgnd_is_ident "$array_name" || {
                saywarning "Invalid state key array name: '$array_name'"
                return 1
            }

            local -n state_keys="$array_name"
            keys+=("${state_keys[@]}")
        fi

        for key in "${keys[@]}"; do
            _sgnd_is_ident "$key" || {
                saywarning "Skipping invalid state key: '$key'"
                continue
            }

            if val="$(sgnd_state_get --file "$state_file" "$key")"; then
                printf -v "$key" '%s' "$val"
            fi
        done
    }

    # sgnd_state_list_keys
        # Purpose:
        #   Print all keys stored in a state domain.
        #
        # Behavior:
        #   - Reads keys from the selected state file.
        #   - Uses SGND_STATE_FILE when no explicit filename is supplied.
        #   - Produces no output when the selected file is absent or unreadable.
        #
        # Options:
        #   --file FILE
        #       State file to inspect. Defaults to SGND_STATE_FILE.
        #
        # Output:
        #   Writes one stored key per line to stdout.
        #
        # Returns:
        #   0 when the file is absent, unreadable, or listed successfully.
        #   1 when an option is invalid.
        #
        # Usage:
        #   sgnd_state_list_keys [--file FILE]
        #
        # . Usage
        #   sgnd_state_list_keys "example" "example-2"
    sgnd_state_list_keys() {
        local state_file="${SGND_STATE_FILE:-}"

        while (( $# )); do
            case "$1" in
                --file)
                    [[ $# -ge 2 ]] || {
                        saywarning "Missing value for --file"
                        return 1
                    }
                    state_file="$2"
                    shift 2
                    ;;
                *)
                    saywarning "Unknown sgnd_state_list_keys option: '$1'"
                    return 1
                    ;;
            esac
        done

        [[ -r "$state_file" ]] || return 0
        _sgnd_kv_list_keys "$state_file"
    }
