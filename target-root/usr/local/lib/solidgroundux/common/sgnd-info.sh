# =====================================================================================
# SolidGroundUX - Framework Information
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
#   Checksum    : 8a59f8ad76e1487e7e9fb04f4ead32a79b57d4bb3f0d6afb86f0356c7ea3a8e3
#   Source      : sgnd-info.sh
#   Type        : library
#   Group       : Common Core
#   Purpose     : Provide framework metadata and runtime information helpers
#
# Description:
#   Exposes information about the SolidGroundUX framework and runtime environment.
#
#   The library:
#     - Provides access to framework identity (name, version, paths)
#     - Exposes resolved bootstrap values such as SGND_FRAMEWORK_ROOT and runtime paths
#     - Supplies helper functions for displaying framework and environment details
#     - Supports diagnostics, logging, and informational output
#
# Design principles:
#   - Keep information access centralized and consistent
#   - Avoid duplication of framework identity data across modules
#   - Ensure values reflect the active runtime environment
#   - Keep implementation lightweight and dependency-free where possible
#
# Role in framework:
#   - Provides introspection capabilities for scripts and tools
#   - Supports diagnostics, debugging, and informational commands
#   - Complements bootstrap and configuration modules
#
# Non-goals:
#   - Configuration management (handled by cfg.sh)
#   - Argument parsing or user interaction
#   - Persistent state tracking
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
    : "${_section_indent:=2}"
    : "${_items_indent:=4}"
    # fn: _sgnd_print_arg_spec_entry - Print arg spec entry
        # . Purpose
        #   Print one parsed argument specification and its current variable value.
        #
        # . Arguments
        #   $1 - Specification entry in NAME|SHORT|TYPE|VARIABLE|HELP|CHOICES format.
        #
        # . Returns
        #   Status of sgnd_print_labeledvalue.
        #
        # . Usage
        #   ```bash
        #   _sgnd_print_arg_spec_entry "dryrun|d|flag|FLAG_DRYRUN|Dry run|"
        #   ```
    _sgnd_print_arg_spec_entry() {
        local entry="${1-}"
        local name=""
        local short=""
        local type=""
        local varname=""
        local help=""
        local choices=""
        local label=""
        local value=""

        IFS='|' read -r name short type varname help choices <<< "$entry"

        if [[ -n "$short" ]]; then
            label="--$name (-$short)"
        else
            label="--$name"
        fi

        if [[ -n "$varname" ]]; then
            value="${varname} = ${!varname-<unset>}"
        else
            value="<no var>"
        fi

        sgnd_print_labeledvalue "$label" "$value" --pad "$_items_indent"
    }
    # fn: _sgnd_print_arg_spec_list - Print arg spec list
        # . Purpose
        #   Print a labeled list of argument specifications and their current values.
        #
        # . Arguments
        #   $1 - Heading to display.
        #   $2 - Name of the specification array.
        #
        # . Returns
        #   0 when the array is absent or empty; otherwise the final rendering status.
        #
        # . Usage
        #   ```bash
        #   _sgnd_print_arg_spec_list "Script arguments" SGND_ARGS_SPEC
        #   ```
    _sgnd_print_arg_spec_list() {
        local header="${1:?missing header}"
        local array_name="${2:?missing array name}"
        local entry=""
        local printed_header=0

        declare -p "$array_name" >/dev/null 2>&1 || return 0

        local -n specs_ref="$array_name"
        (( ${#specs_ref[@]} > 0 )) || return 0

        for entry in "${specs_ref[@]}"; do
            if (( ! printed_header )); then
                sgnd_print_sectionheader --text "$header" --padleft "$_section_indent"
                printed_header=1
            fi
            _sgnd_print_arg_spec_entry "$entry"
        done
    }
    # fn: _sgnd_print_cfg_pass - Print cfg pass
        # . Purpose
        #   Render a named configuration array, filtered by the accepted scope values.
        #
        # . Arguments
        #   $1 - Section heading.
        #   $2 - Specification array name.
        #   $@ - Accepted scopes, after the first two arguments.
        #
        # . Returns
        #   Status of the final UI output operation.
        #
        # . Usage
        #   ```bash
        #   _sgnd_print_cfg_pass "User globals" SGND_SCRIPT_GLOBALS user both
        #   ```
    _sgnd_print_cfg_pass() {
        local header_text="${1:?missing header text}"
        local array_name="${2:?missing array name}"
        shift 2

        local -n source_array="$array_name"
        local -a accept_scopes=( "$@" )
        local item=""
        local scope=""
        local name=""
        local desc=""
        local default=""
        local value=""
        local ok=0
        local s=""

        sgnd_print_sectionheader --text "$header_text" --padleft "$_section_indent"

        for item in "${source_array[@]}"; do
            IFS='|' read -r scope name desc default <<< "$item"

            ok=0
            for s in "${accept_scopes[@]}"; do
                if [[ "$scope" == "$s" ]]; then
                    ok=1
                    break
                fi
            done
            (( ok )) || continue

            value="${!name:-$default}"
            sgnd_print_labeledvalue "$name" "$value" --pad "$_items_indent"
        done
    }
# - Public API ----------------------------------------------------------------------
    # fn: sgnd_print_cfg - Print cfg
        # . Purpose
        #   Print effective configuration values for diagnostics.
        #
        # . Arguments
        #   $1 - Name of a configuration specification array.
        #   $2 - Scope filter: system, user, or both (default).
        #
        # . Returns
        #   1 for an unsupported scope filter; otherwise the status of the final output helper.
                #
        # . Usage
        #   ```bash
        #   sgnd_print_cfg SGND_SCRIPT_GLOBALS both
        #   ```
    sgnd_print_cfg() {
        local array_name="${1:?missing spec array name}"
        local filter="${2:-both}"

        case "$filter" in
            system|user|both) ;;
            *) return 1 ;;
        esac

        if [[ "$filter" == "system" || "$filter" == "both" ]]; then
            _sgnd_print_cfg_pass "System globals" "$array_name" system both
            sgnd_print
        fi

        if [[ "$filter" == "user" || "$filter" == "both" ]]; then
            _sgnd_print_cfg_pass "User globals" "$array_name" user both
            sgnd_print
        fi
    }
    # fn: sgnd_print_framework_metadata - Print framework metadata
        # . Purpose
        #   Print framework metadata values.
        #
        # . Returns
        #   Returns the status of the final UI output operation.
        #
        # . Usage
        #   ```bash
        #   sgnd_print_framework_metadata
        #   ```
    sgnd_print_framework_metadata() {
        sgnd_print_sectionheader --text "Framework metadata" --padleft "$_section_indent"
        sgnd_print_labeledvalue "Product"      "$SGND_PRODUCT" --pad "$_items_indent"
        sgnd_print_labeledvalue "Version"      "$SGND_VERSION" --pad "$_items_indent"
        sgnd_print_labeledvalue "Buildnr"      "$SGND_BUILD" --pad "$_items_indent"
        sgnd_print_labeledvalue "Company"      "$SGND_COMPANY" --pad "$_items_indent"
        sgnd_print_labeledvalue "Copyright"    "$SGND_COPYRIGHT" --pad "$_items_indent"
        sgnd_print_labeledvalue "License"      "$SGND_LICENSE" --pad "$_items_indent"
        sgnd_print
    }
    # fn: sgnd_print_metadata - Print metadata
        # . Purpose
        #   Print active script or module metadata.
        #
        # . Returns
        #   Returns the status of the final UI output operation.
        #
        # . Usage
        #   ```bash
        #   sgnd_print_metadata
        #   ```
    sgnd_print_metadata() {
        sgnd_print_sectionheader --text "Script metadata" --padleft "$_section_indent"
        sgnd_print_labeledvalue "File"               "$SGND_SCRIPT_FILE" --pad "$_items_indent"
        sgnd_print_labeledvalue "Script description" "$SGND_SCRIPT_DESC" --pad "$_items_indent"
        sgnd_print_labeledvalue "Script dir"         "$SGND_SCRIPT_DIR" --pad "$_items_indent"
        sgnd_print_labeledvalue "Script version"     "$SGND_SCRIPT_VERSION (build $SGND_SCRIPT_BUILD)" --pad "$_items_indent"
        sgnd_print
    }
    # fn: sgnd_print_args - Print args
        # . Purpose
        #   Print parsed argument values.
        #
        # . Returns
        #   Returns the status of the final UI output operation.
        #
        # . Usage
        #   ```bash
        #   sgnd_print_args
        #   ```
    sgnd_print_args() {
        sgnd_print
        _sgnd_print_arg_spec_list "Script arguments" "SGND_ARGS_SPEC"

        sgnd_print
        _sgnd_print_arg_spec_list "Framework arguments" "SGND_BUILTIN_ARGS"

        if declare -p SGND_POSITIONAL >/dev/null 2>&1 && (( ${#SGND_POSITIONAL[@]} > 0 )); then
            sgnd_print
            sgnd_print_sectionheader --text "Positional arguments"

            local i=0
            for i in "${!SGND_POSITIONAL[@]}"; do
                sgnd_print_labeledvalue "Arg[$i]" "${SGND_POSITIONAL[$i]}"
            done
        fi

        sgnd_print
    }
    # fn: sgnd_print_state - Print state
        # . Purpose
        #   Print current state-domain values.
        #
        # . Returns
        #   Returns the status of the state-listing/display pipeline.
        #
        # . Usage
        #   ```bash
        #   sgnd_print_state
        #   ```
    sgnd_print_state() {
        sgnd_state_list_keys | {
            local printed_header=0
            local key=""
            local value=""

            while IFS='|' read -r key value; do
                if (( ! printed_header )); then
                    sgnd_print_sectionheader --text "State variables" --padleft "$_section_indent"
                    printed_header=1
                fi
                sgnd_print_labeledvalue "$key" "$value" --pad "$_items_indent"
            done

            sgnd_print
        }
    }
    # fn: sgnd_print_license - Print license
        # . Purpose
        #   Print active license information.
        #
        # . Returns
        #   Returns the status of the final command executed; an unreadable or absent license file is silently skipped.
        #
        # . Usage
        #   ```bash
        #   sgnd_print_license
        #   ```
    sgnd_print_license() {
        local license_file="${SGND_LICENSE_FILE}"
        
        local status_text="${SGND_UI_INVALID}NOT ACCEPTED${RESET}" 

        if (( SGND_LICENSE_ACCEPTED )); then
            status_text="${SGND_UI_VALID}[ACCEPTED]${RESET}"
        fi

        saydebug "sgnd_print_license: license status is: $status_text"
        saydebug "sgnd_print_license: looking for license file at: $license_file"

        saydebug "License status text: ${status_text}\n"
        saydebug 'SGND_DOCS_DIR=%s\n' "$SGND_DOCS_DIR"
        saydebug 'SGND_LICENSE_FILE=%s\n' "$SGND_LICENSE_FILE"

        local filestatus=""
        [[ -e "$license_file" ]] && filestatus="exists" || filestatus="missing"
        [[ -r "$license_file" ]] && filestatus="$filestatus, readable" || filestatus="$filestatus, not readable"
        saydebug "License file status: $filestatus"

        if [[ -r "$license_file" ]]; then
            saydebug "sgnd_print_license: found license file, printing"
            sgnd_print
            sgnd_print_sectionheader --text "$SGND_PRODUCT license $status_text" --padleft "$_section_indent"
            sgnd_print
            sgnd_print_file "$license_file"
            sgnd_print
            sgnd_print_sectionheader --border "$LN_H"
        else
            saydebug "sgnd_print_license: license file not found or not readable: $license_file"
        fi
    }
    # fn: sgnd_print_readme - Print readme
        # . Purpose
        #   Print the active script README section.
        #
        # . Returns
        #   Returns the print-file status when readable; otherwise completes without printing.
        #
        # . Usage
        #   ```bash
        #   sgnd_print_readme
        #   ```
    sgnd_print_readme() {
        local readme_file="$SGND_DOCS_DIR/README.md"

        if [[ -r "$readme_file" ]]; then
            sgnd_print_file "$readme_file"
        fi
    }
    # fn: sgnd_showenvironment - Showenvironment
        # . Purpose
        #   Print a combined SolidGroundUX environment overview.
        #
        # . Returns
        #   Returns the status of the final section-header rendering operation.
        #
        # . Usage
        #   ```bash
        #   sgnd_showenvironment
        #   ```
    sgnd_showenvironment() {
        sgnd_print_titlebar
        sgnd_print

        sgnd_print_metadata

        sgnd_print_sectionheader --text "Command line arguments"
        sgnd_print_args

        sgnd_print_state

        sgnd_print_sectionheader --text "Script configuration ($SGND_SCRIPT_NAME.cfg)"
        sgnd_print_cfg SGND_SCRIPT_GLOBALS both

        sgnd_print_sectionheader --border "$LN_H" --text "Framework configuration ($SGND_FRAMEWORK_CFG_BASENAME)"
        sgnd_print_framework_metadata
        sgnd_print_cfg SGND_FRAMEWORK_GLOBALS both

        sgnd_print_sectionheader --border "$DL_H"
    }
