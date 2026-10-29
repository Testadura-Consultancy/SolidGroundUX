# =====================================================================================
# SolidGroundUX - Argument Parsing
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627808
#   Checksum    : 68f0d6985486a6a362856589a25187c1854e17ecefc987acc89dff1dbf64bddf
#   Source      : sgnd-args.sh
#   Type        : library
#   Group       : Common Core
#   Purpose     : Parse and manage command-line arguments for scripts
#
# Description:
#   Provides a structured argument parsing system for SolidGroundUX scripts.
#
#   The library:
#     - Parses short and long command-line arguments
#     - Supports flags, values, and enumerated options
#     - Maps arguments to strongly defined variables
#     - Validates input against argument specifications
#     - Separates framework arguments from script-specific arguments
#     - Generates consistent help and usage output
#
# Design principles:
#   - Declarative argument specification via SGND_ARGS_SPEC
#   - Predictable and consistent parsing behavior across scripts
#   - Clear separation between parsing and business logic
#   - Minimal runtime surprises through validation and normalization
#
# Role in framework:
#   - Core infrastructure for all executable scripts
#   - Used during bootstrap to interpret command-line input
#   - Enables standardized CLI behavior across the framework
#
# Non-goals:
#   - Complex subcommand frameworks (e.g., git-style commands)
#   - Interactive input handling (handled by ui-ask/ui-dlg)
#   - Dynamic runtime argument schema mutation
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
# - Helper functions ----------------------------------------------------------------
    # fn: _sgnd_arg_split - Split one argument specification
        # . Purpose
        #   Parse a pipe-separated argument specification into parser fields.
        #
        # . Behavior
        #   - Reads one SGND argument specification string.
        #   - Splits the string into name, short option, type, target variable,
        #     help text, default value, and enum choices.
        #   - Stores parsed fields in parser-scoped scratch variables.
        #
        # . Arguments
        #   $1  Argument specification in name|short|type|var|help|default|choices format.
        #
        # Outputs (globals):
        #   _sgnd_name, _sgnd_short, _sgnd_type, _sgnd_var
        #   _sgnd_help, _sgnd_default, _sgnd_choices
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _sgnd_arg_split "example"
    _sgnd_arg_split() {
        local spec="$1"
        IFS='|' read -r _sgnd_name _sgnd_short _sgnd_type _sgnd_var _sgnd_help _sgnd_default _sgnd_choices <<< "$spec"
    }

    # fn: _sgnd_arg_find_spec - Find an argument specification
        # . Purpose
        #   Locate the effective argument specification for a long or short option.
        #
        # . Behavior
        #   - Iterates SGND_EFFECTIVE_ARGS_SPEC in declaration order.
        #   - Matches either the long option name or the short option letter.
        #   - Prints the matching raw specification to stdout.
        #
        # . Arguments
        #   $1  Long option name or short option letter to find.
        #
        # Inputs (globals):
        #   SGND_EFFECTIVE_ARGS_SPEC
        #
        # . Output
        #   Matching raw argument specification on stdout.
        #
        # . Returns
        #   0 when a matching specification is found.
        #   1 when no matching specification exists.
        #
        # . Usage
        #   _sgnd_arg_find_spec "example" "example-2"
    _sgnd_arg_find_spec() {
        local wanted="$1"
        local spec

        for spec in "${SGND_EFFECTIVE_ARGS_SPEC[@]:-}"; do
            _sgnd_arg_split "$spec"
            if [[ "$_sgnd_name" == "$wanted" || "$_sgnd_short" == "$wanted" ]]; then
                printf '%s\n' "$spec"
                return 0
            fi
        done

        return 1
    }
    
    # fn: _sgnd_arg_validate_enum - Validate an enum argument value
        # . Purpose
        #   Test whether a supplied value is present in a comma-separated choice list.
        #
        # . Behavior
        #   - Splits the allowed choices on commas.
        #   - Compares the value with each allowed choice exactly.
        #   - Produces no output.
        #
        # . Arguments
        #   $1  Value to validate.
        #   $2  Comma-separated list of allowed values.
        #
        # . Returns
        #   0 when the value is allowed.
        #   1 when the value is not allowed.
        #
        # . Usage
        #   _sgnd_arg_validate_enum "dark" "2026-07-31" && printf 'Success\n' || printf 'Failed\n'
    _sgnd_arg_validate_enum() {
        local value="$1"
        local choices_csv="$2"

        local choice
        local ok=0
        local choices_arr=()

        IFS=',' read -r -a choices_arr <<< "$choices_csv"
        for choice in "${choices_arr[@]}"; do
            if [[ "$choice" == "$value" ]]; then
                ok=1
                break
            fi
        done

        [[ "$ok" -eq 1 ]]
    }

    # fn: _sgnd_arg_init_defaults - Initialize argument defaults
        # . Purpose
        #   Initialize argument target variables from builtin and/or script argument specs.
        #
        # . Behavior
        #   - Selects builtin specs, script specs, or both depending on the source argument.
        #   - Initializes only argument target variables that are not already set.
        #   - Uses the configured default (or 0 for flags, empty for values/enums) when initialization is required.
        #   - Preserves values already restored from state/config so explicit CLI arguments can override them later.
        #   - Stores the selected combined specification in SGND_EFFECTIVE_ARGS_SPEC.
        #
        # . Arguments
        #   $1  Source selector: builtins, script, or both.
        #       Default: both
        #
        # Inputs (globals):
        #   SGND_BUILTIN_ARGS, SGND_ARGS_SPEC
        #
        # Outputs (globals):
        #   SGND_EFFECTIVE_ARGS_SPEC and configured argument target variables.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _sgnd_arg_init_defaults both
    _sgnd_arg_init_defaults() {
        local source="${1:-both}"
        local -a args=()

        case "$source" in
            builtins)
                if declare -p SGND_BUILTIN_ARGS >/dev/null 2>&1; then
                    args+=( "${SGND_BUILTIN_ARGS[@]}" )
                fi
                ;;
            script)
                if declare -p SGND_ARGS_SPEC >/dev/null 2>&1; then
                    args+=( "${SGND_ARGS_SPEC[@]}" )
                fi
                ;;
            both|*)
                if declare -p SGND_BUILTIN_ARGS >/dev/null 2>&1; then
                    args+=( "${SGND_BUILTIN_ARGS[@]}" )
                fi
                if declare -p SGND_ARGS_SPEC >/dev/null 2>&1; then
                    args+=( "${SGND_ARGS_SPEC[@]}" )
                fi
                ;;
        esac

        local spec
        local init_value

        for spec in "${args[@]}"; do
            _sgnd_arg_split "$spec"
            [[ -n "${_sgnd_var:-}" && -n "${_sgnd_type:-}" ]] || continue

            case "$_sgnd_type" in
                flag)
                    init_value="${_sgnd_default:-0}"
                    ;;
                value|enum)
                    init_value="${_sgnd_default:-}"
                    ;;
                *)
                    continue
                    ;;
            esac

            # State/config is loaded before script arguments are parsed. Do not let
            # argument-spec defaults overwrite an already restored or explicitly seeded value.
            if [[ ! -v "$_sgnd_var" ]]; then
                printf -v "$_sgnd_var" '%s' "$init_value"
            fi
        done

        SGND_EFFECTIVE_ARGS_SPEC=( "${args[@]}" )
    }

# - Public API ----------------------------------------------------------------------
    # var: Help layout settings
        # . Purpose
        #   Configure indentation used by sgnd_show_help when rendering section headers
        #   and option descriptions.
        #
        # Variables:
        #   _header_indent  Left padding for help section headers.
        #   _text_indent    Left padding for option description lines.
    _header_indent=2
    _text_indent=3

    # var: SGND_BUILTIN_ARGS - Builtin framework argument specifications
        # . Purpose
        #   Define standard command-line options available to framework-enabled scripts.
        #
        # Format:
        #   name|short|type|target_variable|help|default|choices
        #
        # Notes:
        #   - type is flag, value, or enum.
        #   - enum choices are comma-separated.
        #   - Unset target variables are initialized by _sgnd_arg_init_defaults.
        #   - Existing state/config values are preserved until an explicit CLI option overrides them.
    SGND_BUILTIN_ARGS=(
        "dryrun|D|flag|FLAG_DRYRUN|Emulate only; do not perform actions|"
        "help|H|flag|FLAG_HELP|Show command-line help and exit|"
        "log|G|flag|FLAG_LOG|Enable logfile output|"
        "loglevel||enum|ARG_LOGLEVEL|Set console output level||silent,quiet,normal,verbose,debug,trace"
        "show||enum|ARG_SHOW|Show internal information and exit||args,cfg,state,meta,license,readme,env"
        "statereset|R|flag|FLAG_STATERESET|Reset the state file|"
        "theme|T|value|ARG_THEME|Select a UI theme||"
    )

    # var: SGND_BUILTIN_EXAMPLES - Builtin help examples
        # . Purpose
        #   Provide reusable help examples for standard framework options.
        #
        # Notes:
        #   - Examples may be merged with SGND_SCRIPT_EXAMPLES by sgnd_show_help.
        #   - SGND_SCRIPT_NAME is resolved lazily for display.
    SGND_BUILTIN_EXAMPLES=(
         "  ${SGND_SCRIPT_NAME:-<script>} --dryrun --loglevel debug"
         "  ${SGND_SCRIPT_NAME:-<script>} --log --loglevel silent"
         "  ${SGND_SCRIPT_NAME:-<script>} --show env"
    ) 
    # fn: sgnd_show_help - Show help
        # . Purpose
        #   Print usage information generated from a SolidGroundUX argument specification.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $0  ARG0 - Positional value used by this function.
        #   $1  INCLUDE_BUILTINS - Positional value used by this function.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_show_help "example-0" "example"
    sgnd_show_help() {
        local include_builtins="${1:-1}"
        local script_name="${SGND_SCRIPT_NAME:-$(basename "${SGND_SCRIPT_FILE:-$0}")}"
        local spaces="   "

        sgnd_print_sectionheader --text "$script_name" 
        sgnd_print "${spaces}Usage:" 
        sgnd_print "\t$script_name [options] [--] [args...]\n" 
        sgnd_print "${spaces}Description:" 
        sgnd_print "\t${SGND_SCRIPT_DESC:-No description available}\n" 

        sgnd_print_sectionheader --text "Script options:" --padleft "$_header_indent"

        if declare -p SGND_ARGS_SPEC >/dev/null 2>&1; then
            local spec opt meta

            for spec in "${SGND_ARGS_SPEC[@]}"; do
                _sgnd_arg_split "$spec"

                # Skip malformed/empty spec entries
                [[ -n "${_sgnd_name:-}" && -n "${_sgnd_type:-}" && -n "${_sgnd_var:-}" ]] || continue

                if [[ -n "${_sgnd_short:-}" ]]; then
                    opt="-$_sgnd_short, --$_sgnd_name"
                else
                    opt="--$_sgnd_name"
                fi

                meta=""
                case "$_sgnd_type" in
                    value) meta=" VALUE" ;;
                    enum)  meta=" {${_sgnd_choices//,/|}}" ;;
                    flag)  meta="" ;;
                esac

                sgnd_print_labeledvalue "$opt$meta" "${_sgnd_help:-}" --pad "$_text_indent" --textclr "$RESET" --valueclr "$RESET" --width 18
            done
        fi

        if (( include_builtins )); then
            if declare -p SGND_BUILTIN_ARGS >/dev/null 2>&1; then
                sgnd_print
                sgnd_print_sectionheader --text "Builtin options:" --padleft "$_header_indent"

                local spec opt meta

                for spec in "${SGND_BUILTIN_ARGS[@]}"; do
                    _sgnd_arg_split "$spec"

                    # Skip malformed/empty spec entries
                    [[ -n "${_sgnd_name:-}" && -n "${_sgnd_type:-}" && -n "${_sgnd_var:-}" ]] || continue

                    # Avoid duplicating help line (already printed above)
                    if [[ "${_sgnd_name}" == "help" ]]; then
                        continue
                    fi

                    if [[ -n "${_sgnd_short:-}" ]]; then
                        opt="-$_sgnd_short, --$_sgnd_name"
                    else
                        opt="--$_sgnd_name"
                    fi

                    meta=""
                    case "$_sgnd_type" in
                        value) meta=" VALUE" ;;
                        enum)  meta=" {${_sgnd_choices//,/|}}" ;;
                        flag)  meta="" ;;
                    esac

                    sgnd_print_labeledvalue "$opt$meta" "${_sgnd_help:-}" --pad "$_text_indent" --textclr "$RESET" --valueclr "$RESET" --width 18
                done
            fi 
        fi

        local -a examples=()

        if (( include_builtins )) && 
            declare -p SGND_BUILTIN_EXAMPLES >/dev/null 2>&1 && 
            declare -p SGND_SCRIPT_EXAMPLES  >/dev/null 2>&1; then
                sgnd_array_union examples SGND_SCRIPT_EXAMPLES SGND_BUILTIN_EXAMPLES
        elif (( include_builtins )) && declare -p SGND_BUILTIN_EXAMPLES >/dev/null 2>&1; then
            examples=( "${SGND_BUILTIN_EXAMPLES[@]}" )
        elif declare -p SGND_SCRIPT_EXAMPLES >/dev/null 2>&1; then
           examples=( "${SGND_SCRIPT_EXAMPLES[@]}" )
        fi

        if (( ${#examples[@]} > 0 )); then
            sgnd_print
            sgnd_print_sectionheader --text "Examples:" --padleft "$_header_indent"

            local ex
            for ex in "${examples[@]}"; do
                sgnd_print "$spaces$ex"
            done
        fi
        
        sgnd_print
        sgnd_print_sectionheader
    }
    # fn: sgnd_parse_args - Parse framework or script command-line arguments
        # . Purpose
        #   Parse command-line options against the selected SolidGroundUX argument
        #   specification while preserving the remaining arguments for a later parse pass.
        #
        # . Behavior
        #   - Selects builtin, script, or combined argument specifications through
        #     SGND_ARGS_SOURCE (builtins, script, or both; default both).
        #   - Initializes defaults only for the argument specification selected for the
        #     current parse pass.
        #   - Parses recognized flag, value, and enum options and updates their declared
        #     target variables.
        #   - With --stop-at-unknown, stops at the first unrecognized option and preserves
        #     that option and the complete remaining command line in SGND_POSITIONAL.
        #   - With --preserve-unknown, consumes recognized options while preserving
        #     unrecognized options and positional values in their original order, then
        #     continues scanning so recognized options may appear anywhere before `--`.
        #   - Treats `--` as the absolute end-of-options marker. Everything following it
        #     is positional data and is preserved without further option interpretation.
        #   - Enables bootstrap to extract framework builtins first and later parse the
        #     preserved script-specific arguments without imposing argument ordering.
        #
        # . Arguments
        #   --stop-at-unknown
        #       Optional parser mode; stop at the first option not present in the active
        #       specification and preserve the remainder.
        #   --preserve-unknown
        #       Optional parser mode; preserve arguments not present in the active
        #       specification and continue parsing later recognized options.
        #   $@  Command-line arguments to parse after optional parser mode switches.
        #
        # Inputs (globals)
        #   SGND_ARGS_SOURCE
        #   SGND_BUILTIN_ARGS
        #   SGND_ARGS_SPEC
        #
        # Outputs (globals)
        #   SGND_POSITIONAL
        #   SGND_EFFECTIVE_ARGS_SPEC
        #   Target variables declared by the selected argument specification.
        #
        # . Returns
        #   0 when parsing succeeds.
        #   1 for unknown options in strict mode, missing values, invalid enum values,
        #   or malformed argument specifications.
        #
        # . Usage
        #   SGND_ARGS_SOURCE=builtins sgnd_parse_args --preserve-unknown "$@"
        #   SGND_ARGS_SOURCE=script sgnd_parse_args "${SGND_POSITIONAL[@]}"
    sgnd_parse_args() {

        local stop_at_unknown=0
        local preserve_unknown=0

        # Optional mode switches.
        while [[ $# -gt 0 ]]; do
            case "${1-}" in
                --stop-at-unknown)
                    stop_at_unknown=1
                    shift
                    ;;
                --preserve-unknown)
                    preserve_unknown=1
                    shift
                    ;;
                *)
                    break
                    ;;
            esac
        done

        # Select which specification set this pass is allowed to consume.
        local source="${SGND_ARGS_SOURCE:-both}"

        # Reset positional/preserved array.
        SGND_POSITIONAL=()

        # Initialize only unset selected argument variables from defaults. Existing
        # state/config values remain in place until an explicit CLI option overrides them.
        _sgnd_arg_init_defaults "$source"

        # Main parse loop
        while [[ $# -gt 0 ]]; do
            saydebug "Parsing argument $1"
            case "$1" in

                # Explicit end-of-options marker
                --)
                    shift
                    SGND_POSITIONAL+=("$@")
                    break
                    ;;

                # Long option: --option
                --*)
                    local opt spec
                    opt="${1#--}"

                    spec="$(_sgnd_arg_find_spec "$opt" || true)"

                    if [[ -z "${spec:-}" ]]; then
                        if (( preserve_unknown )); then
                            SGND_POSITIONAL+=("$1")
                            shift
                            continue
                        fi
                        if (( stop_at_unknown )); then
                            SGND_POSITIONAL+=("$@")
                            break
                        fi
                        echo "Unknown option: $1" >&2
                        return 1
                    fi

                    _sgnd_arg_split "$spec"

                    case "$_sgnd_type" in
                        flag)
                            printf -v "$_sgnd_var" '1'
                            shift
                            ;;

                        value)
                            if [[ $# -lt 2 ]]; then
                                echo "Missing value for --$opt" >&2
                                return 1
                            fi
                            printf -v "$_sgnd_var" '%s' "$2"
                            shift 2
                            ;;

                        enum)
                            if [[ $# -lt 2 ]]; then
                                echo "Missing value for --$opt" >&2
                                return 1
                            fi

                            if ! _sgnd_arg_validate_enum "$2" "${_sgnd_choices:-}"; then
                                echo "Invalid value '$2' for --$opt (allowed: ${_sgnd_choices:-<none>})" >&2
                                return 1
                            fi

                            printf -v "$_sgnd_var" '%s' "$2"
                            shift 2
                            ;;

                        *)
                            echo "Invalid spec type '$_sgnd_type' for --$opt" >&2
                            return 1
                            ;;
                    esac
                    ;;

                # Short option: -o
                -?*)
                    local sopt spec
                    sopt="${1#-}"

                    # Only single short options supported
                    if [[ "${#sopt}" -ne 1 ]]; then
                        echo "Unknown option: $1" >&2
                        return 1
                    fi

                    spec="$(_sgnd_arg_find_spec "$sopt" || true)"

                    if [[ -z "${spec:-}" ]]; then
                        if (( preserve_unknown )); then
                            SGND_POSITIONAL+=("$1")
                            shift
                            continue
                        fi
                        if (( stop_at_unknown )); then
                            SGND_POSITIONAL+=("$@")
                            break
                        fi
                        echo "Unknown option: $1" >&2
                        return 1
                    fi

                    _sgnd_arg_split "$spec"

                    case "$_sgnd_type" in
                        flag)
                            printf -v "$_sgnd_var" '1'
                            shift
                            ;;

                        value)
                            if [[ $# -lt 2 ]]; then
                                echo "Missing value for -$sopt" >&2
                                return 1
                            fi
                            printf -v "$_sgnd_var" '%s' "$2"
                            shift 2
                            ;;

                        enum)
                            if [[ $# -lt 2 ]]; then
                                echo "Missing value for -$sopt" >&2
                                return 1
                            fi

                            if ! _sgnd_arg_validate_enum "$2" "${_sgnd_choices:-}"; then
                                echo "Invalid value '$2' for -$sopt (allowed: ${_sgnd_choices:-<none>})" >&2
                                return 1
                            fi

                            printf -v "$_sgnd_var" '%s' "$2"
                            shift 2
                            ;;

                        *)
                            echo "Invalid spec type '$_sgnd_type' for -$sopt" >&2
                            return 1
                            ;;
                    esac
                    ;;

                # Positional argument. During preservation/extraction passes, keep
                # scanning so later builtin options can still be consumed.
                *)
                    if (( preserve_unknown )); then
                        SGND_POSITIONAL+=("$1")
                        shift
                        continue
                    fi
                    SGND_POSITIONAL+=("$@")
                    break
                    ;;
            esac
        done

        return 0
    }
    # fn: sgnd_builtinarg_handler - Builtinarg handler
        # . Purpose
        #   Handle built-in framework options such as help, debug, verbose, dry-run, logfile, and UI mode.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # Outputs (globals):
        #   May update SGND_* globals shown in the function body.
        #
        # . Side effects
        #   May update files, directories, runtime state, or process state required by the workflow.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, user cancellation, or execution fails.
        #
        # . Usage
        #   sgnd_builtinarg_handler
    sgnd_builtinarg_handler(){
        local show_target="${ARG_SHOW:-}"
        local loglevel="${ARG_LOGLEVEL:-}"
        local theme="${ARG_THEME:-}"

        if (( ${FLAG_LOG:-0} )); then
            SGND_LOGFILE_ENABLED=1
        fi

        # Apply an explicit CLI loglevel without resetting a bootstrap/script default.
        case "$loglevel" in
            silent|quiet|normal|verbose|debug|trace)
                SGND_LOG_LEVEL="$loglevel"
                ;;
        esac

        # Apply an explicit CLI theme without resetting a bootstrap/script default.
        if [[ -n "$theme" ]]; then
            sgnd_theme "$theme" || return $?
            saydebug "Selected theme: $(basename "$SGND_UI_STYLE")"
        fi

        # Info-only builtins: perform action and EXIT.
        if (( FLAG_HELP )); then
            sgnd_show_help
            sayend "Information displayed"
            exit 0
        fi

        case "$show_target" in
            args)
                sgnd_print_args
                sayend "Information displayed"
                exit 0
                ;;
            meta)
                sgnd_print_metadata
                sgnd_print
                sgnd_print_framework_metadata
                sayend "Information displayed"
                exit 0
                ;;
            cfg)
                sgnd_print_sectionheader --text "Script configuration ($SGND_SCRIPT_NAME.cfg)"
                sgnd_print_cfg SGND_SCRIPT_GLOBALS both
                sgnd_print_sectionheader --border "$LN_H" --text "Framework configuration ($SGND_FRAMEWORK_CFG_BASENAME)"
                sgnd_print_cfg SGND_FRAMEWORK_GLOBALS both
                sayend "Information displayed"
                exit 0
                ;;
            state)
                sgnd_print_state
                sayend "Information displayed"
                exit 0
                ;;
            env)
                sgnd_showenvironment
                sayend "Information displayed"
                exit 0
                ;;
            license)
                saydebug "Showing license as requested"
                sgnd_print_license
                sayend "Information displayed"
                exit 0
                ;;
            readme)
                saydebug "Showing README as requested"
                sgnd_print_readme
                sayend "Information displayed"
                exit 0
                ;;
            "")
                ;;
            *)
                sayfail "Unknown show target: $show_target"
                return 1
                ;;
        esac

        # Mutating builtins: perform action and CONTINUE.
        if (( FLAG_STATERESET )); then
            if (( FLAG_DRYRUN )); then
                sayinfo "Would have reset state file."
            else
                sgnd_state_reset
                sayinfo "State file reset as requested."
            fi
        fi
    }





