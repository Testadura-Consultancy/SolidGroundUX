# =====================================================================================
# SolidGroundUX - Header Parser
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627412
#   Checksum    : 1277f415e6707a9281d5a01fe0197f7645dc56cc261ea7e1f0da64c8fc718948
#   Source      : sgnd-comment-header-parser.sh
#   Type        : library
#   Group       : Common Core
#   Purpose     : Read, parse, and update canonical script header comments in SolidGroundUX files
#
# Description:
#   Provides parsing, lookup, and update utilities for canonical script header comments
#   used throughout the SolidGroundUX framework.
#
#   The library:
#     - Detects top-level canonical header sections
#     - Loads header section fields into sgnd-datatable structures
#     - Extracts banner information such as product and title
#     - Reads individual header field values from structured sections
#     - Updates existing header fields while preserving formatting
#     - Adds missing fields where required
#     - Supports checksum, build, and semantic version metadata workflows
#
# Design principles:
#   - Header comments are treated as structured, machine-readable data
#   - Header parsing and header mutation are kept predictable and convention-based
#   - Existing field formatting is preserved wherever possible
#   - Metadata workflows remain independent from higher-level UI logic
#
# Role in framework:
#   - Core header metadata parsing and update layer for script tooling
#   - Supports release preparation and other header-aware development utilities
#   - Provides the canonical API for header field inspection and mutation
#
# Non-goals:
#   - Parsing arbitrary inline documentation blocks in source bodies
#   - Rendering documentation output
#   - Acting as a general-purpose text processing library
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
    # fn: sgnd_header_read - Header read
        # . Purpose
        #   Read a SolidGroundUX script header from a file.
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
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_header_read "/tmp/sgnd-example.txt"
    sgnd_header_read() {
        local file="${1:?missing file}"
        local line=""
        local started=0
        local result=""

        [[ -r "$file" ]] || return 1

        while IFS= read -r line || [[ -n "$line" ]]; do
            if (( ! started )); then
                [[ "$line" == '#!'* ]] && continue
                [[ -z "$line" ]] && continue
            fi

            if [[ "$line" == \#* ]]; then
                started=1
                result+="$line"$'\n'
                continue
            fi

            if (( started )); then
                break
            fi

            [[ -z "$line" ]] || break
        done < "$file"

        printf '%s' "${result%$'\n'}"
    }
    # fn: sgnd_header_load_section_to_dt - Header load section to dt
        # . Purpose
        #   Load a named header section into a SolidGroundUX datatable.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  FILE - File path.
        #   $2  SECTION - Header section name.
        #   $3  SCHEMA - Datatable schema string.
        #   $4  TABLE_NAME - Variable, field, or item name.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_header_load_section_to_dt "/tmp/sgnd-example.txt" "example-2" "example-3" "example-4"
    sgnd_header_load_section_to_dt() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local schema="${3:?missing schema}"
        local table_name="${4:?missing table name}"

        local line=""
        local key=""
        local value=""
        local in_section=0

        while IFS= read -r line; do
            [[ "$line" == \#* ]] || break
            [[ "$line" =~ ^\#[[:space:]]*[=-]+[[:space:]]*$ ]] && continue

            if [[ "$line" == "# $section:" ]]; then
                in_section=1
                continue
            fi

            if (( in_section )) && sgnd_header_is_section_header "$line"; then
                break
            fi

            if (( in_section )); then
                line="${line#\#}"
                line="${line# }"

                key="${line%%:*}"
                value="${line#*:}"

                key="$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
                value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

                [[ -n "$key" ]] || continue

                sgnd_dt_append "$schema" "$table_name" "$section" "$key" "$value" || return 1
            fi
        done < "$file"
    }
    # fn: sgnd_header_is_section_header - Header is section header
        # . Purpose
        #   Check whether a line starts a named header section.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  LINE - Input line.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_header_is_section_header "example" && printf 'Success\n' || printf 'Failed\n'
    sgnd_header_is_section_header() {
        local line="${1-}"

        [[ "$line" =~ ^\#[[:space:]][A-Za-z][A-Za-z[:space:]-]*:[[:space:]]*$ ]] || return 1
        [[ "$line" == "#   "* ]] && return 1
        return 0
    }
    # fn: sgnd_header_buffer_load - Header buffer load
        # . Purpose
        #   Load a file header into the reusable header buffer.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Arguments
        #   $1  FILE - File path.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_header_buffer_load "/tmp/sgnd-example.txt" "example-2"
    sgnd_header_buffer_load() {
        local file="${1:?missing file}"

        [[ -r "$file" ]] || return 1

        SGND_HEADER_BUFFER_FILE="$file"
        SGND_HEADER_BUFFER_TEXT="$(sgnd_header_read "$file")" || return 1
    }
    # fn: sgnd_header_buffer_get_section - Header buffer get section
        # . Purpose
        #   Extract a section from the reusable header buffer.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Arguments
        #   $1  SECTION - Header section name.
        #   $2  _OUTVAR - Target variable name.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_header_buffer_get_section "example" "example-2"
    sgnd_header_buffer_get_section() {
        local section="${1:?missing section}"
        local _outvar="${2:?missing outvar}"

        [[ -n "${SGND_HEADER_BUFFER_TEXT:-}" ]] || return 1
        sgnd_header_get_section_from_text "$SGND_HEADER_BUFFER_TEXT" "$section" "$_outvar"
    }
    # fn: sgnd_header_calc_checksum - Header calc checksum
        # . Purpose
        #   Calculate the managed-body checksum for a script file.
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
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_header_calc_checksum "/tmp/sgnd-example.txt" "example-2"
    sgnd_header_calc_checksum() {
        local file="${1:?missing file}"

        [[ -r "$file" ]] || return 1

        awk '
            BEGIN { in_metadata = 0 }
            /^# Metadata:$/ { in_metadata = 1; print; next }
            in_metadata && /^#[[:space:]][A-Za-z][A-Za-z[:space:]-]*:[[:space:]]*$/ { in_metadata = 0 }
            in_metadata && /^#[[:space:]]+Version[[:space:]]*:/ { next }
            in_metadata && /^#[[:space:]]+Build[[:space:]]*:/ { next }
            in_metadata && /^#[[:space:]]+Checksum[[:space:]]*:/ { next }
            { print }
        ' "$file" | sha256sum | awk '{print $1}'
    }
    # fn: sgnd_header_bump_version - Header bump version
        # . Purpose
        #   Bump a semantic version string according to a requested bump mode.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  FILE - File path.
        #   $2  MODE - Operation mode.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_header_bump_version "/tmp/sgnd-example.txt" "normal"
    sgnd_header_bump_version() {
        local file="${1:?missing file}"
        local mode="${2:-none}"
        local stored_checksum=""
        local current_checksum=""
        local version=""
        local major="0"
        local minor="0"
        local new_version=""
        local new_build=""
        local needs_update=0

        SGND_HEADER_BUMP_CHANGED=0

        [[ -r "$file" ]] || return 1

        case "$mode" in
            none|major|minor) ;;
            *) return 1 ;;
        esac

        current_checksum="$(sgnd_header_calc_checksum "$file")" || return 1

        if ! sgnd_header_get_field "$file" "Metadata" "Checksum" stored_checksum; then
            stored_checksum=""
            sgnd_header_add_field "$file" "Metadata" "Checksum" "$current_checksum" || return 1
            SGND_HEADER_BUMP_CHANGED=1
        fi

        saydebug "stored checksum : $stored_checksum"
        saydebug "current checksum: $current_checksum"
        saydebug "mode            : $mode"

        if [[ "$stored_checksum" != "$current_checksum" ]]; then
            needs_update=1
        fi

        if [[ "$mode" != "none" ]]; then
            sgnd_header_get_field "$file" "Metadata" "Version" version || version="1.0"

            if [[ "$version" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
                major="${BASH_REMATCH[1]}"
                minor="${BASH_REMATCH[2]}"
            else
                major="1"
                minor="0"
            fi

            case "$mode" in
                major)
                    major=$((major + 1))
                    minor=0
                    ;;
                minor)
                    minor=$((minor + 1))
                    ;;
            esac

            new_version="${major}.${minor}"

            if ! sgnd_header_get_field "$file" "Metadata" "Version" version || [[ "$version" != "$new_version" ]]; then
                sgnd_header_upsert_field "$file" "Metadata" "Version" "$new_version" || return 1
                SGND_HEADER_BUMP_CHANGED=1
            fi

            needs_update=1
            current_checksum="$(sgnd_header_calc_checksum "$file")" || return 1
        fi

        if (( needs_update )); then
            new_build="$(date +%y%j%H)"

            sgnd_header_upsert_field "$file" "Metadata" "Build" "$new_build" || return 1
            sgnd_header_upsert_field "$file" "Metadata" "Checksum" "$current_checksum" || return 1
            SGND_HEADER_BUMP_CHANGED=1
        fi

        return 0
    }
    # fn: sgnd_header_get_section - Header get section
        # . Purpose
        #   Read a named header section from a script file.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  FILE - File path.
        #   $2  SECTION - Header section name.
        #   $3  _RESULTVAR - Target variable name.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_header_get_section "/tmp/sgnd-example.txt" "example-2" "example-3"
    sgnd_header_get_section() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local _resultvar="${3:?missing result var}"

        local line=""
        local capture=0
        local result=""

        while IFS= read -r line; do
            [[ "$line" == \#* ]] || break
            [[ "$line" =~ ^\#[[:space:]]*[=-]+[[:space:]]*$ ]] && continue

            if [[ "$line" == "# $section:" ]]; then
                capture=1
                continue
            fi

            if (( capture )) && sgnd_header_is_section_header "$line"; then
                break
            fi

            if (( capture )); then
                line="${line#\#}"
                [[ "$line" == " "* ]] && line="${line# }"

                [[ -z "$line" ]] && break

                result+="$line"$'\n'
            fi
        done < "$file"

        result="${result%$'\n'}"
        printf -v "$_resultvar" '%s' "$result"
    }
    # fn: sgnd_header_get_section_from_text - Header get section from text
        # . Purpose
        #   Extract a named header section from supplied header text.
        #
        # . Behavior
        #   - Extracts the requested comment-header section from buffered header text.
        #   - Stops at the next section header, blank line, or closing header separator.
        #
        # . Arguments
        #   $1  TEXT - Text value.
        #   $2  SECTION - Header section name.
        #   $3  _OUTVAR - Target variable name.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_header_get_section_from_text "SolidGroundUX example" "example-2" "example-3"
    sgnd_header_get_section_from_text() {
        local text="${1-}"
        local section="${2:?missing section}"
        local _outvar="${3:?missing outvar}"

        local line=""
        local found=0
        local in_section=0
        local result=""

        while IFS= read -r line; do
            if [[ "$line" == "# $section:" ]]; then
                found=1
                in_section=1
                continue
            fi

            if (( in_section )) && [[ "$line" =~ ^\#[[:space:]]*[=-]+[[:space:]]*$ ]]; then
                break
            fi

            if (( in_section )) && sgnd_header_is_section_header "$line"; then
                break
            fi

            if (( in_section )); then
                line="${line#\#}"
                line="${line#"${line%%[![:space:]]*}"}"
                
                [[ -z "$line" ]] && break

                result+="$line"$'\n'
            fi
        done <<< "$text"

        printf -v "$_outvar" '%s' "${result%$'\n'}"
        (( found ))
    }
    # fn: sgnd_header_get_banner_parts_from_text - Header get banner parts from text
        # . Purpose
        #   Parse banner name, version, and release fields from supplied header text.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  TEXT - Text value.
        #   $2  _PRODUCT_VAR - Target variable name.
        #   $3  _TITLE_VAR - Target variable name.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_header_get_banner_parts_from_text "SolidGroundUX example" "example-2" "SolidGroundUX example"
    sgnd_header_get_banner_parts_from_text() {
        local text="${1-}"
        local _product_var="${2:?missing product var}"
        local _title_var="${3:?missing title var}"

        local line=""
        local banner_line=""
        local found_sep=0
        local parsed_product=""
        local parsed_title=""

        while IFS= read -r line; do
            if (( ! found_sep )); then
                if [[ "$line" =~ ^\#[[:space:]]*={3,}[[:space:]]*$ ]]; then
                    found_sep=1
                fi
                continue
            fi

            banner_line="$line"
            break
        done <<< "$text"

        if [[ "$banner_line" =~ ^\#[[:space:]]*(.+)[[:space:]]-[[:space:]](.+)[[:space:]]*$ ]]; then
            parsed_product="${BASH_REMATCH[1]}"
            parsed_title="${BASH_REMATCH[2]}"

            parsed_product="${parsed_product%"${parsed_product##*[![:space:]]}"}"
            parsed_title="${parsed_title#"${parsed_title%%[![:space:]]*}"}"
            parsed_title="${parsed_title%"${parsed_title##*[![:space:]]}"}"

            printf -v "$_product_var" '%s' "$parsed_product"
            printf -v "$_title_var" '%s' "$parsed_title"
            return 0
        fi

        printf -v "$_product_var" '%s' ""
        printf -v "$_title_var" '%s' ""
        return 1
    }
    # fn: sgnd_header_parse_banner_line - Header parse banner line
        # . Purpose
        #   Parse one SolidGroundUX banner line into structured fields.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  LINE - Input line.
        #   $2  _PRODUCT_VAR - Target variable name.
        #   $3  _TITLE_VAR - Target variable name.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_header_parse_banner_line "example" "example-2" "SolidGroundUX example"
    sgnd_header_parse_banner_line() {
        local line="${1-}"
        local _product_var="${2:?missing product var}"
        local _title_var="${3:?missing title var}"

        local parsed_product=""
        local parsed_title=""

        if [[ "$line" =~ ^\#[[:space:]]*(.+)[[:space:]]-[[:space:]](.+)[[:space:]]*$ ]]; then
            parsed_product="${BASH_REMATCH[1]}"
            parsed_title="${BASH_REMATCH[2]}"

            parsed_product="${parsed_product%"${parsed_product##*[![:space:]]}"}"
            parsed_title="${parsed_title#"${parsed_title%%[![:space:]]*}"}"
            parsed_title="${parsed_title%"${parsed_title##*[![:space:]]}"}"

            printf -v "$_product_var" '%s' "$parsed_product"
            printf -v "$_title_var" '%s' "$parsed_title"
            return 0
        fi

        printf -v "$_product_var" '%s' ""
        printf -v "$_title_var" '%s' ""
        return 1
    }
    # fn: sgnd_header_get_field - Header get field
        # . Purpose
        #   Read a named metadata field from a script file.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  FILE - File path.
        #   $2  SECTION - Header section name.
        #   $3  FIELD - Metadata field name.
        #   $4  _RESULTVAR - Target variable name.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_header_get_field "/tmp/sgnd-example.txt" "example-2" "example-3" "example-4"
    sgnd_header_get_field() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local field="${3:?missing field}"
        local _resultvar="${4:?missing result var}"

        local line=""
        local key=""
        local value=""
        local in_section=0

        while IFS= read -r line; do
            [[ "$line" == \#* ]] || break
            [[ "$line" =~ ^\#[[:space:]]*[=-]+[[:space:]]*$ ]] && continue

            if [[ "$line" == "# $section:" ]]; then
                in_section=1
                continue
            fi

            if (( in_section )) && sgnd_header_is_section_header "$line"; then
                break
            fi

            if (( in_section )); then
                line="${line#\#}"
                line="${line# }"

                key="${line%%:*}"
                value="${line#*:}"

                key="$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
                value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

                if [[ "$key" == "$field" ]]; then
                    printf -v "$_resultvar" '%s' "$value"
                    return 0
                fi
            fi
        done < "$file"

        printf -v "$_resultvar" '%s' ""
        return 1
    }
    # fn: sgnd_header_get_field_value - Header get field value
        # . Purpose
        #   Read the value part of a named metadata field from a script file.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  FILE - File path.
        #   $2  SECTION - Header section name.
        #   $3  FIELD - Metadata field name.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_header_get_field_value "/tmp/sgnd-example.txt" "example-2" "example-3"
    sgnd_header_get_field_value() {
        local file="$1"
        local section="$2"
        local field="$3"
        local value=""

        sgnd_header_get_field "$file" "$section" "$field" value
        printf '%s' "$value"
    }
    # fn: sgnd_header_get_banner_parts - Header get banner parts
        # . Purpose
        #   Read banner name, version, and release fields from a script file.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  FILE - File path.
        #   $2  _PRODUCT_VAR - Target variable name.
        #   $3  _TITLE_VAR - Target variable name.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_header_get_banner_parts "/tmp/sgnd-example.txt" "example-2" "SolidGroundUX example"
    sgnd_header_get_banner_parts() {
        local file="${1:?missing file}"
        local _product_var="${2:?missing product var}"
        local _title_var="${3:?missing title var}"

        local line=""
        local banner_line=""
        local found_sep=0
        local parsed_product=""
        local parsed_title=""

        while IFS= read -r line; do
            if (( ! found_sep )); then
                if [[ "$line" =~ ^\#[[:space:]]*={3,}[[:space:]]*$ ]]; then
                    found_sep=1
                fi
                continue
            fi

            banner_line="$line"
            break
        done < "$file"

        if [[ "$banner_line" =~ ^\#[[:space:]]*(.+)[[:space:]]-[[:space:]](.+)[[:space:]]*$ ]]; then
            parsed_product="${BASH_REMATCH[1]}"
            parsed_title="${BASH_REMATCH[2]}"

            parsed_product="${parsed_product%"${parsed_product##*[![:space:]]}"}"
            parsed_title="${parsed_title#"${parsed_title%%[![:space:]]*}"}"
            parsed_title="${parsed_title%"${parsed_title##*[![:space:]]}"}"

            printf -v "$_product_var" '%s' "$parsed_product"
            printf -v "$_title_var" '%s' "$parsed_title"
            return 0
        fi

        printf -v "$_product_var" '%s' ""
        printf -v "$_title_var" '%s' ""
        return 1
    }
    # fn: sgnd_section_get_field_value - Section get field value
        # . Purpose
        #   Read the value of a field from an already extracted section.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  SECTION - Header section name.
        #   $2  FIELD - Metadata field name.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_section_get_field_value "example" "example-2"
    sgnd_section_get_field_value() {
        local section="${1-}"
        local field="${2:?missing field}"
        local line=""
        local key=""
        local value=""

        while IFS= read -r line; do
            [[ "$line" == *:* ]] || continue

            key="${line%%:*}"
            value="${line#*:}"

            key="${key#"${key%%[![:space:]]*}"}"
            key="${key%"${key##*[![:space:]]}"}"

            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"

            if [[ "$key" == "$field" ]]; then
                printf '%s' "$value"
                return 0
            fi
        done <<< "$section"

        printf ''
    }
    # fn: sgnd_header_add_field - Header add field
        # . Purpose
        #   Add a metadata field to a named header section.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  FILE - File path.
        #   $2  SECTION - Header section name.
        #   $3  FIELD - Metadata field name.
        #   $4  VALUE - Value to read, validate, render, or store.
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
        #   sgnd_header_add_field "/tmp/sgnd-example.txt" "example-2" "example-3" "dark"
    sgnd_header_add_field() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local field="${3:?missing field}"
        local value="${4-}"

        local tmp_file=""
        local line=""
        local in_section=0
        local inserted=0
        local saw_section=0

        tmp_file="$(mktemp)" || return 1

        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "# $section:" ]]; then
                in_section=1
                saw_section=1
                printf '%s\n' "$line" >> "$tmp_file"
                continue
            fi

            if (( in_section )) && sgnd_header_is_section_header "$line"; then
                printf '#   %s : %s\n' "$field" "$value" >> "$tmp_file"
                printf '%s\n' "$line" >> "$tmp_file"
                inserted=1
                in_section=0
                continue
            fi

            printf '%s\n' "$line" >> "$tmp_file"
        done < "$file"

        if (( in_section && saw_section && ! inserted )); then
            printf '#   %s : %s\n' "$field" "$value" >> "$tmp_file"
            inserted=1
        fi

        if (( ! saw_section )); then
            rm -f "$tmp_file"
            return 2
        fi

        if (( ${FLAG_DRYRUN:-0} )); then
            sayinfo "Would have inserted [$section] $field in $file to: $value"
            rm -f "$tmp_file"
            return 0
        fi

        if (( inserted )); then
            sgnd_safe_replace_file "$tmp_file" "$file" || {
                rm -f "$tmp_file"
                return 1
            }
            return 0
        fi

        rm -f "$tmp_file"
        return 1
    }
    # fn: sgnd_header_upsert_field - Header upsert field
        # . Purpose
        #   Add or replace a metadata field in a named header section.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  FILE - File path.
        #   $2  SECTION - Header section name.
        #   $3  FIELD - Metadata field name.
        #   $4  VALUE - Value to read, validate, render, or store.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_header_upsert_field "/tmp/sgnd-example.txt" "example-2" "example-3" "dark"
    sgnd_header_upsert_field() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local field="${3:?missing field}"
        local value="${4-}"
        local rc=0

        sgnd_header_set_field "$file" "$section" "$field" "$value"
        rc=$?

        case "$rc" in
            0) return 0 ;;
            2) sgnd_header_add_field "$file" "$section" "$field" "$value"; return $? ;;
            *) return "$rc" ;;
        esac
    }
    # fn: sgnd_header_set_field - Header set field
        # . Purpose
        #   Set an existing metadata field in a named header section.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  FILE - File path.
        #   $2  SECTION - Header section name.
        #   $3  FIELD - Metadata field name.
        #   $4  VALUE - Value to read, validate, render, or store.
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
        #   sgnd_header_set_field "/tmp/sgnd-example.txt" "example-2" "example-3" "dark"
    sgnd_header_set_field() {
        local file="${1:?missing file}"
        local section="${2:?missing section}"
        local field="${3:?missing field}"
        local value="${4-}"

        local tmp_file=""
        local line=""
        local in_section=0
        local replaced=0

        local raw=""
        local lead_ws=""
        local label_part=""
        local sep_part=""
        local value_part=""
        local key=""

        tmp_file="$(mktemp)" || return 1

        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" != \#* ]]; then
                printf '%s\n' "$line" >> "$tmp_file"
                continue
            fi

            if [[ "$line" == "# $section:" ]]; then
                in_section=1
                printf '%s\n' "$line" >> "$tmp_file"
                continue
            fi

            if (( in_section )) && sgnd_header_is_section_header "$line"; then
                in_section=0
                printf '%s\n' "$line" >> "$tmp_file"
                continue
            fi

            if (( in_section )); then
                raw="${line#\#}"

                # Preserve exact formatting:
                #   group 1 = leading whitespace after '#'
                #   group 2 = label part exactly as written (including spaces before ':')
                #   group 3 = separator part beginning with ':' and including spaces/tabs after it
                #   group 4 = existing value part
                if [[ "$raw" =~ ^([[:space:]]*)([^:]+)(:[[:space:]]*)(.*)$ ]]; then
                    lead_ws="${BASH_REMATCH[1]}"
                    label_part="${BASH_REMATCH[2]}"
                    sep_part="${BASH_REMATCH[3]}"
                    value_part="${BASH_REMATCH[4]}"

                    key="$(printf '%s' "$label_part" | sed 's/[[:space:]]*$//')"

                    if [[ "$key" == "$field" ]]; then
                        printf '#%s%s%s%s\n' \
                            "$lead_ws" \
                            "$label_part" \
                            "$sep_part" \
                            "$value" >> "$tmp_file"
                        replaced=1
                        continue
                    fi
                fi
            fi

            printf '%s\n' "$line" >> "$tmp_file"
        done < "$file"

        if (( replaced )); then
            if (( ${FLAG_DRYRUN:-0} )); then
                sayinfo "Would have updated [$section] $field in $file to: $value"
                rm -f "$tmp_file"
                return 0
            fi

            sgnd_safe_replace_file "$tmp_file" "$file" || {
                rm -f "$tmp_file"
                return 1
            }
            return 0
        fi

        rm -f "$tmp_file"
        return 2
    }
    
    # fn: sgnd_framework_set_version - Update framework version identity
        # . Purpose
        #   Update the framework version identity stored in sgnd-bootstrap-env.sh.
        #
        # . Behavior
        #   - Updates SGND_VERSION with the supplied framework version.
        #   - Updates SGND_BUILD with the supplied framework build number.
        #   - Preserves all other file contents and formatting.
        #   - Performs in-place replacement of existing assignments only.
        #
        # . Arguments
        #   $1  FILE
        #       Path to sgnd-bootstrap-env.sh.
        #   $2  VERSION
        #       Framework version (for example 1.6).
        #   $3  BUILD
        #       Framework build number (for example 2618912).
        #
        # . Returns
        #   0 when the framework version information was updated.
        #   1 when arguments are invalid, the file is unreadable, or an update fails.
        #
        # . Usage
        #   sgnd_framework_set_version "/tmp/sgnd-example.txt" "1.8.0" "1.7.9"
    sgnd_framework_set_version() {
        local file="${1:-}"
        local version="${2:-}"
        local build="${3:-}"

        [[ -n "$file" ]]    || return 1
        [[ -n "$version" ]] || return 1
        [[ -n "$build" ]]   || return 1
        [[ -f "$file" ]]    || return 1
        [[ -w "$file" ]]    || return 1

        sed -Ei \
            -e "s|^([[:space:]]*SGND_VERSION=).*|\1\"$version\"|" \
            -e "s|^([[:space:]]*SGND_BUILD=).*|\1\"$build\"|" \
            "$file" || return 1

        return 0
    }




