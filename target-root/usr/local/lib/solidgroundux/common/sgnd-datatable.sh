# =====================================================================================
# SolidGroundUX - Datatable
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
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
# - DDL functions -----------------------------------------------------------------
    # fn: sgnd_dt_array_length - Return the number of elements in a named indexed array.
        # . Purpose
        #   Return the number of elements in a named indexed array.
        #
        # . Arguments
        #   $1  Name of an existing Bash array (passed by name, not by value).
        #
        # . Output
        #   Writes the count to stdout.
        #
        # . Returns
        #   0 after writing its element count.
        #
        # . Usage
        #   ```bash
        #   rows=("Ada|admin" "Lin|viewer")
        #   sgnd_dt_array_length rows
        #   ```
    sgnd_dt_array_length() {
        local array_name="${1:?missing array name}"
        local -n array_ref="$array_name"

        printf '%s\n' "${#array_ref[@]}"
    }
    # fn: sgnd_dt_split_schema - Split a pipe-delimited schema into its column names.
        # . Purpose
        #   Split a pipe-delimited schema into its column names.
        #
        # . Arguments
        #   $1  Schema, for example name|role.
        #
        # . Side effects
        #   Populates the global SGND_DT_SPLIT array.
        #
        # . Returns
        #   0 after splitting.
        #
        # . Usage
        #   ```bash
        #   sgnd_dt_split_schema "name|role"
        #   printf "%s\n" "${SGND_DT_SPLIT[@]}"
        #   ```
    sgnd_dt_split_schema() {
        local schema="${1:?missing schema}"

        IFS='|' read -r -a SGND_DT_SPLIT <<< "$schema"
    }
    # fn: sgnd_dt_split_row - Split a PSV row into fields, preserving trailing empty fields.
        # . Purpose
        #   Split a PSV row into fields, preserving trailing empty fields.
        #
        # . Arguments
        #   $1  Pipe-separated row; omitted means an empty row.
        #
        # . Side effects
        #   Populates the global SGND_DT_SPLIT array.
        #
        # . Returns
        #   0 after splitting.
        #
        # . Usage
        #   ```bash
        #   sgnd_dt_split_row "Ada|admin"
        #   printf "%s\n" "${SGND_DT_SPLIT[@]}"
        #   ```
    sgnd_dt_split_row() {
        local row="${1-}"
        local tmp

        tmp="${row}|_SGND_SENTINEL_"
        IFS='|' read -r -a SGND_DT_SPLIT <<< "$tmp"

        unset 'SGND_DT_SPLIT[${#SGND_DT_SPLIT[@]}-1]'
    }
    # fn: _dt_build_sortkey - Build a case-insensitive sort key from a row.
        # . Purpose
        #   Build a case-insensitive sort key from a row.
        #
        # . Arguments
        #   $1  Schema containing the named columns.
        #   $2  Pipe-separated row.
        #   $3  Comma-separated column names used for sorting.
        #
        # . Output
        #   Prints the lowercased field values joined by |.
        #
        # . Returns
        #   0 after printing the sort key; 1 if a column cannot be resolved.
        #
        # . Usage
        #   ```bash
        #   _dt_build_sortkey "name|role" "Ada|admin" "role,name"
        #   ```
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
    # fn: sgnd_dt_validate_value - Reject values that cannot be safely stored in a PSV row.
        # . Purpose
        #   Reject values that cannot be safely stored in a PSV row.
        #
        # . Arguments
        #   $1  Field value to validate.
        #
        # . Returns
        #   0 when no pipe or newline is present; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_dt_validate_value "Ada"
        #   ```
    sgnd_dt_validate_value() {
        local value="${1-}"

        [[ "$value" == *"|"* ]] && return 1
        [[ "$value" == *$'\n'* ]] && return 1
        return 0
    }
    # fn: sgnd_dt_validate_schema - Validate a pipe-delimited schema for nonempty unique column names.
        # . Purpose
        #   Validate a pipe-delimited schema for nonempty unique column names.
        #
        # . Arguments
        #   $1  Schema to check.
        #
        # . Side effects
        #   Updates SGND_DT_SPLIT with the schema fields.
        #
        # . Returns
        #   0 when the schema is nonempty and every column name is unique and nonempty; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_dt_validate_schema "name|role"
        #   ```
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
    # fn: sgnd_dt_column_index - Look up the zero-based index of a named schema column.
        # . Purpose
        #   Look up the zero-based index of a named schema column.
        #
        # . Arguments
        #   $1  Pipe-delimited schema.
        #   $2  Column name to find (exact match).
        #
        # . Output
        #   Writes the numeric column index to stdout.
        #
        # . Returns
        #   0 when found; 1 when the column is absent.
        #
        # . Usage
        #   ```bash
        #   sgnd_dt_column_index "name|role" "role"
        #   ```
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
    # fn: sgnd_dt_column_count - Count the columns in a pipe-delimited schema.
        # . Purpose
        #   Count the columns in a pipe-delimited schema.
        #
        # . Arguments
        #   $1  Schema string.
        #
        # . Output
        #   Writes the count to stdout.
        #
        # . Returns
        #   0 after writing the column count.
        #
        # . Usage
        #   ```bash
        #   sgnd_dt_column_count "name|role"
        #   ```
    sgnd_dt_column_count() {
        local schema="${1:?missing schema}"

        sgnd_dt_split_schema "$schema"
        printf '%s\n' "${#SGND_DT_SPLIT[@]}"
    }

# - DML functions -----------------------------------------------------------------
    # fn: sgnd_dt_make_row - Join values into a validated PSV row in schema order.
        # . Purpose
        #   Join values into a validated PSV row in schema order.
        #
        # . Description
        #   Rejects a mismatched field count and values containing a pipe or newline.
        #
        # . Arguments
        #   $1  Schema string.
        #   $2...  One field value per schema column, in order.
        #
        # . Output
        #   Writes a pipe-separated row to stdout.
        #
        # . Returns
        #   0 when field count and contents are valid; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_dt_make_row "name|role" "Ada" "admin"
        #   ```
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
    # fn: sgnd_dt_has_row - Test whether any row matches a column value.
        # . Purpose
        #   Test whether any row matches a column value.
        #
        # . Arguments
        #   $1  Schema.
        #   $2  Name of the indexed array holding table rows.
        #   $3  Column name.
        #   $4  Value to match exactly.
        #
        # . Returns
        #   0 when a matching row exists; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   rows=("Ada|admin" "Lin|viewer")
        #   sgnd_dt_has_row "name|role" rows role admin
        #   ```
    sgnd_dt_has_row() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local column="${3:?missing column name}"
        local value="${4-}"

        sgnd_dt_find_first "$schema" "$table_name" "$column" "$value" >/dev/null 2>&1
    }
    # fn: sgnd_dt_row_get - Extract one named column from an already obtained PSV row.
        # . Purpose
        #   Extract one named column from an already obtained PSV row.
        #
        # . Arguments
        #   $1  Schema.
        #   $2  Pipe-separated row value (not a table name or index).
        #   $3  Column name.
        #
        # . Output
        #   Writes the selected field value to stdout.
        #
        # . Returns
        #   0 when the column is known; 1 if it is absent.
        #
        # . Usage
        #   ```bash
        #   sgnd_dt_row_get "name|role" "Ada|admin" role
        #   ```
    sgnd_dt_row_get() {
        local schema="${1:?missing schema}"
        local row="${2-}"
        local column="${3:?missing column name}"
        local index=0

        index="$(sgnd_dt_column_index "$schema" "$column")" || return 1
        sgnd_dt_split_row "$row"

        printf '%s\n' "${SGND_DT_SPLIT[index]-}"
    }
    # fn: sgnd_dt_row_set - Return a PSV row with one named field replaced.
        # . Purpose
        #   Return a PSV row with one named field replaced.
        #
        # . Arguments
        #   $1  Schema.
        #   $2  Original pipe-separated row.
        #   $3  Column name.
        #   $4  Replacement field value.
        #
        # . Output
        #   Writes a new PSV row; does not modify a table array.
        #
        # . Returns
        #   0 on success; 1 if the column or new value is invalid.
        #
        # . Usage
        #   ```bash
        #   sgnd_dt_row_set "name|role" "Ada|admin" role editor
        #   ```
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
    # fn: sgnd_dt_row_count - Count the rows stored in a named table array.
        # . Purpose
        #   Count the rows stored in a named table array.
        #
        # . Arguments
        #   $1  Name of the indexed table array.
        #
        # . Output
        #   Writes the count to stdout.
        #
        # . Returns
        #   0 after writing the row count.
        #
        # . Usage
        #   ```bash
        #   rows=("Ada|admin")
        #   sgnd_dt_row_count rows
        #   ```
    sgnd_dt_row_count() {
        local table_name="${1:?missing table name}"

        sgnd_dt_array_length "$table_name"
    }
    # fn: sgnd_dt_insert - Append an already formatted PSV row to a table array.
        # . Purpose
        #   Append an already formatted PSV row to a table array.
        #
        # . Description
        #   Validates the schema and the number of row fields; does not revalidate individual field contents.
        #
        # . Arguments
        #   $1  Schema.
        #   $2  Name of the indexed table array.
        #   $3  Complete PSV row.
        #
        # . Side effects
        #   Appends a row to the named array.
        #
        # . Returns
        #   0 when the schema and field count are valid; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   rows=()
        #   sgnd_dt_insert "name|role" rows "Ada|admin"
        #   ```
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
    # fn: sgnd_dt_delete - Delete a row and compact its table array.
        # . Purpose
        #   Delete a row and compact its table array.
        #
        # . Arguments
        #   $1  Name of the indexed table array.
        #   $2  Zero-based index to delete.
        #
        # . Side effects
        #   Mutates the table array and compacts the remaining elements.
        #
        # . Returns
        #   0 for an existing numeric index; 1 for invalid or out-of-range indexes.
        #
        # . Usage
        #   ```bash
        #   rows=("Ada|admin" "Lin|viewer")
        #   sgnd_dt_delete rows 0
        #   ```
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
    # fn: sgnd_dt_get - Read a column from a table row by numeric index.
        # . Purpose
        #   Read a column from a table row by numeric index.
        #
        # . Arguments
        #   $1  Schema.
        #   $2  Name of table array.
        #   $3  Zero-based row index.
        #   $4  Column name.
        #
        # . Output
        #   Writes the field value to stdout.
        #
        # . Returns
        #   0 when row and column exist; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   rows=("Ada|admin")
        #   sgnd_dt_get "name|role" rows 0 role
        #   ```
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
    # fn: sgnd_dt_set - Update a named column in a table row by numeric index.
        # . Purpose
        #   Update a named column in a table row by numeric index.
        #
        # . Arguments
        #   $1  Schema.
        #   $2  Name of table array.
        #   $3  Zero-based row index.
        #   $4  Column name.
        #   $5  New field value.
        #
        # . Side effects
        #   Replaces one row in the named table array.
        #
        # . Returns
        #   0 on update; 1 for an invalid index, column, or field value.
        #
        # . Usage
        #   ```bash
        #   rows=("Ada|admin")
        #   sgnd_dt_set "name|role" rows 0 role editor
        #   ```
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
    # fn: sgnd_dt_find_first - Find the first row whose named column equals a value.
        # . Purpose
        #   Find the first row whose named column equals a value.
        #
        # . Arguments
        #   $1  Schema.
        #   $2  Name of table array.
        #   $3  Column name.
        #   $4  Value to match exactly.
        #
        # . Output
        #   Prints the zero-based row index of the first match.
        #
        # . Returns
        #   0 when a row matches; 1 if no match or the column is invalid.
        #
        # . Usage
        #   ```bash
        #   rows=("Ada|admin")
        #   sgnd_dt_find_first "name|role" rows role admin
        #   ```
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
    # fn: sgnd_dt_append - Build, validate and append a row from individual field values.
        # . Purpose
        #   Build, validate and append a row from individual field values.
        #
        # . Arguments
        #   $1  Schema.
        #   $2  Name of table array.
        #   $3...  Values corresponding to the schema columns.
        #
        # . Side effects
        #   Adds a row to the table array and emits a debug message.
        #
        # . Returns
        #   0 on append; 1 for an invalid schema or field values.
        #
        # . Usage
        #   ```bash
        #   rows=()
        #   sgnd_dt_append "name|role" rows "Ada" "admin"
        #   ```
    sgnd_dt_append() {
        local schema="${1:?missing schema}"
        local table_name="${2:?missing table name}"
        local row=""

        shift 2

        row="$(sgnd_dt_make_row "$schema" "$@")" || return 1
        saydebug "Appending row to $schema $table_name: $row"
        sgnd_dt_insert "$schema" "$table_name" "$row"
    }
    # fn: sgnd_dt_print_table - Render table rows with an aligned heading and themed colors.
        # . Purpose
        #   Render table rows with an aligned heading and themed colors.
        #
        # . Description
        #   By default colors come from SGND_DT_HEADERLINE_CLR, SGND_DT_COLUMNNAME_CLR and SGND_DT_DATACOLOR_CLR with legacy palette fallbacks. Explicit color arguments override both header roles or the data role.
        #
        # . Arguments
        #   $1  Schema.
        #   $2  Name of table array.
        #   $3  Optional prettyprint flag (0 or 1; retained for compatibility).
        #   $4  Optional header color override (heading and both rules).
        #   $5  Optional data color override.
        #   $6  Optional maximum number of rows.
        #
        # . Output
        #   Writes an aligned table to stdout.
        #
        # . Returns
        #   0 after rendering; 1 for an invalid schema.
        #
        # . Usage
        #   ```bash
        #   rows=("Ada|admin" "Lin|viewer")
        #   sgnd_dt_print_table "name|role" rows
        #   ```
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
        local color_headerline=""
        local color_columnname=""
        local color_data=""
        local -a widths=()
        local -a columns=()
        local -n table_ref="$table_name"

        sgnd_dt_validate_schema "$schema" || return 1

        if [[ -n "$headercolor" || -n "$datacolor" ]]; then
            prettyprint=1
        fi

        # Theme roles are independent: horizontal rules, column headings, and
        # data can each be styled without changing the other two.
        # Preserve the historical palette fallback when no style is loaded.
        if (( prettyprint )); then
            color_headerline="${SGND_DT_HEADERLINE_CLR:-$(sgnd_sgr "${SGND_UI_BORDER:-${CYAN:-}}" "" "${FX_BOLD:-}")}"
            color_columnname="${SGND_DT_COLUMNNAME_CLR:-$(sgnd_sgr "${SGND_UI_LABEL:-${CYAN:-}}" "" "${FX_BOLD:-}")}"
        else
            color_headerline="${SGND_DT_HEADERLINE_CLR:-${SGND_UI_BORDER:-${WHITE:-}}}"
            color_columnname="${SGND_DT_COLUMNNAME_CLR:-${SGND_UI_LABEL:-${WHITE:-}}}"
        fi
        color_data="${SGND_DT_DATACOLOR_CLR:-${SGND_UI_TEXT:-${SILVER:-}}}"

        # Backwards-compatible per-table overrides. The existing HEADERCOLOR
        # argument intentionally applies to both heading text and header rules.
        if [[ -n "$headercolor" ]]; then
            color_headerline="$(sgnd_sgr "$headercolor" "" "${FX_BOLD:-}")"
            color_columnname="$color_headerline"
        fi
        [[ -z "$datacolor" ]] || color_data="$datacolor"

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
                "$color_columnname" \
                "$color_data" \
                "$table_name" \
                "$print_count" \
                "$row_count" \
                "$color_reset"
        else
            printf '\n%sTable: %s%s (%s rows)%s\n' \
                "$color_columnname" \
                "$color_data" \
                "$table_name" \
                "$row_count" \
                "$color_reset"
        fi

        # print top border
        printf '%s' "$color_headerline"

        for (( j=0; j<col_count; j++ )); do
            for (( k=0; k<widths[j]; k++ )); do
                printf "${LN_H:-─}"
            done

            (( j < col_count - 1 )) && printf '  '
        done

        printf '%s\n' "$color_reset"

        # print column names
        printf '%s' "$color_columnname"

        for (( j=0; j<col_count; j++ )); do
            printf '%-*s' "${widths[j]}" "${columns[j]}"
            (( j < col_count - 1 )) && printf '  '
        done

        printf '%s\n' "$color_reset"

        # print bottom border
        printf '%s' "$color_headerline"

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
    # fn: sgnd_dt_get_sorted_rows - Return table rows sorted by one or more named columns.
        # . Purpose
        #   Return table rows sorted by one or more named columns.
        #
        # . Description
        #   Creates lowercased compound sort keys and uses a pipe-separated composite key for each row.
        #
        # . Arguments
        #   $1  Schema.
        #   $2  Name of table array.
        #   $3  Comma-separated column names in sort precedence order.
        #
        # . Output
        #   Writes sorted PSV rows (not row indexes) to stdout.
        #
        # . Returns
        #   0 on success; 1 if the schema or a sort column is invalid.
        #
        # . Usage
        #   ```bash
        #   rows=("Lin|viewer" "Ada|admin")
        #   sgnd_dt_get_sorted_rows "name|role" rows "role,name"
        #   ```
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
    # fn: sgnd_dt_row2var - Expand a PSV row into prefixed shell variables.
        # . Purpose
        #   Expand a PSV row into prefixed shell variables.
        #
        # . Arguments
        #   $1  Schema.
        #   $2  Prefix for generated variable names.
        #   $3  Pipe-separated row.
        #
        # . Side effects
        #   Creates variables named PREFIX_column using lowercased schema columns and hyphens converted to underscores.
        #
        # . Returns
        #   0 when the schema is valid; 1 otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_dt_row2var "name|role" person "Ada|admin"
        #   printf "%s\n" "$person_role"
        #   ```
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
    # fn: sgnd_dt_export_psv - Write a table to a PSV file with the schema as its first line.
        # . Purpose
        #   Write a table to a PSV file with the schema as its first line.
        #
        # . Arguments
        #   $1  Schema.
        #   $2  Name of table array.
        #   $3  Destination file.
        #
        # . Side effects
        #   Creates the parent directory if necessary and overwrites the destination file.
        #
        # . Returns
        #   0 after writing the file; 1 on invalid schema or filesystem failure.
        #
        # . Usage
        #   ```bash
        #   rows=("Ada|admin")
        #   sgnd_dt_export_psv "name|role" rows "/tmp/people.psv"
        #   ```
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
