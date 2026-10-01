# =====================================================================================
# SolidGroundUX - Datatable
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627412
#   Checksum    : c631457fdd2c6412b1e9c5736560b372a21f2666a6586da77d1293c04ae41cf3
#   Source      : sgnd-datatable.sh
#   Type        : library
#   Group       : Common Core
#   Purpose     : Provide lightweight tabular data structures and utilities
#
# Description:
#   Provides a lightweight, schema-driven datatable abstraction for handling
#   structured data within shell scripts.
#
#   The library:
#     - Defines schema-based row structures using delimited fields
#     - Stores and manages tabular data in indexed arrays
#     - Supports row insertion, retrieval, and iteration
#     - Enables field-based access using schema definitions
#     - Provides helper functions for filtering and transformation
#
# Design principles:
#   - Minimal abstraction on top of native shell arrays
#   - Schema-driven access for readability and consistency
#   - Predictable and explicit data handling
#   - Lightweight implementation without external dependencies
#
# Role in framework:
#   - Core data structure used across SolidGroundUX tooling
#   - Backbone for metadata parsing, UI rendering, and data exchange
#
# Non-goals:
#   - Full relational data modeling or query capabilities
#   - Persistent storage or database functionality
#   - Replacement for external data processing tools
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
# - DDL functions -----------------------------------------------------------------
    # fn: sgnd_dt_array_length - Dt array length
        # . Purpose
        #   Return the number of items in an indexed Bash array.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  ARRAY_NAME - Variable, field, or item name.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_dt_array_length "example"
    sgnd_dt_array_length() {
        local array_name="${1:?missing array name}"
        local -n array_ref="$array_name"

        printf '%s\n' "${#array_ref[@]}"
    }
    # fn: sgnd_dt_split_schema - Dt split schema
        # . Purpose
        #   Split a datatable schema string into column names.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_dt_split_schema "example"
    sgnd_dt_split_schema() {
        local schema="${1:?missing schema}"

        IFS='|' read -r -a SGND_DT_SPLIT <<< "$schema"
    }
    # fn: sgnd_dt_split_row - Dt split row
        # . Purpose
        #   Split a pipe-separated datatable row into fields.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #
        # . Arguments
        #   $1  ROW - Datatable row value.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_dt_split_row "example" "example-2" "example-3"
    sgnd_dt_split_row() {
        local row="${1-}"
        local tmp

        tmp="${row}|_SGND_SENTINEL_"
        IFS='|' read -r -a SGND_DT_SPLIT <<< "$tmp"

        unset 'SGND_DT_SPLIT[${#SGND_DT_SPLIT[@]}-1]'
    }
    # fn: _dt_build_sortkey - Dt build sortkey
        # . Purpose
        #   Internal helper for dt build sortkey.
        #
        # . Behavior
        #   - Supports the module implementation; not intended as a public framework API.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  ROW - Datatable row value.
        #   $3  SORT_FIELDS - Positional value used by this function.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   _dt_build_sortkey "example" "example-2" "example-3"
    _dt_build_sortkey() {
        local schema="${1:?missing schema}"
        local row="${2-}"
        local sort_fields="${3:?missing sort fields}"
        local field=""
        local value=""
        local sortkey=""
        local -a fields=()

        IFS=',' read -r -a fields <<< "$sort_fields"

        for field in "${fields[@]}"; do
            field="${field//[[:space:]]/}"
            [[ -n "$field" ]] || continue

            value="$(sgnd_dt_row_get "$schema" "$row" "$field")" || return 1

            [[ -z "$sortkey" ]] || sortkey+="|"
            sortkey+="${value,,}"
        done

        printf '%s\n' "$sortkey"
    }
    # fn: sgnd_dt_validate_value - Dt validate value
        # . Purpose
        #   Validate a datatable value before it is stored in a PSV row.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Arguments
        #   $1  VALUE - Value to read, validate, render, or store.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_validate_value "dark" && printf 'Success\n' || printf 'Failed\n'
    sgnd_dt_validate_value() {
        local value="${1-}"

        [[ "$value" == *"|"* ]] && return 1
        [[ "$value" == *$'\n'* ]] && return 1
        return 0
    }
    # fn: sgnd_dt_validate_schema - Dt validate schema
        # . Purpose
        #   Validate a datatable schema definition.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_validate_schema "2026-07-31" "2026-07-31" && printf 'Success\n' || printf 'Failed\n'
    sgnd_dt_validate_schema() {
        local schema="${1-}"
        local i
        local j

        [[ -n "$schema" ]] || return 1

        sgnd_dt_split_schema "$schema"
        (( ${#SGND_DT_SPLIT[@]} > 0 )) || return 1

        for (( i=0; i<${#SGND_DT_SPLIT[@]}; i++ )); do
            [[ -n "${SGND_DT_SPLIT[i]}" ]] || return 1

            for (( j=i+1; j<${#SGND_DT_SPLIT[@]}; j++ )); do
                [[ "${SGND_DT_SPLIT[i]}" != "${SGND_DT_SPLIT[j]}" ]] || return 1
            done
        done

        return 0
    }
    # fn: sgnd_dt_column_index - Dt column index
        # . Purpose
        #   Return the zero-based index for a schema column.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  COLUMN - Datatable column name.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_column_index "example" "example-2"
    sgnd_dt_column_index() {
        local schema="${1:?missing schema}"
        local column="${2:?missing column name}"
        local i

        sgnd_dt_split_schema "$schema"

        for (( i=0; i<${#SGND_DT_SPLIT[@]}; i++ )); do
            [[ "${SGND_DT_SPLIT[i]}" == "$column" ]] || continue
            printf '%s\n' "$i"
            return 0
        done

        return 1
    }
    # fn: sgnd_dt_column_count - Dt column count
        # . Purpose
        #   Return the number of columns in a schema.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_dt_column_count "example"
    sgnd_dt_column_count() {
        local schema="${1:?missing schema}"

        sgnd_dt_split_schema "$schema"
        printf '%s\n' "${#SGND_DT_SPLIT[@]}"
    }

# - DML functions -----------------------------------------------------------------
    # fn: sgnd_dt_make_row - Dt make row
        # . Purpose
        #   Build a pipe-separated datatable row from field values.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_make_row "example" "example-2" "example-3"
    sgnd_dt_make_row() {
        local schema="${1:?missing schema}"
        shift

        local expected=0
        local actual=$#
        local field=""
        local row=""
        local i

        expected="$(sgnd_dt_column_count "$schema")"
        [[ "$actual" -eq "$expected" ]] || return 1

        for (( i=1; i<=actual; i++ )); do
            field="${!i}"
            sgnd_dt_validate_value "$field" || return 1

            [[ -z "$row" ]] || row+="|"
            row+="$field"
        done

        printf '%s\n' "$row"
    }
    # fn: sgnd_dt_has_row - Dt has row
        # . Purpose
        #   Check whether a datatable row index exists.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  TABLE_NAME - Variable, field, or item name.
        #   $3  COLUMN - Datatable column name.
        #   $4  VALUE - Value to read, validate, render, or store.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_dt_has_row "example" "example-2" "example-3" "dark" && printf 'Success\n' || printf 'Failed\n'
    sgnd_dt_has_row() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local column="${3:?missing column name}"
        local value="${4-}"

        sgnd_dt_find_first "$schema" "$table_name" "$column" "$value" >/dev/null 2>&1
    }
    # fn: sgnd_dt_row_get - Dt row get
        # . Purpose
        #   Read a whole datatable row by index.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  ROW - Datatable row value.
        #   $3  COLUMN - Datatable column name.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_row_get "example" "example-2" "example-3" "example-4"
    sgnd_dt_row_get() {
        local schema="${1:?missing schema}"
        local row="${2-}"
        local column="${3:?missing column name}"
        local index=0

        index="$(sgnd_dt_column_index "$schema" "$column")" || return 1
        sgnd_dt_split_row "$row"

        printf '%s\n' "${SGND_DT_SPLIT[index]-}"
    }
    # fn: sgnd_dt_row_set - Dt row set
        # . Purpose
        #   Replace a whole datatable row by index.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  ROW - Datatable row value.
        #   $3  COLUMN - Datatable column name.
        #   $4  VALUE - Value to read, validate, render, or store.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_row_set "example" "example-2" "example-3" "dark"
    sgnd_dt_row_set() {
        local schema="${1:?missing schema}"
        local row="${2-}"
        local column="${3:?missing column name}"
        local value="${4-}"
        local index=0
        local i
        local out=""
        local column_count=0

        sgnd_dt_validate_value "$value" || return 1
        index="$(sgnd_dt_column_index "$schema" "$column")" || return 1

        sgnd_dt_split_schema "$schema"
        column_count="${#SGND_DT_SPLIT[@]}"

        sgnd_dt_split_row "$row"

        for (( i=0; i<column_count; i++ )); do
            [[ -z "$out" ]] || out+="|"

            if (( i == index )); then
                out+="$value"
            else
                out+="${SGND_DT_SPLIT[i]-}"
            fi
        done

        printf '%s\n' "$out"
    }
    # fn: sgnd_dt_row_count - Dt row count
        # . Purpose
        #   Return the number of rows in a datatable.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  TABLE_NAME - Variable, field, or item name.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_dt_row_count "example" "example-2" "example-3"
    sgnd_dt_row_count() {
        local table_name="${1:?missing table name}"

        sgnd_dt_array_length "$table_name"
    }
    # fn: sgnd_dt_insert - Dt insert
        # . Purpose
        #   Insert or append a datatable row.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  TABLE_NAME - Variable, field, or item name.
        #   $3  ROW - Datatable row value.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_insert "example" "example-2" "example-3"
    sgnd_dt_insert() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row="${3-}"
        local expected=0
        local -n table_ref="$table_name"

        sgnd_dt_validate_schema "$schema" || return 1
        expected="$(sgnd_dt_column_count "$schema")"

        sgnd_dt_split_row "$row"
        [[ "${#SGND_DT_SPLIT[@]}" -eq "$expected" ]] || return 1

        table_ref+=("$row")
    }
    # fn: sgnd_dt_delete - Dt delete
        # . Purpose
        #   Delete a datatable row by index.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  TABLE_NAME - Variable, field, or item name.
        #   $2  ROW_INDEX - Zero-based datatable row index.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_delete "example" 20 "example-3" "example-4"
    sgnd_dt_delete() {
        local table_name="${1:?missing table name}"
        local row_index="${2:?missing row index}"
        local row_count=0
        local -n table_ref="$table_name"

        [[ "$row_index" =~ ^[0-9]+$ ]] || return 1

        row_count="$(sgnd_dt_row_count "$table_name")"
        (( row_index < row_count )) || return 1

        unset 'table_ref[row_index]'
        table_ref=("${table_ref[@]}")
    }
    # fn: sgnd_dt_get - Dt get
        # . Purpose
        #   Read one field from a datatable row.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  TABLE_NAME - Variable, field, or item name.
        #   $3  ROW_INDEX - Zero-based datatable row index.
        #   $4  COLUMN - Datatable column name.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_get "example" "example-2" 20 "example-4" "example-5"
    sgnd_dt_get() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row_index="${3:?missing row index}"
        local column="${4:?missing column name}"
        local row_count=0
        local -n table_ref="$table_name"

        [[ "$row_index" =~ ^[0-9]+$ ]] || return 1

        row_count="$(sgnd_dt_row_count "$table_name")"
        (( row_index < row_count )) || return 1

        sgnd_dt_row_get "$schema" "${table_ref[row_index]}" "$column"
    }
    # fn: sgnd_dt_set - Dt set
        # . Purpose
        #   Set one field in a datatable row.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  TABLE_NAME - Variable, field, or item name.
        #   $3  ROW_INDEX - Zero-based datatable row index.
        #   $4  COLUMN - Datatable column name.
        #   $5  VALUE - Value to read, validate, render, or store.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_set "example" "example-2" 20 "example-4" "dark"
    sgnd_dt_set() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row_index="${3:?missing row index}"
        local column="${4:?missing column name}"
        local value="${5-}"
        local row_count=0
        local updated=""
        local -n table_ref="$table_name"

        [[ "$row_index" =~ ^[0-9]+$ ]] || return 1

        row_count="$(sgnd_dt_row_count "$table_name")"
        (( row_index < row_count )) || return 1

        updated="$(sgnd_dt_row_set "$schema" "${table_ref[row_index]}" "$column" "$value")" || return 1
        table_ref[row_index]="$updated"
    }
    # fn: sgnd_dt_find_first - Dt find first
        # . Purpose
        #   Find the first datatable row where a column matches a value.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  TABLE_NAME - Variable, field, or item name.
        #   $3  COLUMN - Datatable column name.
        #   $4  VALUE - Value to read, validate, render, or store.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_find_first "example" "example-2" "example-3" "dark"
    sgnd_dt_find_first() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local column="${3:?missing column name}"
        local value="${4-}"
        local row_count=0
        local i
        local cell=""

        row_count="$(sgnd_dt_row_count "$table_name")"

        for (( i=0; i<row_count; i++ )); do
            cell="$(sgnd_dt_get "$schema" "$table_name" "$i" "$column")" || return 1
            [[ "$cell" == "$value" ]] || continue
            printf '%s\n' "$i"
            return 0
        done

        return 1
    }
    # fn: sgnd_dt_append - Dt append
        # . Purpose
        #   Append a complete row to a datatable.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  TABLE_NAME - Variable, field, or item name.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_append "example" "example-2" "example-3" "example-4" "example-5" "example-6"
    sgnd_dt_append() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row=""

        shift 2

        row="$(sgnd_dt_make_row "$schema" "$@")" || return 1
        saydebug "Appending row to $schema $table_name: $row"
        sgnd_dt_insert "$schema" "$table_name" "$row"
    }
    # fn: sgnd_dt_print_table - Dt print table
        # . Purpose
        #   Render a datatable as an aligned table.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  TABLE_NAME - Variable, field, or item name.
        #   $3  PRETTYPRINT - Positional value used by this function.
        #   $4  HEADERCOLOR - Color value.
        #   $5  DATACOLOR - Color value.
        #   $6  TOP_N - Positional value used by this function.
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
        #   sgnd_dt_print_table "example" "example-2" "example-3" "example-4" "example-5" "example-6"
    sgnd_dt_print_table() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local prettyprint="${3:-0}"
        local headercolor="${4:-}"
        local datacolor="${5:-}"
        local top_n="${6:-}"

        local row_count=0
        local print_count=0
        local col_count=0
        local i=0
        local j=0
        local k=0
        local cell=""
        local row=""
        local color_reset="${RESET:-}"
        local color_header=""
        local color_data=""
        local -a widths=()
        local -a columns=()
        local -n table_ref="$table_name"

        sgnd_dt_validate_schema "$schema" || return 1

        if [[ -n "$headercolor" || -n "$datacolor" ]]; then
            prettyprint=1
        fi

        if (( prettyprint )); then
            color_header="$(sgnd_sgr "${headercolor:-${CYAN:-}}" "" "$FX_BOLD")"
            color_data="${datacolor:-${SILVER:-}}"
        else
            color_header="${WHITE:-}"
            color_data="${SILVER:-}"
        fi

        sgnd_dt_split_schema "$schema"
        columns=("${SGND_DT_SPLIT[@]}")
        col_count="${#columns[@]}"
        row_count="${#table_ref[@]}"

        print_count="$row_count"

        if [[ -n "$top_n" && "$top_n" =~ ^[0-9]+$ ]]; then
            if (( top_n > 0 && top_n < row_count )); then
                print_count="$top_n"
            fi
        fi

        for (( j=0; j<col_count; j++ )); do
            widths[j]="${#columns[j]}"
        done

        for (( i=0; i<print_count; i++ )); do
            row="${table_ref[i]}"
            sgnd_dt_split_row "$row"

            for (( j=0; j<col_count; j++ )); do
                cell="${SGND_DT_SPLIT[j]-}"
                (( ${#cell} > widths[j] )) && widths[j]="${#cell}"
            done
        done

        if (( print_count < row_count )); then
            printf '\n%sTable: %s%s (%s of %s rows)%s\n' \
                "$color_header" \
                "$color_data" \
                "$table_name" \
                "$print_count" \
                "$row_count" \
                "$color_reset"
        else
            printf '\n%sTable: %s%s (%s rows)%s\n' \
                "$color_header" \
                "$color_data" \
                "$table_name" \
                "$row_count" \
                "$color_reset"
        fi

        # print top border
        printf '%s' "$color_header"

        for (( j=0; j<col_count; j++ )); do
            for (( k=0; k<widths[j]; k++ )); do
                printf "${LN_H:-─}"
            done

            (( j < col_count - 1 )) && printf '  '
        done

        printf '%s\n' "$color_reset"

        # print column names
        printf '%s' "$color_header"

        for (( j=0; j<col_count; j++ )); do
            printf '%-*s' "${widths[j]}" "${columns[j]}"
            (( j < col_count - 1 )) && printf '  '
        done

        printf '%s\n' "$color_reset"

        # print bottom border
        printf '%s' "$color_header"

        for (( j=0; j<col_count; j++ )); do
            for (( k=0; k<widths[j]; k++ )); do
                printf "${LN_H:-─}"
            done

            (( j < col_count - 1 )) && printf '  '
        done

        printf '%s\n' "$color_reset"

        printf '%s' "$color_data"

        for (( i=0; i<print_count; i++ )); do
            row="${table_ref[i]}"
            sgnd_dt_split_row "$row"

            for (( j=0; j<col_count; j++ )); do
                cell="${SGND_DT_SPLIT[j]-}"
                printf '%-*s' "${widths[j]}" "$cell"
                (( j < col_count - 1 )) && printf '  '
            done

            printf '\n'
        done

        printf '%s' "$color_reset"
    }
    # fn: sgnd_dt_get_sorted_rows - Dt get sorted rows
        # . Purpose
        #   Return datatable row indexes sorted by a column.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  TABLE_NAME - Variable, field, or item name.
        #   $3  SORT_FIELDS - Positional value used by this function.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_get_sorted_rows "example" "example-2" "example-3"
    sgnd_dt_get_sorted_rows() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local sort_fields="${3:?missing sort fields}"
        local row=""
        local sortkey=""
        local row_count=0
        local i=0
        local -n table_ref="$table_name"

        sgnd_dt_validate_schema "$schema" || return 1

        row_count="$(sgnd_dt_row_count "$table_name")"

        for (( i=0; i<row_count; i++ )); do
            row="${table_ref[i]}"
            sortkey="$(_dt_build_sortkey "$schema" "$row" "$sort_fields")" || return 1

            printf '%s\t%s\n' "$sortkey" "$row"
        done | sort -t $'\t' -k1,1 | cut -f2-
    }
    # fn: sgnd_dt_row2var - Dt row2var
        # . Purpose
        #   Export one datatable row to shell variables.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  TABLE_NAME - Variable, field, or item name.
        #   $3  ROW - Datatable row value.
        #
        # . Output
        #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_dt_row2var "example" "example-2" "example-3"
    sgnd_dt_row2var() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row="${3-}"

        local i
        local field_name
        local var_name
        local -a columns=()

        sgnd_dt_validate_schema "$schema" || return 1

        sgnd_dt_split_schema "$schema"
        columns=("${SGND_DT_SPLIT[@]}")

        sgnd_dt_split_row "$row"

        for (( i=0; i<${#columns[@]}; i++ )); do
            field_name="${columns[i]}"

            field_name="${field_name,,}"
            field_name="${field_name//-/_}"

            var_name="${table_name}_${field_name}"

            printf -v "$var_name" '%s' "${SGND_DT_SPLIT[i]-}"
        done
    }
    # fn: sgnd_dt_export_psv - Dt export psv
        # . Purpose
        #   Print a datatable as pipe-separated values.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses SolidGroundUX datatable rows and schemas for structured state.
        #
        # . Arguments
        #   $1  SCHEMA - Datatable schema string.
        #   $2  TABLE_NAME - Variable, field, or item name.
        #   $3  OUTPUT_FILE - File path.
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
        #   sgnd_dt_export_psv "example" "example-2" "/tmp/sgnd-example.txt"
    sgnd_dt_export_psv() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local output_file="${3:?missing output file}"

        local output_dir=""
        local row=""
        local -n table_ref="$table_name"

        sgnd_dt_validate_schema "$schema" || return 1

        output_dir="$(dirname "$output_file")"
        mkdir -p "$output_dir" || return 1

        {
            printf '%s\n' "$schema"

            for row in "${table_ref[@]}"; do
                printf '%s\n' "$row"
            done
        } > "$output_file" || return 1

        return 0
    }
