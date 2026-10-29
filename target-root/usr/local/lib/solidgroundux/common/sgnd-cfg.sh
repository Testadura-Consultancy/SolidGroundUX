# =====================================================================================
# SolidGroundUX - Configuration Management
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
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
# - Internal helpers ----------------------------------------------------------------
    # fn: _sgnd_is_ident - Check whether text is a valid Bash variable identifier.
        # . Purpose
        #   Check whether text is a valid Bash variable identifier.
        #
        # . Arguments
        #   $1  Candidate identifier.
        #
        # . Returns
        #   0 for letters/underscores followed by alphanumerics/underscores; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   _sgnd_is_ident "SGND_UI_STYLE"
        #   ```
    _sgnd_is_ident() {
            [[ "${1:-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
    }
    # fn: _sgnd_kv_load_file - Read valid KEY=VALUE lines into variables in the current shell.
        # . Purpose
        #   Read valid KEY=VALUE lines into variables in the current shell.
        #
        # . Description
        #   Skips blank, comment and malformed lines, trims surrounding whitespace from names, and preserves the value after the first equals sign.
        #
        # . Arguments
        #   $1  Path of a key/value file.
        #
        # . Side effects
        #   Assigns validated shell variable names via printf -v.
        #
        # . Returns
        #   0 after processing, including when the file does not exist.
        #
        # . Usage
        #   ```bash
        #   _sgnd_kv_load_file "$SGND_CFG_FILE"
        #   ```
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
    # fn: _sgnd_kv_set - Write or replace one key in a private key/value file.
        # . Purpose
        #   Write or replace one key in a private key/value file.
        #
        # . Arguments
        #   $1  Destination file.
        #   $2  Bash-identifier key.
        #   $3  Value to store literally.
        #
        # . Side effects
        #   Creates the parent directory and atomically installs a mode-600 file. Under sudo it prefers the invoking user as owner.
        #
        # . Returns
        #   0 when installed successfully; 1 on invalid key or filesystem error.
        #
        # . Usage
        #   ```bash
        #   _sgnd_kv_set "/tmp/sgnd-cfg-demo" SGND_UI_STYLE dark
        #   ```
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
    # fn: _sgnd_kv_unset - Remove one key from a KEY=VALUE file.
        # . Purpose
        #   Remove one key from a KEY=VALUE file.
        #
        # . Arguments
        #   $1  File path.
        #   $2  Key to remove.
        #
        # . Side effects
        #   Rewrites the file without matching lines, or deletes it if empty.
        #
        # . Returns
        #   0 if removed or the file was already absent; 1 for invalid key or filesystem errors.
        #
        # . Usage
        #   ```bash
        #   _sgnd_kv_unset "/tmp/sgnd-cfg-demo" SGND_UI_STYLE
        #   ```
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

    # fn: _sgnd_kv_reset_file - Delete a key/value file if it exists.
        # . Purpose
        #   Delete a key/value file if it exists.
        #
        # . Arguments
        #   $1  File path.
        #
        # . Side effects
        #   Removes the named file.
        #
        # . Returns
        #   0 when removal succeeds, including when already absent; otherwise rm status.
        #
        # . Usage
        #   ```bash
        #   _sgnd_kv_reset_file "/tmp/sgnd-cfg-demo"
        #   ```
    _sgnd_kv_reset_file() {
        local file="$1"
        rm -f "$file"
    }
    # fn: _sgnd_kv_get - Read the first matching key from a readable KEY=VALUE file.
        # . Purpose
        #   Read the first matching key from a readable KEY=VALUE file.
        #
        # . Arguments
        #   $1  File path.
        #   $2  Valid shell-identifier key.
        #
        # . Output
        #   Writes the exact value after the first equals sign without a trailing newline.
        #
        # . Returns
        #   0 when found; 1 when missing; 2 for invalid input or unreadable file.
        #
        # . Usage
        #   ```bash
        #   _sgnd_kv_get "/tmp/sgnd-cfg-demo" SGND_UI_STYLE
        #   ```
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

    # fn: _sgnd_kv_has - Test whether a valid key is present, including an empty value.
        # . Purpose
        #   Test whether a valid key is present, including an empty value.
        #
        # . Arguments
        #   $1  File path.
        #   $2  Key to test.
        #
        # . Returns
        #   0 when present; 1 if absent; 2 for invalid input or unreadable file.
        #
        # . Usage
        #   ```bash
        #   _sgnd_kv_has "/tmp/sgnd-cfg-demo" SGND_UI_STYLE
        #   ```
    _sgnd_kv_has() {
        local file="$1" key="$2"

        [[ -n "$file" && -n "$key" ]] || return 2
        _sgnd_is_ident "$key" || return 2
        [[ -r "$file" ]] || return 2

        grep -q -E "^[[:space:]]*${key}[[:space:]]*=" -- "$file" 2>/dev/null
    }
    # fn: _sgnd_kv_list_keys - List identifier/value pairs from a readable configuration file.
        # . Purpose
        #   List identifier/value pairs from a readable configuration file.
        #
        # . Arguments
        #   $1  File path.
        #
        # . Output
        #   Writes one KEY|VALUE pair per valid record.
        #
        # . Returns
        #   0 on completion; 1 when the file cannot be read.
        #
        # . Usage
        #   ```bash
        #   _sgnd_kv_list_keys "/tmp/sgnd-cfg-demo"
        #   ```
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
    # fn: sgnd_cfg_load - Load the selected configuration file into shell variables.
        # . Purpose
        #   Load the selected configuration file into shell variables.
        #
        # . Arguments
        #   $1  Optional file path (defaults to SGND_CFG_FILE).
        #
        # . Side effects
        #   Sets shell variables for valid entries.
        #
        # . Returns
        #   0 after loading, including when the file is absent.
        #
        # . Usage
        #   ```bash
        #   sgnd_cfg_load "$SGND_CFG_FILE"
        #   ```
    sgnd_cfg_load() {
        local file="${1:-$SGND_CFG_FILE}"
        _sgnd_kv_load_file "$file"
    }
    # fn: sgnd_cfg_set - Persist a configuration variable and assign its current value.
        # . Purpose
        #   Persist a configuration variable and assign its current value.
        #
        # . Description
        #   Configuration keys are Bash identifiers, not dotted paths.
        #
        # . Arguments
        #   $1  Valid shell-identifier key.
        #   $2  Literal value to store.
        #
        # . Side effects
        #   Writes SGND_CFG_FILE and updates the named variable in the current shell.
        #
        # . Returns
        #   0 after assigning the variable; 1 if the key is invalid. File-write failures are not propagated by this wrapper.
        #
        # . Usage
        #   ```bash
        #   sgnd_cfg_set SGND_UI_STYLE dark
        #   ```
    sgnd_cfg_set() {
        local key="$1" val="$2"
        _sgnd_is_ident "$key" || { saywarning "Skipping invalid cfg key: '$key'"; return 1; }
        local file
        file="${SGND_CFG_FILE}"
        _sgnd_kv_set "$file" "$key" "$val"
        printf -v "$key" '%s' "$val"
    }
    # fn: sgnd_cfg_unset - Remove a configuration key and unset its variable.
        # . Purpose
        #   Remove a configuration key and unset its variable.
        #
        # . Arguments
        #   $1  Valid shell-identifier key.
        #
        # . Side effects
        #   Updates SGND_CFG_FILE and unsets the matching shell variable.
        #
        # . Returns
        #   0 after unsetting the variable; 1 if the key is invalid. File-write failures may be masked by the final unset.
        #
        # . Usage
        #   ```bash
        #   sgnd_cfg_unset SGND_UI_STYLE
        #   ```
    sgnd_cfg_unset() {
        local key="$1"
        _sgnd_is_ident "$key" || { saywarning "Skipping invalid cfg key: '$key'"; return 1; }
        local file
        file="${SGND_CFG_FILE}"
        _sgnd_kv_unset "$file" "$key"
        unset "$key" || true
    }
    # fn: sgnd_cfg_reset - Remove the active configuration file.
        # . Purpose
        #   Remove the active configuration file.
        #
        # . Side effects
        #   Deletes SGND_CFG_FILE; does not explicitly unset previously loaded variables.
        #
        # . Returns
        #   0 when removed or already absent; otherwise the removal command status.
        #
        # . Usage
        #   ```bash
        #   sgnd_cfg_reset
        #   ```
    sgnd_cfg_reset() {
        local file
        file="${SGND_CFG_FILE}"
        _sgnd_kv_reset_file "$file"
    }
    # fn: sgnd_cfg_get - Retrieve the persisted value of one configuration key.
        # . Purpose
        #   Retrieve the persisted value of one configuration key.
        #
        # . Arguments
        #   $1  Valid shell-identifier key.
        #
        # . Output
        #   Writes the stored value without a newline.
        #
        # . Returns
        #   0 when present; 1 if invalid/absent; 2 when the config file is unreadable.
        #
        # . Usage
        #   ```bash
        #   sgnd_cfg_get SGND_UI_STYLE
        #   ```
    sgnd_cfg_get() {
        local key="$1"
        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid cfg key: '$key'"
            return 1
        }
        _sgnd_kv_get "$SGND_CFG_FILE" "$key"
    }
    # fn: sgnd_cfg_has - Check whether the active configuration contains a key.
        # . Purpose
        #   Check whether the active configuration contains a key.
        #
        # . Arguments
        #   $1  Valid shell-identifier key.
        #
        # . Returns
        #   0 if present; 1 when invalid or absent; 2 when the file is unreadable.
        #
        # . Usage
        #   ```bash
        #   sgnd_cfg_has SGND_UI_STYLE
        #   ```
    sgnd_cfg_has() {
        local key="$1"
        _sgnd_is_ident "$key" || {
            saywarning "Skipping invalid cfg key: '$key'"
            return 1
        }
        _sgnd_kv_has "$SGND_CFG_FILE" "$key"
    }
    # fn: sgnd_cfg_show_keys - Display specified configuration keys and their effective stored values.
        # . Purpose
        #   Display specified configuration keys and their effective stored values.
        #
        # . Description
        #   Missing keys are shown as <unset>; present keys with empty values are shown as "".
        #
        # . Arguments
        #   $@  Names of the keys to display.
        #
        # . Output
        #   Writes a formatted configuration summary through Framework UI printers.
        #
        # . Returns
        #   Status returned by the final sgnd_print call.
        #
        # . Usage
        #   ```bash
        #   sgnd_cfg_show_keys SGND_UI_STYLE SGND_FRAMEWORK_ROOT
        #   ```
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
    # fn: sgnd_cfg_has_audience - Check whether a specification array contains an audience.
        # . Purpose
        #   Check whether a specification array contains an audience.
        #
        # . Description
        #   Inspects the audience field in each configuration-variable specification.
        #
        # . Arguments
        #   $1  Name of the specification array.
        #   $2  Required audience: system or user.
        #
        # . Returns
        #   0 when an entry matches the desired audience; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_cfg_has_audience SGND_SCRIPT_GLOBALS user
        #   ```
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
    # fn: _sgnd_cfg_write_template_header - Generate a comment header for a configuration template.
        # . Purpose
        #   Generate a comment header for a configuration template.
        #
        # . Arguments
        #   $1  Optional domain name (defaults to configuration).
        #   $2  Optional audience (defaults to user).
        #
        # . Output
        #   Writes comment lines to standard output.
        #
        # . Returns
        #   0 after printing the header.
        #
        # . Usage
        #   ```bash
        #   _sgnd_cfg_write_template_header Framework system
        #   ```
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
    # fn: sgnd_cfg_load_file - Load valid key/value lines from a readable config file.
        # . Purpose
        #   Load valid key/value lines from a readable config file.
        #
        # . Arguments
        #   $1  Path to file; unreadable files are ignored.
        #
        # . Side effects
        #   Sets valid shell variables without evaluating the values as shell code.
        #
        # . Returns
        #   0 after processing, including when the file is missing.
        #
        # . Usage
        #   ```bash
        #   sgnd_cfg_load_file "/etc/solidgroundux/sample.cfg"
        #   ```
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
    # fn: sgnd_cfg_create_missing_domain_files - Create missing system and user configuration skeletons as permitted.
        # . Purpose
        #   Create missing system and user configuration skeletons as permitted.
        #
        # . Description
        #   Only creates system configuration when running as root. Creates a user skeleton when user-scope variables are declared.
        #
        # . Arguments
        #   $1  Domain label for reporting.
        #   $2  System configuration file path.
        #   $3  User configuration file path.
        #   $4  Name of array containing variable specifications.
        #   $5  Optional mode (defaults to script).
        #
        # . Side effects
        #   Creates directories and missing config files; logs results through sayinfo/saydebug.
        #
        # . Returns
        #   0 when all required files exist or were created; 1 for invalid input or creation failure.
        #
        # . Usage
        #   ```bash
        #   sgnd_cfg_create_missing_domain_files Framework "$SGND_SYSCFG_FILE" "$SGND_USRCFG_FILE" SGND_SCRIPT_GLOBALS script
        #   ```
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
    # fn: sgnd_cfg_domain_apply - Apply system then user configuration files for a domain.
        # . Purpose
        #   Apply system then user configuration files for a domain.
        #
        # . Description
        #   Creates missing configuration skeletons where permitted, then loads system-scope followed by user-scope values. Does not load the default values itself.
        #
        # . Arguments
        #   $1  Domain label.
        #   $2  System config path.
        #   $3  User config path.
        #   $4  Name of variable-specification array.
        #   $5  Optional mode (defaults to script).
        #
        # . Side effects
        #   May create missing files and updates configuration variables in the current shell.
        #
        # . Returns
        #   0 when configuration files were processed; 1 for invalid input or skeleton-creation failure.
        #
        # . Usage
        #   ```bash
        #   sgnd_cfg_domain_apply Framework "$SGND_SYSCFG_FILE" "$SGND_USRCFG_FILE" SGND_SCRIPT_GLOBALS script
        #   ```
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
    # fn: sgnd_state_load - Load a state file into shell variables
        # . Purpose
        #   Load a state file into shell variables.
        #
        # . Description
        #   Reads validated KEY=VALUE entries into the current shell, using SGND_STATE_FILE when --file is omitted.
        #
        # . Arguments
        #   --file FILE  Optional state file path.
        #
        # . Side effects
        #   Updates variables in the calling shell.
        #
        # . Returns
        #   0 if the selected file was processed (including a missing file); 1 for an invalid or missing option.
        #
        # . Usage
        #   ```bash
        #   sgnd_state_load --file "$SGND_FRAMEWORK_STATE_FILE"
        #   ```
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

    # fn: sgnd_state_set - Persist a state key and update its shell variable
        # . Purpose
        #   Persist a state key and update its shell variable.
        #
        # . Arguments
        #   --file FILE  Optional state file path.
        #   KEY         Valid shell identifier.
        #   VALUE       String to persist.
        #
        # . Side effects
        #   Modifies the state file and variable KEY in the calling shell.
        #
        # . Returns
        #   0 on successful update; 1 for invalid input or file failure.
        #
        # . Usage
        #   ```bash
        #   sgnd_state_set --file "$SGND_FRAMEWORK_STATE_FILE" SGND_UI_STYLE "$SGND_UI_STYLE"
        #   ```
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

    # fn: sgnd_state_unset - Remove a persisted key and unset its variable
        # . Purpose
        #   Remove a persisted key and unset its variable.
        #
        # . Arguments
        #   --file FILE  Optional state file path.
        #   KEY         Valid shell identifier to remove.
        #
        # . Side effects
        #   Updates the state file and unsets the named shell variable.
        #
        # . Returns
        #   0 on success; 1 for invalid input or file failure.
        #
        # . Usage
        #   ```bash
        #   sgnd_state_unset --file "$SGND_FRAMEWORK_STATE_FILE" SGND_UI_STYLE
        #   ```
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

    # fn: sgnd_state_reset - Reset the selected state file
        # . Purpose
        #   Reset the selected state file.
        #
        # . Arguments
        #   --file FILE  Optional state file path.
        #
        # . Side effects
        #   Removes the selected state file.
        #
        # . Returns
        #   0 when no file is configured or reset succeeds; nonzero on failure.
        #
        # . Usage
        #   ```bash
        #   sgnd_state_reset --file "$SGND_FRAMEWORK_STATE_FILE"
        #   ```
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

    # fn: sgnd_state_get - Retrieve a persisted state value
        # . Purpose
        #   Retrieve a persisted state value.
        #
        # . Arguments
        #   --file FILE  Optional state file path.
        #   KEY         Valid shell identifier to retrieve.
        #
        # . Output
        #   Writes the value to standard output without modifying shell variables.
        #
        # . Returns
        #   0 when found; 1 for missing key, invalid input or missing state file.
        #
        # . Usage
        #   ```bash
        #   value="$(sgnd_state_get --file "$SGND_FRAMEWORK_STATE_FILE" SGND_UI_STYLE)"
        #   ```
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

    # fn: sgnd_state_has - Check whether a state key is present
        # . Purpose
        #   Check whether a state key is present.
        #
        # . Arguments
        #   --file FILE  Optional state file path.
        #   KEY         Valid shell identifier to test.
        #
        # . Returns
        #   0 if the key exists; 1 if absent or invalid.
        #
        # . Usage
        #   ```bash
        #   if sgnd_state_has SGND_UI_STYLE; then :; fi
        #   ```
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

    # fn: sgnd_state_save_keys - Persist selected shell variables as state keys
        # . Purpose
        #   Persist selected shell variables as state keys.
        #
        # . Description
        #   Takes names directly and/or from a named array. Unset variables are stored as empty values. Invalid keys are skipped.
        #
        # . Arguments
        #   --file FILE          Optional state file.
        #   --array ARRAY_NAME    Name of an indexed array containing keys.
        #   KEY...                Additional shell-variable names.
        #
        # . Side effects
        #   Creates or updates entries in the selected state file.
        #
        # . Returns
        #   0 after successfully writing the valid keys; 1 on invalid file/array or write failure.
        #
        # . Usage
        #   ```bash
        #   sgnd_state_save_keys --file "$SGND_FRAMEWORK_STATE_FILE" --array SGND_FRAMEWORK_STATE
        #   ```
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

    # fn: sgnd_state_load_keys - Restore selected persisted keys into shell variables
        # . Purpose
        #   Restore selected persisted keys into shell variables.
        #
        # . Description
        #   Takes key names directly or from a named array. Absent keys leave their variables unchanged; invalid names are skipped.
        #
        # . Arguments
        #   --file FILE          Optional state file.
        #   --array ARRAY_NAME    Name of an indexed array containing keys.
        #   KEY...                Additional state keys.
        #
        # . Side effects
        #   Assigns values to shell variables for keys found in the file.
        #
        # . Returns
        #   0 after processing valid names; 1 on invalid file or array.
        #
        # . Usage
        #   ```bash
        #   sgnd_state_load_keys --file "$SGND_FRAMEWORK_STATE_FILE" --array SGND_FRAMEWORK_STATE
        #   ```
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

    # fn: sgnd_state_list_keys - List keys stored in a state file
        # . Purpose
        #   List keys stored in a state file.
        #
        # . Arguments
        #   --file FILE  Optional state file path.
        #
        # . Output
        #   Writes one key name per line to standard output.
        #
        # . Returns
        #   0 when listed or file unavailable; 1 on invalid options.
        #
        # . Usage
        #   ```bash
        #   sgnd_state_list_keys --file "$SGND_FRAMEWORK_STATE_FILE"
        #   ```
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
