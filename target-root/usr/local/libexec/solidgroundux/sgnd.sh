#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Framework Preference Utility
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627515
#   Shortname   : SGND
#   Source      : sgnd.sh
#   Type        : script
#   Group       : Framework Utilities
#   Purpose     : Show and change transferable SolidGroundUX framework preferences
#
#   Checksum : 3773a61795693d926f1070cef9cc81bfeffe47123b40c8e8a15bef49072d93d0
# Description:
#   Provides a small command-line front end for the transferable SolidGroundUX framework
#   settings also used by the Management Console. It can show or change console logging,
#   file logging, and the active UI theme without maintaining a separate configuration.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail

# --- Bootstrap ----------------------------------------------------------------------
    # fn$ _framework_locator - Resolve and load the active SolidGroundUX framework
        # . Purpose
        #   Determine the filesystem root of the currently executing SolidGroundUX tree
        #   from the script's physical path, then load the executable runtime library.
        #
        # . Behavior
        #   - Resolves the physical path of the executing script.
        #   - Treats usr, etc, and var as the canonical top-level SolidGroundUX tree roots.
        #   - Uses the last occurrence of one of those path components to determine the
        #     active filesystem root.
        #   - Resolves production scripts beneath /usr, /etc, or /var to root (/).
        #   - Resolves staged/development trees to the path prefix preceding the detected
        #     usr, etc, or var component.
        #   - Loads sgnd-exe-common.sh from the resolved framework root when available.
        #   - For staged/development trees where the executable common library is not
        #     present, falls back to the installed framework copy without changing
        #     SGND_FRAMEWORK_ROOT.
        #
        # . Globals (write)
        #   SGND_FRAMEWORK_ROOT
        #
        # . Output
        #   Writes fatal bootstrap errors to stderr using printf because framework UI
        #   helpers are not available until sgnd-exe-common.sh has been loaded.
        #
        # . Returns
        #   0 when the framework root was resolved and executable common library loaded.
        #   126 when the script path cannot be resolved, no canonical root component can
        #   be found, or the executable common library is unreadable.
        #
        # . Usage
        #   _framework_locator || return $?
    _framework_locator() {
        local script_file=""
        local path_without_root=""
        local component=""
        local framework_root=""
        local exe_common=""
        local index=0
        local root_index=-1
        local -a path_parts=()

        script_file="$(readlink -f "${BASH_SOURCE[0]}")" || {
            printf 'FATAL: Cannot resolve executable path: %s\n' "${BASH_SOURCE[0]}" >&2
            return 126
        }

        path_without_root="${script_file#/}"
        IFS='/' read -r -a path_parts <<< "$path_without_root"

        for index in "${!path_parts[@]}"; do
            component="${path_parts[$index]}"
            case "$component" in
                usr|etc|var)
                    root_index=$index
                    ;;
            esac
        done

        if (( root_index < 0 )); then
            printf 'FATAL: Cannot determine SolidGroundUX framework root from: %s\n' "$script_file" >&2
            return 126
        fi

        if (( root_index == 0 )); then
            framework_root="/"
        else
            framework_root=""
            for (( index=0; index<root_index; index++ )); do
                framework_root+="/${path_parts[$index]}"
            done
        fi

        SGND_FRAMEWORK_ROOT="$framework_root"

        if [[ "$SGND_FRAMEWORK_ROOT" == "/" ]]; then
            exe_common="/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        else
            exe_common="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"

            if [[ ! -r "$exe_common" ]]; then
                exe_common="/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
            fi
        fi

        [[ -r "$exe_common" ]] || {
            printf 'FATAL: Cannot read executable common library: %s\n' "$exe_common" >&2
            return 126
        }

        # shellcheck source=/dev/null
        source "$exe_common"
    }

# --- Script metadata ----------------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"

# --- Framework integration -----------------------------------------------------------
    SGND_USING=()

    # This utility intentionally uses positionals so the public syntax remains concise:
    #   sgnd.sh <setting> <value>
    # Built-in options such as --help and --dryrun are supplied by the executable framework.
    SGND_ARGS_SPEC=()

    SGND_SCRIPT_EXAMPLES=(
        "Examples:"
        "  $SGND_SCRIPT_NAME"
        "  $SGND_SCRIPT_NAME consoleloglevel quiet"
        "  $SGND_SCRIPT_NAME fileloglevel verbose"
        "  $SGND_SCRIPT_NAME theme mono-blue"
        "  $SGND_SCRIPT_NAME theme monoblue"
        "  $SGND_SCRIPT_NAME --dryrun consoleloglevel debug"
    )

    SGND_SCRIPT_GLOBALS=()
    SGND_STATE_VARIABLES=()
    SGND_ON_EXIT_HANDLERS=()
    SGND_STATE_SAVE=0

# --- Helpers ------------------------------------------------------------------------
    # fn: _sgnd_preference_valid_loglevel - Validate a transferable log level
        # . Arguments
        #   $1  LEVEL - Requested console or file log level.
        #
        # . Returns
        #   0 for silent, quiet, normal, verbose, debug, or trace; otherwise 1.
        #
        # . Usage
        #   _sgnd_preference_valid_loglevel quiet
    _sgnd_preference_valid_loglevel() {
        case "${1:-}" in
            silent|quiet|normal|verbose|debug|trace) return 0 ;;
            *) return 1 ;;
        esac
    }

    # fn: _sgnd_preference_theme_name - Resolve an installed theme to its canonical short name
        # . Purpose
        #   Resolve either the literal short theme name used by sgnd_theme or a convenient
        #   punctuation-free spelling such as monoblue for mono-blue.
        #
        # . Arguments
        #   $1  THEME - Requested theme name.
        #
        # . Output
        #   Prints the canonical short theme name when exactly one installed theme matches.
        #
        # . Returns
        #   0 when a matching installed theme is found; otherwise 1.
        #
        # . Usage
        #   _sgnd_preference_theme_name monoblue
    _sgnd_preference_theme_name() {
        local requested="${1:-}"
        local requested_normalized=""
        local candidate=""
        local short_name=""
        local candidate_normalized=""
        local resolved=""
        local match_count=0
        local -a theme_paths=()

        [[ -n "$requested" && -n "${SGND_STYLE_DIR:-}" ]] || return 1

        requested="${requested##*/}"
        requested="${requested%.sh}"
        requested="${requested#style-}"
        if [[ "$requested" =~ ^[0-9][0-9]-style-(.+)$ ]]; then
            requested="${BASH_REMATCH[1]}"
        fi
        [[ "$requested" == "default-ui-style" ]] && requested="default"
        requested_normalized="${requested//[-_[:space:]]/}"
        requested_normalized="${requested_normalized,,}"

        shopt -s nullglob
        theme_paths=("${SGND_STYLE_DIR%/}"/[0-9][0-9]-style-*.sh)
        shopt -u nullglob

        for candidate in "${theme_paths[@]}"; do
            short_name="${candidate##*/}"
            short_name="${short_name%.sh}"
            short_name="${short_name#[0-9][0-9]-style-}"
            candidate_normalized="${short_name//[-_[:space:]]/}"
            candidate_normalized="${candidate_normalized,,}"

            if [[ "${short_name,,}" == "${requested,,}" || "$candidate_normalized" == "$requested_normalized" ]]; then
                resolved="$short_name"
                match_count=$((match_count + 1))
            fi
        done

        (( match_count == 1 )) || return 1
        printf '%s\n' "$resolved"
    }

    # fn: _sgnd_preference_show - Display the current transferable framework preferences
        # . Returns
        #   0 after rendering current values.
        #
        # . Usage
        #   _sgnd_preference_show
    _sgnd_preference_show() {
        local theme="${SGND_UI_STYLE:-00-style-default.sh}"

        theme="${theme##*/}"
        theme="${theme%.sh}"
        if [[ "$theme" =~ ^[0-9][0-9]-style-(.+)$ ]]; then
            theme="${BASH_REMATCH[1]}"
        else
            theme="${theme#style-}"
            [[ "$theme" == "default-ui-style" ]] && theme="default"
        fi

        sgnd_print_sectionheader "SolidGroundUX framework preferences"
        sgnd_print_labeledvalue --label "Console log level" --value "${SGND_CONSOLE_LOG_LEVEL:-quiet}" --labelwidth 22
        sgnd_print_labeledvalue --label "File log level" --value "${SGND_FILE_LOG_LEVEL:-silent}" --labelwidth 22
        sgnd_print_labeledvalue --label "Theme" --value "$theme" --labelwidth 22
    }

    # fn: _sgnd_preference_set_loglevel - Validate and persist one framework log level
        # . Arguments
        #   $1  KEY   - SGND_CONSOLE_LOG_LEVEL or SGND_FILE_LOG_LEVEL.
        #   $2  VALUE - Requested supported log level.
        #
        # Side effects:
        #   Updates SGND_FRAMEWORK_STATEFILE unless --dryrun is active.
        #
        # . Returns
        #   0 on success; 1 when the value is invalid or persistence fails.
        #
        # . Usage
        #   _sgnd_preference_set_loglevel SGND_CONSOLE_LOG_LEVEL quiet
    _sgnd_preference_set_loglevel() {
        local key="${1:?missing framework state key}"
        local level="${2:-}"

        _sgnd_preference_valid_loglevel "$level" || {
            sayfail "Invalid log level: $level"
            sayinfo "Supported log levels: silent, quiet, normal, verbose, debug, trace"
            return 1
        }

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "DRYRUN: Would set $key to $level in $SGND_FRAMEWORK_STATEFILE."
            return 0
        fi

        sgnd_state_set --file "$SGND_FRAMEWORK_STATEFILE" "$key" "$level" || {
            sayfail "Could not update framework state: $SGND_FRAMEWORK_STATEFILE"
            return 1
        }

        printf -v "$key" '%s' "$level"
        sayok "Framework preference updated: $key=$level"
    }

    # fn: _sgnd_preference_set_theme - Validate, apply, and persist the active framework theme
        # . Arguments
        #   $1  THEME - Installed theme name or unambiguous punctuation-free spelling.
        #
        # Side effects:
        #   Applies the selected theme and updates SGND_FRAMEWORK_STATEFILE unless --dryrun is active.
        #
        # . Returns
        #   0 on success; 1 when the theme is unavailable or cannot be applied/persisted.
        #
        # . Usage
        #   _sgnd_preference_set_theme monoblue
    _sgnd_preference_set_theme() {
        local requested="${1:-}"
        local theme=""

        theme="$(_sgnd_preference_theme_name "$requested")" || {
            sayfail "Theme not found or ambiguous: $requested"
            return 1
        }

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "DRYRUN: Would set the framework theme to $theme."
            return 0
        fi

        sgnd_theme "$theme" || {
            sayfail "Could not apply framework theme: $theme"
            return 1
        }

        sayok "Framework theme updated: $theme"
    }

# --- Main ---------------------------------------------------------------------------
    # fn: main - Show or change transferable SolidGroundUX framework preferences
        # . Purpose
        #   Provide a concise command-line interface to the framework preferences also used
        #   by the Management Console.
        #
        # . Arguments
        #   $@  Framework built-in options followed by optional SETTING VALUE positionals.
        #
        # . Behavior
        #   - With no positionals, displays the current transferable preferences.
        #   - Supports consoleloglevel, fileloglevel, and theme.
        #   - Uses the framework-provided --help and --dryrun behavior.
        #   - Persists log levels through SGND_FRAMEWORK_STATEFILE.
        #   - Applies themes through sgnd_theme, which also updates framework state.
        #
        # . Returns
        #   0 on success; 2 for invalid command syntax; non-zero for validation/persistence errors.
        #
        # . Usage
        #   main "$@"
    main() {
        local setting=""
        local value=""
        local -a positionals=()

        _framework_locator || return $?
        sgnd_exe_start --no-title -- "$@" || return $?

        positionals=("${SGND_BOOTSTRAP_REST[@]:-}")

        if (( ${#positionals[@]} == 0 )); then
            _sgnd_preference_show
            return 0
        fi

        if (( ${#positionals[@]} != 2 )); then
            sayfail "Expected: $SGND_SCRIPT_NAME <setting> <value>"
            sayinfo "Settings: consoleloglevel, fileloglevel, theme"
            return 2
        fi

        setting="${positionals[0],,}"
        value="${positionals[1]}"

        case "$setting" in
            consoleloglevel)
                _sgnd_preference_set_loglevel SGND_CONSOLE_LOG_LEVEL "${value,,}"
                ;;
            fileloglevel)
                _sgnd_preference_set_loglevel SGND_FILE_LOG_LEVEL "${value,,}"
                ;;
            theme)
                _sgnd_preference_set_theme "$value"
                ;;
            *)
                sayfail "Unknown framework preference: $setting"
                sayinfo "Settings: consoleloglevel, fileloglevel, theme"
                return 2
                ;;
        esac
    }

    main "$@"
