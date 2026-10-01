# =====================================================================================
# SolidGroundUX - UI Ask
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627412
#   Checksum    : 1b67927682d37294c02b4695b1f31dbbfb7adb02cdc218b8c2b5f0534728013f
#   Source      : ui-ask.sh
#   Type        : library
#   Group       : UI
#   Purpose     : Provide interactive prompting and lightweight dialog utilities
#
# Description:
#   Provides the framework's console interaction layer.
#
#   The library:
#     - Prompts for typed input using labeled questions
#     - Supports editable defaults and validation hooks
#     - Supports constrained symbolic decisions
#     - Supports timed auto-continue prompts with simple intervention keys
#     - Supports typed and immediate choice selection helpers
#     - Supports normalized absolute and relative datetime input through ask_datetime
#     - Supports prompting a variable set from field-spec lines
#     - Reads input from the controlling terminal to avoid stdin conflicts
#
# Public API:
#   - ask
#   - ask_datetime
#   - ask_decision
#   - ask_dlg_autocontinue
#   - ask_selection
#   - ask_choose
#   - ask_choose_immediate
#   - ask_prompt_form
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
    # fn: _ask_expand_choices - Expand compact choice specifications
        # . Purpose
        #   Expand a comma-separated choice specification into one choice per line.
        #
        # . Behavior
        #   - Splits the specification on commas.
        #   - Trims surrounding whitespace from each part.
        #   - Expands single-character ranges such as A-D or 1-4.
        #   - Emits invalid reversed ranges as warnings and skips them.
        #
        # . Arguments
        #   $1 - Choice specification to expand.
        #
        # . Output
        #   Writes one expanded choice per line to stdout.
        #
        # . Returns
        #   0 after processing the supplied specification.
        #
        # . Usage
        #   mapfile -t choices < <(_ask_expand_choices "A-D,Q")
    _ask_expand_choices() {
        local spec="$1"
        local -a out=()
        local -a parts=()
        local part=""
        local start=""
        local end=""
        local i=0
        local s=0
        local e=0

        IFS=',' read -r -a parts <<< "$spec"

        for part in "${parts[@]}"; do
            part="${part#"${part%%[![:space:]]*}"}"
            part="${part%"${part##*[![:space:]]}"}"

            if [[ "$part" =~ ^([[:alnum:]])-([[:alnum:]])$ ]]; then
                start="${BASH_REMATCH[1]}"
                end="${BASH_REMATCH[2]}"

                s=$(printf '%d' "'$start")
                e=$(printf '%d' "'$end")

                if (( s > e )); then
                    saywarning "Invalid range: $part"
                    continue
                fi

                for (( i=s; i<=e; i++ )); do
                    out+=( "$(printf '\\%03o' "$i")" )
                done
            else
                out+=( "$part" )
            fi
        done

        for part in "${out[@]}"; do
            printf '%b\n' "$part"
        done
    }

    # fn: _ask_choice_is_valid
        # . Purpose
        #   Validate a single choice against a ask_choose-style choices list.
        #
        # . Arguments
        #   $1  VALUE
        #   $2  CHOICES
        #
        # . Returns
        #   0 if valid
        #   1 if invalid
        #
        # . Usage
        #   _ask_choice_is_valid "yes" "yes,no,cancel" && printf 'Valid choice\n'
    _ask_choice_is_valid() {
        local value="${1-}"
        local choices="${2-}"
        local opt=""
        local -a expanded=()

        [[ -z "$choices" ]] && return 0

        mapfile -t expanded < <(_ask_expand_choices "$choices")
        for opt in "${expanded[@]}"; do
            if [[ "${value^^}" == "${opt^^}" ]]; then
                return 0
            fi
        done

        return 1
    }

    # fn: _ask_build_prompt - Build a readline-safe ask prompt
        # . Purpose
        #   Build the colored prompt string used by ask-style input functions.
        #
        # . Behavior
        #   - Applies optional left padding and visible label width alignment.
        #   - Adds readline control markers around non-printing ANSI sequences.
        #   - Applies label and input colors according to the colorize mode.
        #
        # . Arguments
        #   $1 - Label text.
        #   $2 - Visible label width, or empty to avoid width padding.
        #   $3 - Number of leading spaces to add before the label.
        #   $4 - ANSI sequence used for the label color.
        #   $5 - ANSI sequence used for the input color.
        #   $6 - Colorize mode: none, label, input, or both.
        #
        # . Output
        #   Writes the prompt string to stdout.
        #
        # . Returns
        #   0 when the prompt string was written.
        #
        # . Usage
        #   prompt="$(_ask_build_prompt "User name" 25 2 $'\e[36m' $'\e[37m' both)"; printf '%s\n' "$prompt"
    _ask_build_prompt() {
        local label="$1"
        local labelwidth="$2"
        local pad="$3"
        local labelclr="$4"
        local inputclr="$5"
        local colorize="$6"
        local readline_safe="${7:-1}"

        local rl_start=""
        local rl_end=""
        local label_color="$labelclr"
        local input_color="$inputclr"
        local padded_label=""
        local padleft=""
        local prompt=""

        if (( readline_safe )); then
            rl_start=$'\001'
            rl_end=$'\002'
        fi

        case "$colorize" in
            none)
                label_color=""
                input_color=""
                ;;
            label)
                input_color=""
                ;;
            input)
                label_color=""
                ;;
            both) ;;
            *) ;;
        esac

        if [[ -n "$labelwidth" && "$labelwidth" =~ ^[0-9]+$ ]]; then
            padded_label="$(sgnd_padded_visible "$label" "$labelwidth")"
        else
            padded_label="$label"
        fi

        padleft="$(sgnd_string_repeat " " "${pad:-0}")"
        padded_label="${padleft}${padded_label}"

        [[ -n "$label_color" ]] && prompt+="${rl_start}${label_color}${rl_end}"
        prompt+="$padded_label"
        [[ -n "${RESET-}" ]] && prompt+="${rl_start}${RESET}${rl_end}"
        prompt+=" : "
        [[ -n "$input_color" ]] && prompt+="${rl_start}${input_color}${rl_end}"

        printf '%s' "$prompt"
    }

    # fn: _ask_validate
        # . Purpose
        #   Run a validation callback when provided.
        #
        # . Arguments
        #   $1  VALIDATE_FUNCTION
        #   $2  VALUE
        #
        # . Returns
        #   0 if valid or no validator is supplied.
        #   Non-zero when the validator rejects the value.
        #
        # . Usage
        #   _ask_validate "42" sgnd_validate_int && printf 'Valid integer\n'
    _ask_validate() {
        local fn="${1-}"
        local value="${2-}"

        [[ -z "$fn" ]] && return 0
        "$fn" "$value"
    }

    # fn: _ask_decision_expand_choices - Expand decision aliases
        # . Purpose
        #   Expand a decision choice specification into canonical/alias pairs.
        #
        # . Behavior
        #   - Splits groups on commas.
        #   - Splits aliases inside each group on pipe characters.
        #   - Uses the first alias in each group as the canonical value.
        #   - Normalizes aliases to uppercase for matching.
        #
        # . Arguments
        #   $1 - Decision specification, for example "YES|Y,NO|N,CANCEL|C".
        #
        # . Output
        #   Writes CANONICAL|ALIAS records to stdout.
        #
        # . Returns
        #   0 after processing the supplied specification.
        #
        # . Usage
        #   _ask_decision_expand_choices "YES|Y,NO|N"
    _ask_decision_expand_choices() {
        local spec="${1-}"
        local group=""
        local canonical=""
        local alias=""
        local IFS=','
        local -a aliases=()

        for group in $spec; do
            canonical=""
            IFS='|' read -r -a aliases <<< "$group"

            for alias in "${aliases[@]}"; do
                alias="${alias#"${alias%%[![:space:]]*}"}"
                alias="${alias%"${alias##*[![:space:]]}"}"
                alias="${alias^^}"

                [[ -n "$alias" ]] || continue
                [[ -z "$canonical" ]] && canonical="$alias"

                printf '%s|%s\n' "$canonical" "$alias"
            done
        done
    }

    # fn: _ask_decision_normalize - Normalize a typed decision
        # . Purpose
        #   Convert a typed decision or alias into its canonical decision value.
        #
        # . Behavior
        #   - Uses the default value when the supplied value is empty.
        #   - Trims surrounding whitespace.
        #   - Compares values case-insensitively through uppercase aliases.
        #
        # . Arguments
        #   $1 - Typed value to normalize.
        #   $2 - Decision choice specification.
        #   $3 - Default value used when $1 is empty.
        #
        # . Output
        #   Writes the canonical decision value to stdout.
        #
        # . Returns
        #   0 when the value matched a known alias.
        #   1 when the value could not be normalized.
        #
        # . Usage
        #   decision="$(_ask_decision_normalize "y" "YES|Y,NO|N" "NO")"
    _ask_decision_normalize() {
        local value="${1-}"
        local choices="${2-}"
        local default_value="${3-}"
        local canonical=""
        local alias=""

        [[ -z "$value" ]] && value="$default_value"

        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        value="${value^^}"

        while IFS='|' read -r canonical alias; do
            [[ "$value" == "$alias" ]] || continue
            printf '%s\n' "$canonical"
            return 0
        done < <(_ask_decision_expand_choices "$choices")

        return 1
    }

    # fn: _ask_decision_display
        # . Purpose
        #   Build a compact display string from a decision specification.
        #
        # . Arguments
        #   $1  CHOICES
        #
        # . Output
        #   Writes display string, e.g. YES/NO.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _ask_decision_display "YES|Y,NO|N,CANCEL|C"
    _ask_decision_display() {
        local spec="${1-}"
        local group=""
        local out=""
        local first=""
        local IFS=','

        for group in $spec; do
            first="${group%%|*}"
            first="${first#"${first%%[![:space:]]*}"}"
            first="${first%"${first##*[![:space:]]}"}"
            [[ -n "$first" ]] || continue
            [[ -n "$out" ]] && out+="/"
            out+="$first"
        done

        printf '%s\n' "$out"
    }

    # fn: _ask_decision_map_dlg_rc - Map autocontinue return codes to decisions
        # . Purpose
        #   Convert ask_dlg_autocontinue return codes into canonical decision values.
        #
        # . Behavior
        #   - Maps continue/timeout behavior to the configured default value.
        #   - Maps cancel-style return codes to CANCEL, QUIT, or NO where available.
        #   - Maps redo return codes to REDO where available.
        #
        # . Arguments
        #   $1 - Return code from ask_dlg_autocontinue.
        #   $2 - Decision choice specification.
        #   $3 - Default decision value.
        #
        # . Output
        #   Writes the mapped canonical decision value to stdout.
        #
        # . Returns
        #   0 when a mapping was found.
        #   1 when the return code cannot be mapped to the supplied choices.
        #
        # . Usage
        #   decision="$(_ask_decision_map_dlg_rc 0 "YES|Y,NO|N,CANCEL|C" "YES")"; printf '%s\n' "$decision"
    _ask_decision_map_dlg_rc() {
        local rc="${1-}"
        local choices="${2-}"
        local default_value="${3-}"
        local mapped=""

        case "$rc" in
            0|1)
                mapped="$(_ask_decision_normalize "$default_value" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            2)
                mapped="$(_ask_decision_normalize "CANCEL" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || mapped="$(_ask_decision_normalize "QUIT" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || mapped="$(_ask_decision_normalize "NO" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            3)
                mapped="$(_ask_decision_normalize "REDO" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    }

    # fn: _ask_parse_fieldspec - Parse an ask_prompt_form field specification
        # . Purpose
        #   Split a form field specification into the temporary parser globals used by ask_prompt_form.
        #
        # . Behavior
        #   - Parses pipe-delimited field specifications.
        #   - Populates _ask_field_key, _ask_field_label, _ask_field_default, and _ask_field_validate.
        #   - Leaves validation of the parsed key to the caller.
        #
        # . Arguments
        #   $1 - Field specification in KEY|LABEL|DEFAULT|VALIDATOR format.
        #
        # Outputs (globals):
        #   _ask_field_key      - Target variable name.
        #   _ask_field_label    - Prompt label.
        #   _ask_field_default  - Default value.
        #   _ask_field_validate - Optional validator function name.
        #
        # . Returns
        #   0 when the specification was parsed.
        #
        # . Usage
        #   _ask_parse_fieldspec "TARGET_DIR|Target directory|/tmp|sgnd_validate_dir_exists"
    _ask_parse_fieldspec() {
        local spec="${1-}"

        IFS='|' read -r \
            _ask_field_key \
            _ask_field_label \
            _ask_field_default \
            _ask_field_validate \
            <<< "$spec"
    }

    # fn: _ask_is_ident
        # . Purpose
        #   Test whether a value is a valid shell variable identifier.
        #
        # . Arguments
        #   $1  VALUE
        #
        # . Returns
        #   0 if valid
        #   1 if invalid
        #
        # . Usage
        #   _ask_is_ident "TARGET_DIR" && printf 'Valid identifier\n'
    _ask_is_ident() {
        [[ "${1-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
    }

    # fn$ _ask_datetime_normalize
        # . Purpose
        #   Normalize an absolute date/time value or SolidGroundUX datetime shortcut.
        #
        # . Behavior
        #   - Accepts absolute values understood by GNU date.
        #   - Resolves N to the current local date and time.
        #   - Resolves D to the start of the current local day.
        #   - Resolves signed relative expressions against the current local time.
        #   - Supports s, m, h, d, M, and y units for seconds, minutes, hours,
        #     days, months, and years respectively.
        #   - Supports combined relative expressions such as -1d2h30m.
        #   - Returns a local ISO-8601 timestamp including the UTC offset.
        #
        # Inputs:
        #   $1 - Absolute date/time value or SolidGroundUX datetime expression.
        #
        # Outputs (stdout):
        #   Normalized ISO-8601 datetime.
        #
        # . Returns
        #   0 when the value was normalized successfully.
        #   1 when the value is empty or invalid.
        #
        # . Usage
        #   normalized="$(_ask_datetime_normalize "-2h30m")"
    _ask_datetime_normalize() {
        local value="${1-}"
        local sign=""
        local remainder=""
        local amount=""
        local unit=""
        local date_unit=""
        local expression="now"

        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        [[ -n "$value" ]] || return 1

        case "$value" in
            N)
                date --iso-8601=seconds
                return $?
                ;;
            D)
                date --iso-8601=seconds -d 'today 00:00:00'
                return $?
                ;;
        esac

        if [[ "$value" =~ ^[+-] ]]; then
            sign="${value:0:1}"
            remainder="${value:1}"
            [[ -n "$remainder" ]] || return 1

            while [[ -n "$remainder" ]]; do
                if [[ "$remainder" =~ ^([0-9]+)([smhdMy])(.*)$ ]]; then
                    amount="${BASH_REMATCH[1]}"
                    unit="${BASH_REMATCH[2]}"
                    remainder="${BASH_REMATCH[3]}"
                else
                    return 1
                fi

                case "$unit" in
                    s) date_unit="seconds" ;;
                    m) date_unit="minutes" ;;
                    h) date_unit="hours" ;;
                    d) date_unit="days" ;;
                    M) date_unit="months" ;;
                    y) date_unit="years" ;;
                    *) return 1 ;;
                esac

                expression+=" $sign $amount $date_unit"
            done

            date --iso-8601=seconds -d "$expression" 2>/dev/null
            return $?
        fi

        date --iso-8601=seconds -d "$value" 2>/dev/null
    }

# - Public API ---------------------------------------------------------------------
    # fn: ask - Ask for a single typed value
        # . Purpose
        #   Prompt the user for one text value through the SolidGroundUX console UI.
        #
        # . Behavior
        #   - Reads from /dev/tty so piped stdin remains available to callers.
        #   - Supports readline editing and editable default values.
        #   - Applies optional label alignment, padding, and input coloring.
        #   - Re-prompts until the optional validation callback accepts the value.
        #
        # . options
        #   --label TEXT
        #       Prompt label shown before the input field.
        #   --var NAME
        #       Shell variable that receives the entered value.
        #   --default VALUE
        #       Editable default value offered to the user.
        #   --validate FUNCTION
        #       Optional validator callback. FUNCTION receives the value as $1 and
        #       must return 0 for valid input and non-zero for invalid input.
        #   --back
        #       Treat a lone Q (case-insensitive) as "back" and return 1 without
        #       assigning the target variable.
        #   --echo
        #       Echo the accepted value and validation marker to the terminal.
        #   --labelwidth WIDTH
        #       Visible width used to align the prompt label.
        #   --pad COUNT
        #       Number of spaces inserted before the prompt label.
        #   --labelclr ANSI
        #       ANSI sequence used for the label.
        #   --inputclr ANSI
        #       ANSI sequence used for the input.
        #   --colorize MODE
        #       Colorize mode: none, label, input, or both.
        #
        # Common validators:
        #   sgnd_validate_text
        #   sgnd_validate_yesno
        #   sgnd_validate_int
        #   sgnd_validate_numeric
        #   sgnd_validate_bool
        #   sgnd_validate_date
        #   sgnd_validate_ipv4
        #   sgnd_validate_cidr
        #   sgnd_validate_slug
        #   sgnd_validate_fs_name
        #   sgnd_validate_file_exists
        #   sgnd_validate_file_not_exists
        #   sgnd_validate_path_exists
        #   sgnd_validate_dir_exists
        #   sgnd_validate_executable
        #
        # Outputs (globals):
        #   Variable named by --var, when --var is supplied.
        #
        # . Output
        #   Writes the value to stdout only when --echo is used without --var.
        #
        # . Side effects
        #   Writes the interactive prompt, validation message, and optional echoed value to /dev/tty.
        #
        # . Returns
        #   0 when a valid value was accepted.
        #   1 when --back is enabled and Q is entered.
        #   2 when /dev/tty is not available.
        #
        # . Usage
        #   ask --label "Target directory" --var TARGET_DIR --default "/tmp" --validate sgnd_validate_dir_exists
    ask() {
        local label=""
        local var_name=""
        local colorize="both"
        local validate_fn=""
        local def_value=""
        local echo_input=0
        local allow_back=0
        local labelwidth=25
        local pad=0
        local labelclr="${SGND_UI_LABEL}"
        local inputclr="${SGND_UI_INPUT}"

        local -a _orig_args=( "$@" )

        local prompt=""
        local value=""
        local ok=1
        local tty_fd=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)       label="$2"; shift 2 ;;
                --labelwidth)  labelwidth="$2"; shift 2 ;;
                --pad)         pad="$2"; shift 2 ;;
                --labelclr)    labelclr="$2"; shift 2 ;;
                --inputclr)    inputclr="$2"; shift 2 ;;
                --var)         var_name="$2"; shift 2 ;;
                --colorize)    colorize="$2"; shift 2 ;;
                --validate)    validate_fn="$2"; shift 2 ;;
                --default)     def_value="$2"; shift 2 ;;
                --back)        allow_back=1; shift ;;
                --echo)        echo_input=1; shift ;;
                --)            shift; break ;;
                *)             [[ -z "$label" ]] && label="$1"; shift ;;
            esac
        done

        [[ "$labelwidth" =~ ^[0-9]+$ ]] || labelwidth=25
        [[ "$pad" =~ ^[0-9]+$ ]] || pad=0

        prompt="$(_ask_build_prompt "$label" "$labelwidth" "$pad" "$labelclr" "$inputclr" "$colorize")"

        exec {tty_fd}</dev/tty || {
            printf "%bNo TTY available%b\n" "$SGND_UI_INVALID" "$RESET"
            return 2
        }

        if [[ -n "$def_value" ]]; then
            IFS= read -u "$tty_fd" -e -p "$prompt" -i "$def_value" value
            [[ -z "$value" ]] && value="$def_value"
        else
            IFS= read -u "$tty_fd" -e -p "$prompt" value
        fi

        exec {tty_fd}<&-
        printf "%b" "$RESET" >/dev/tty

        if (( allow_back )) && [[ "${value^^}" == "Q" ]]; then
            return 1
        fi

        if _ask_validate "$validate_fn" "$value"; then
            ok=1
        else
            ok=0
        fi

        if (( echo_input )); then
            if (( ok )); then
                printf "  %b%s%b %b✓%b\n" \
                    "$inputclr" "$value" "$RESET" \
                    "$SGND_UI_VALID" "$RESET" >/dev/tty
            else
                printf "  %b%s%b %b✗%b\n" \
                    "$inputclr" "$value" "$RESET" \
                    "$SGND_UI_INVALID" "$RESET" >/dev/tty
            fi
        fi

        if (( ! ok )); then
            printf "%bInvalid value. Please try again.%b\n" "$SGND_UI_INVALID" "$RESET" >/dev/tty
            ask "${_orig_args[@]}"
            return
        fi

        if [[ -n "$var_name" ]]; then
            printf -v "$var_name" '%s' "$value"
        elif (( echo_input )); then
            printf '%s\n' "$value"
        fi
    }

    # fn: ask_datetime
        # . Purpose
        #   Prompt for an absolute or relative date/time value and normalize it.
        #
        # . Behavior
        #   - Reuses ask for readline editing, defaults, alignment, and colors.
        #   - Accepts normal date and datetime values understood by GNU date.
        #   - Accepts N for now and D for today at 00:00:00.
        #   - Accepts signed relative values using s, m, h, d, M, and y units.
        #   - Supports combined relative expressions such as -1d2h30m.
        #   - Re-prompts until the entered value can be normalized.
        #   - Displays the resolved ISO-8601 datetime when a shortcut is entered.
        #   - Stores the accepted value as a local ISO-8601 timestamp.
        #
        # . options
        #   --label TEXT
        #       Prompt label shown before the input field.
        #   --var NAME
        #       Shell variable that receives the normalized datetime.
        #   --default VALUE
        #       Editable absolute value or SolidGroundUX datetime shortcut.
        #   --echo
        #       Echo the normalized value after it has been accepted.
        #   --labelwidth WIDTH
        #       Visible width used to align the prompt label.
        #   --pad COUNT
        #       Number of spaces inserted before the prompt label.
        #   --labelclr ANSI
        #       ANSI sequence used for the label.
        #   --inputclr ANSI
        #       ANSI sequence used for the input.
        #   --colorize MODE
        #       Colorize mode: none, label, input, or both.
        #
        # Supported shortcuts:
        #   N       Current local date and time.
        #   D       Current local date at 00:00:00.
        #   s       Seconds.
        #   m       Minutes.
        #   h       Hours.
        #   d       Days.
        #   M       Months.
        #   y       Years.
        #
        # Outputs (globals):
        #   Variable named by --var, when --var is supplied.
        #
        # . Output
        #   Displays the normalized value after N, D, or a signed relative shortcut.
        #   Writes the normalized value to stdout only when --echo is used without --var.
        #
        # . Returns
        #   0 when a valid datetime was accepted.
        #   2 when /dev/tty is unavailable through ask.
        #
        # . Usage
        #   ask_datetime --label "Changed after" --var CHANGED_AFTER --default "-2h"
    ask_datetime() {
        local label=""
        local var_name=""
        local default_value=""
        local colorize="both"
        local labelwidth=25
        local pad=0
        local labelclr="${SGND_UI_LABEL}"
        local inputclr="${SGND_UI_INPUT}"
        local echo_input=0
        local entered=""
        local normalized=""
        local shortcut_entered=0
        local rc=0

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)       label="$2"; shift 2 ;;
                --var)         var_name="$2"; shift 2 ;;
                --default)     default_value="$2"; shift 2 ;;
                --colorize)    colorize="$2"; shift 2 ;;
                --labelwidth)  labelwidth="$2"; shift 2 ;;
                --pad)         pad="$2"; shift 2 ;;
                --labelclr)    labelclr="$2"; shift 2 ;;
                --inputclr)    inputclr="$2"; shift 2 ;;
                --echo)        echo_input=1; shift ;;
                --)            shift; break ;;
                *)             [[ -z "$label" ]] && label="$1"; shift ;;
            esac
        done

        while :; do
            entered="$default_value"

            ask \
                --label "$label" \
                --var entered \
                --default "$default_value" \
                --colorize "$colorize" \
                --labelwidth "$labelwidth" \
                --pad "$pad" \
                --labelclr "$labelclr" \
                --inputclr "$inputclr"
            rc=$?
            (( rc == 0 )) || return "$rc"

            normalized="$(_ask_datetime_normalize "$entered" 2>/dev/null || true)"
            if [[ -n "$normalized" ]]; then
                case "$entered" in
                    N|D) shortcut_entered=1 ;;
                    *)
                        [[ "$entered" =~ ^[+-]([0-9]+[smhdMy])+$ ]] && shortcut_entered=1
                        ;;
                esac
                break
            fi

            saywarning "Invalid date, datetime, or relative datetime expression: $entered"
            default_value="$entered"
        done

        if (( shortcut_entered )); then
            sgnd_print_labeledvalue \
                --label "Resolved" \
                --value "$normalized" \
                --labelwidth "$labelwidth"
        fi

        if [[ -n "$var_name" ]]; then
            printf -v "$var_name" '%s' "$normalized"
        elif (( echo_input )); then
            printf '%s\n' "$normalized"
        fi

        if (( echo_input )) && [[ -n "$var_name" ]]; then
            printf '%s\n' "$normalized" >/dev/tty
        fi

        return 0
    }

    # fn: ask_decision - Ask for a canonical symbolic decision
        # . Purpose
        #   Prompt the user for a constrained decision and store the canonical result.
        #
        # . Behavior
        #   - Displays the configured decision choices next to the prompt by default.
        #   - Accepts aliases such as YES|Y or NO|N and stores the canonical value.
        #   - Can auto-continue after a timeout and map redo/cancel keys to decisions.
        #   - Re-prompts until the entered value matches the configured choice list.
        #
        # . options
        #   --label TEXT
        #       Prompt text displayed to the user.
        #   --choices SPEC
        #       Comma-separated canonical/alias groups, e.g. "YES|Y,NO|N".
        #   --default VALUE
        #       Default decision used for empty input or timeout mapping.
        #   --var NAME
        #       Shell variable that receives the canonical decision. Defaults to decision.
        #   --seconds COUNT
        #       Optional auto-continue countdown before falling back to typed input.
        #   --displaychoices 0|1
        #       Controls whether the compact choice list is shown in the prompt.
        #   --labelwidth WIDTH
        #       Visible width used to align the prompt label.
        #   --pad COUNT
        #       Number of spaces inserted before the prompt label.
        #   --labelclr ANSI
        #       ANSI sequence used for the label.
        #   --inputclr ANSI
        #       ANSI sequence used for the input.
        #   --colorize MODE
        #       Colorize mode passed to ask.
        #
        # Outputs (globals):
        #   Variable named by --var.
        #
        # . Returns
        #   0 when a canonical decision was stored.
        #
        # . Usage
        #   ask_decision --label "Install now" \
        #       --choices "YES|Y,NO|N,CANCEL|C" \
        #       --default "YES" \
        #       --var decision
    ask_decision() {
        local label=""
        local choices=""
        local default_value=""
        local var_name="decision"
        local seconds=0
        local displaychoices=1
        local colorize="both"
        local labelclr="${SGND_UI_LABEL}"
        local inputclr="${SGND_UI_INPUT}"
        local labelwidth=25
        local pad=0

        local prompt_label=""
        local display=""
        local typed=""
        local canonical=""
        local dlg_rc=0

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)          label="$2"; shift 2 ;;
                --choices)        choices="$2"; shift 2 ;;
                --default)        default_value="$2"; shift 2 ;;
                --var)            var_name="$2"; shift 2 ;;
                --seconds)        seconds="$2"; shift 2 ;;
                --displaychoices) displaychoices="$2"; shift 2 ;;
                --colorize)       colorize="$2"; shift 2 ;;
                --labelclr)       labelclr="$2"; shift 2 ;;
                --inputclr)       inputclr="$2"; shift 2 ;;
                --labelwidth)     labelwidth="$2"; shift 2 ;;
                --pad)            pad="$2"; shift 2 ;;
                --)               shift; break ;;
                *)
                    [[ -z "$label" ]] && label="$1"
                    shift
                    ;;
            esac
        done

        prompt_label="$label"
        if [[ -n "$choices" && "$displaychoices" -eq 1 ]]; then
            display="$(_ask_decision_display "$choices")"
            [[ -n "$display" ]] && prompt_label+=" [$display]"
        fi

        if [[ "$seconds" =~ ^[0-9]+$ ]] && (( seconds > 0 )); then
            ask_dlg_autocontinue --seconds "$seconds" --message "$prompt_label" --redo --cancel --pause
            dlg_rc=$?
            canonical="$(_ask_decision_map_dlg_rc "$dlg_rc" "$choices" "$default_value" 2>/dev/null || true)"
            if [[ -n "$canonical" ]]; then
                printf -v "$var_name" '%s' "$canonical"
                return 0
            fi
        fi

        while :; do
            ask \
                --label "$prompt_label" \
                --var typed \
                --default "$default_value" \
                --colorize "$colorize" \
                --labelclr "$labelclr" \
                --inputclr "$inputclr" \
                --labelwidth "$labelwidth" \
                --pad "$pad"

            if [[ -z "$choices" ]]; then
                canonical="${typed^^}"
                break
            fi

            canonical="$(_ask_decision_normalize "$typed" "$choices" "$default_value" 2>/dev/null || true)"
            [[ -n "$canonical" ]] && break

            saywarning "Invalid choice: $typed"
        done

        printf -v "$var_name" '%s' "$canonical"
    }

    # fn: ask_dlg_autocontinue - Show an interruptible auto-continue countdown
        # . Purpose
        #   Display a short countdown prompt that continues automatically unless the user intervenes.
        #
        # . Behavior
        #   - Writes countdown status and optional legend to /dev/tty.
        #   - Allows Enter or any key to continue depending on options.
        #   - Optionally supports redo, cancel, and pause/resume keys.
        #   - Returns distinct codes so callers can map user intervention to decisions.
        #
        # . options
        #   --seconds COUNT
        #       Countdown length in seconds. Defaults to 5.
        #   --message TEXT
        #       Message displayed above the countdown.
        #   --legend TEXT
        #       Custom legend text. When omitted, the standard key legend is built
        #       from the enabled interaction options.
        #   --redo
        #       Enables R as redo, returning 3.
        #   --again
        #       Enables A as again/repeat, returning 3.
        #   --cancel
        #       Enables C or Esc as cancel, returning 2.
        #   --pause
        #       Enables P or Space to pause/resume the countdown.
        #   --anykey
        #       Allows any key to continue immediately.
        #   --hidelegend
        #       Suppresses the key legend line.
        #
        # . Output
        #   Writes countdown UI to /dev/tty.
        #
        # . Returns
        #   0 when the user continues explicitly.
        #   1 when the countdown expires.
        #   2 when the user cancels.
        #   3 when the user requests redo/again.
        #
        # . Usage
        #   ask_dlg_autocontinue --seconds 10 --message "Continuing deployment" --redo --cancel --pause
    ask_dlg_autocontinue() {
        local seconds=5
        local message=""
        local allow_redo=0
        local allow_again=0
        local allow_cancel=0
        local allow_pause=0
        local allow_anykey=0
        local hide_legend=0
        local custom_legend=""

        local tty="/dev/tty"
        local paused=0
        local key=""
        local got=0
        local clr=""
        local line_count=1
        local legend=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --seconds)    seconds="$2"; shift 2 ;;
                --message)    message="$2"; shift 2 ;;
                --legend)     custom_legend="$2"; shift 2 ;;
                --redo)       allow_redo=1; shift ;;
                --again)      allow_again=1; shift ;;
                --cancel)     allow_cancel=1; shift ;;
                --pause)      allow_pause=1; shift ;;
                --anykey)     allow_anykey=1; shift ;;
                --hidelegend) hide_legend=1; shift ;;
                --)           shift; break ;;
                *)
                    [[ -z "$message" ]] && message="$1"
                    shift
                    ;;
            esac
        done

        [[ "$seconds" =~ ^[0-9]+$ ]] || seconds=5
        [[ -r "$tty" && -w "$tty" ]] || return 0

        clr="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_ITALIC")"

        # Visually separate the dialog from preceding output.
        printf '\n' >"$tty"

        [[ -n "$message" ]] && (( line_count++ ))
        (( ! hide_legend )) && (( line_count++ ))

        while true; do
            if [[ -n "$custom_legend" ]]; then
                legend="$custom_legend"
            else
                legend=""
                if (( allow_anykey )); then
                    legend+="Any key=continue; "
                else
                    legend+="Enter=continue; "
                fi
                (( allow_redo )) && legend+="R=redo; "
                (( allow_again )) && legend+="A=again; "
                (( allow_cancel )) && legend+="C/Esc=cancel; "
                if (( allow_pause )); then
                    if (( paused )); then
                        legend+="P/Space=resume; "
                    else
                        legend+="P/Space=pause; "
                    fi
                fi
                legend="${legend%; }"
            fi

            if [[ -n "$message" ]]; then
                printf '\r\033[K%s%s%s\n' "$SGND_UI_TEXT" "$message" "$RESET" >"$tty"
            fi
            if (( ! hide_legend )); then
                printf '\r\033[K%s%s%s\n' "$SGND_UI_TEXT" "$legend" "$RESET" >"$tty"
            fi
            if (( paused )); then
                printf '\r\033[K%sPaused...%s' "$clr" "$RESET" >"$tty"
            else
                printf '\r\033[K%sContinuing in %ds...%s' "$clr" "$seconds" "$RESET" >"$tty"
            fi

            got=0
            key=""
            if (( paused )); then
                if IFS= read -r -n 1 -s key <"$tty"; then
                    got=1
                fi
            else
                if IFS= read -r -n 1 -s -t 1 key <"$tty"; then
                    got=1
                fi
            fi

            if (( line_count > 1 )); then
                printf '\033[%dA' "$((line_count - 1))" >"$tty"
            fi
            printf '\r' >"$tty"

            if (( got )); then
                [[ -z "$key" ]] && key=$'\n'
                case "$key" in
                    p|P|" ")
                        (( allow_pause )) || continue
                        (( paused )) && paused=0 || paused=1
                        continue
                        ;;
                    r|R)
                        (( allow_redo )) || continue
                        printf '\r\033[%dB\033[K\n' "$((line_count - 1))" >"$tty"
                        return 3
                        ;;
                    a|A)
                        (( allow_again )) || continue
                        printf '\r\033[%dB\033[K\n' "$((line_count - 1))" >"$tty"
                        return 3
                        ;;
                    c|C|$'\e')
                        (( allow_cancel )) || continue
                        printf '\r\033[%dB\033[K\n' "$((line_count - 1))" >"$tty"
                        return 2
                        ;;
                    $'\n'|$'\r')
                        printf '\r\033[%dB\033[K\n' "$((line_count - 1))" >"$tty"
                        return 0
                        ;;
                    *)
                        (( allow_anykey )) || continue
                        printf '\r\033[%dB\033[K\n' "$((line_count - 1))" >"$tty"
                        return 0
                        ;;
                esac
            fi

            if (( ! paused )); then
                ((seconds--))
                if (( seconds < 0 )); then
                    printf '\r\033[%dB\033[K\n' "$((line_count - 1))" >"$tty"
                    return 1
                fi
            fi
        done
    }

    # fn: ask_selection - Select one or more values from a numbered list
        # . Purpose
        #   Display a reusable numbered selection list and return the selected value or values.
        #
        # . Behavior
        #   - Accepts the supplied items directly, making normal Bash array expansion usable.
        #   - Uses single-select mode by default.
        #   - Supports multi-select mode with comma-separated numbers and numeric ranges.
        #   - Returns actual item values rather than list indexes.
        #   - Accepts Q to cancel and return to the caller.
        #   - Re-prompts after invalid selections.
        #
        # . options
        #   --label TEXT
        #       Heading displayed above the selection list. Defaults to "Select an option".
        #   --var NAME
        #       Variable that receives the selected value. In --multi mode NAME receives
        #       an indexed array of selected values. Defaults to selection.
        #   --multi
        #       Enable selection of multiple values using entries such as 1,3,5-7.
        #   --items ITEM...
        #       Values to display. This option must be the final option in the call.
        #
        # Outputs (globals):
        #   Variable named by --var. Scalar in single-select mode; indexed array in multi-select mode.
        #
        # . Returns
        #   0 when a valid selection was stored.
        #   1 when the user selects Q to cancel.
        #   2 when no items are supplied or --var is not a valid shell identifier.
        #
        # . Usage
        #   options=("Default" "Dark" "Testadura")
        #   ask_selection --label "Theme" --var theme --items "${options[@]}"
        #
        #   groups=("Domain Admins" "File Server Users" "Accounting")
        #   ask_selection --label "Groups" --var selected_groups --multi --items "${groups[@]}"
    ask_selection() {
        local label="Select an option"
        local var_name="selection"
        local multi=0
        local input=""
        local token=""
        local start=0
        local end=0
        local index=0
        local value=""
        local i=0
        local invalid=0
        local -a items=()
        local -a selected_values=()
        local -A selected_indexes=()

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label) label="$2"; shift 2 ;;
                --var)   var_name="$2"; shift 2 ;;
                --multi) multi=1; shift ;;
                --items)
                    shift
                    items=("$@")
                    break
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    items+=("$1")
                    shift
                    ;;
            esac
        done

        _ask_is_ident "$var_name" || return 2
        (( ${#items[@]} > 0 )) || return 2

        sgnd_print
        sgnd_print_sectionheader --text "$label"

        for (( i=0; i<${#items[@]}; i++ )); do
            sgnd_print --text "$((i + 1)). ${items[i]}" --pad 2
        done
        sgnd_print --text "Q. Back" --pad 2

        while :; do
            input=""
            if (( multi )); then
                ask --label "Selection (comma/range)" --var input
            else
                ask --label "Selection" --var input
            fi

            input="${input#"${input%%[![:space:]]*}"}"
            input="${input%"${input##*[![:space:]]}"}"

            if [[ "${input^^}" == "Q" ]]; then
                return 1
            fi

            if (( ! multi )); then
                if [[ "$input" =~ ^[1-9][0-9]*$ ]] && (( input <= ${#items[@]} )); then
                    printf -v "$var_name" '%s' "${items[input - 1]}"
                    return 0
                fi

                saywarning "Invalid selection: $input"
                continue
            fi

            selected_values=()
            selected_indexes=()
            invalid=0

            IFS=',' read -r -a tokens <<< "$input"
            for token in "${tokens[@]}"; do
                token="${token#"${token%%[![:space:]]*}"}"
                token="${token%"${token##*[![:space:]]}"}"

                if [[ "$token" =~ ^([1-9][0-9]*)-([1-9][0-9]*)$ ]]; then
                    start="${BASH_REMATCH[1]}"
                    end="${BASH_REMATCH[2]}"

                    if (( start > end || end > ${#items[@]} )); then
                        invalid=1
                        break
                    fi

                    for (( index=start; index<=end; index++ )); do
                        selected_indexes["$index"]=1
                    done
                elif [[ "$token" =~ ^[1-9][0-9]*$ ]] && (( token <= ${#items[@]} )); then
                    selected_indexes["$token"]=1
                else
                    invalid=1
                    break
                fi
            done

            if (( invalid || ${#selected_indexes[@]} == 0 )); then
                saywarning "Invalid selection: $input"
                continue
            fi

            for (( index=1; index<=${#items[@]}; index++ )); do
                [[ -n "${selected_indexes[$index]-}" ]] || continue
                value="${items[index - 1]}"
                selected_values+=("$value")
            done

            local -n output_ref="$var_name"
            output_ref=("${selected_values[@]}")
            return 0
        done
    }

    # fn: ask_choose - Ask for a value from a choice list
        # . Purpose
        #   Prompt the user for a choice and store the entered value in a named variable.
        #
        # . Behavior
        #   - Optionally displays the accepted choices next to the prompt label.
        #   - Validates the response against a compact choice list when supplied.
        #   - Supports expanded ranges such as A-D through _ask_expand_choices.
        #   - Can either keep asking or accept the invalid value after warning.
        #
        # . options
        #   --label TEXT
        #       Prompt label shown to the user.
        #   --var NAME
        #       Shell variable that receives the chosen value. Defaults to choice.
        #   --choices SPEC
        #       Comma-separated choices or ranges, e.g. "A-D,Q".
        #   --displaychoices 0|1
        #       Controls whether choices are appended to the label.
        #   --keepasking 0|1
        #       Controls whether invalid choices are re-prompted. Defaults to 1.
        #   --preservecase 0|1
        #       Preserves the exact case of instant single-key choices. Defaults to 0.
        #   --labelwidth WIDTH
        #       Visible width used to align the prompt label.
        #   --pad COUNT
        #       Number of spaces inserted before the prompt label.
        #   --labelclr ANSI
        #       ANSI sequence used for the label.
        #   --inputclr ANSI
        #       ANSI sequence used for the input.
        #   --colorize MODE
        #       Colorize mode passed to ask.
        #
        # Outputs (globals):
        #   Variable named by --var.
        #
        # . Returns
        #   0 after storing the selected or accepted value.
        #
        # . Usage
        #   ask_choose --label "Select action" --choices "A-D,Q" --var action
    ask_choose() {
        local label=""
        local choices=""
        local colorize="both"
        local displaychoices=1
        local keepasking=1
        local preserve_case=0
        local varname="choice"
        local labelwidth=""
        local pad=""
        local labelclr=""
        local inputclr=""

        local _rsp="" # Purposely ugly variablename to minimize risk of collisions

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)          label="$2"; shift 2 ;;
                --var)            varname="$2"; shift 2 ;;
                --colorize)       colorize="$2"; shift 2 ;;
                --choices)        choices="$2"; shift 2 ;;
                --displaychoices) displaychoices="$2"; shift 2 ;;
                --keepasking)     keepasking="$2"; shift 2 ;;
                --labelwidth)     labelwidth="$2"; shift 2 ;;
                --pad)            pad="$2"; shift 2 ;;
                --labelclr)       labelclr="$2"; shift 2 ;;
                --inputclr)       inputclr="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    [[ -z "$label" ]] && label="$1"
                    shift
                    ;;
            esac
        done

        if [[ -n "$choices" && "$displaychoices" -eq 1 ]]; then
            label+=" [$choices]"
        fi

        while :; do
            if [[ -n "$labelclr" || -n "$inputclr" || -n "$labelwidth" || -n "$pad" ]]; then
                local -a ask_opts=(
                    --label "$label"
                    --var _rsp
                    --colorize "$colorize"
                )
                [[ -n "$labelwidth" ]] && ask_opts+=( --labelwidth "$labelwidth" )
                [[ -n "$pad" ]]        && ask_opts+=( --pad "$pad" )
                [[ -n "$labelclr" ]]   && ask_opts+=( --labelclr "$labelclr" )
                [[ -n "$inputclr" ]]   && ask_opts+=( --inputclr "$inputclr" )

                ask "${ask_opts[@]}"
            else
                ask --label "$label" --var _rsp --colorize "$colorize"
            fi

            [[ -z "$choices" ]] && break

            if _ask_choice_is_valid "$_rsp" "$choices"; then
                break
            fi

            saywarning "Invalid choice: $_rsp"
            (( keepasking )) || break
        done

        printf -v "$varname" '%s' "$_rsp"
    }

    # fn: ask_choose_immediate - Ask for a choice with instant single-key acceptance
        # . Purpose
        #   Prompt for a choice while allowing configured single-key choices to be accepted immediately.
        #
        # . Behavior
        #   - Reads one character at a time from /dev/tty.
        #   - Recognizes left and right arrow escape sequences.
        #   - Maps left/right arrows to < and > when those are configured as instant choices.
        #   - Maps Ctrl+R to the symbolic instant choice CTRL-R.
        #   - Accepts instant choices without requiring Enter.
        #   - Allows longer typed values to be completed with Enter.
        #   - Supports backspace editing for the typed buffer.
        #   - Validates the final response against the configured choice list when supplied.
        #
        # . options
        #   --label TEXT
        #       Prompt label shown to the user.
        #   --var NAME
        #       Shell variable that receives the selected value. Defaults to choice.
        #   --choices SPEC
        #       Full accepted choice list, e.g. "A-D,Q".
        #   --instantchoices SPEC
        #       Choices accepted immediately after one key press.
        #   --displaychoices 0|1
        #       Controls whether choices are appended to the label.
        #   --keepasking 0|1
        #       Controls whether invalid choices are re-prompted. Defaults to 1.
        #   --preservecase 0|1
        #       Preserves the exact case of instant single-key choices. Defaults to 0.
        #   --labelwidth WIDTH
        #       Visible width used to align the prompt label.
        #   --pad COUNT
        #       Number of spaces inserted before the prompt label.
        #   --labelclr ANSI
        #       ANSI sequence used for the label.
        #   --inputclr ANSI
        #       ANSI sequence used for the input.
        #   --colorize MODE
        #       Colorize mode passed to the prompt builder.
        #
        # Outputs (globals):
        #   Variable named by --var.
        #
        # . Returns
        #   0 after storing a valid selected value.
        #   1 when reading from /dev/tty fails.
        #
        # . Usage
        #   ask_choose_immediate --label "Menu" --choices "1-9,Q" --instantchoices "1-9,Q" --var menu_choice
    ask_choose_immediate() {
        local label=""
        local choices=""
        local instantchoices=""
        local displaychoices=1
        local keepasking=1
        local preserve_case=0
        local varname="choice"

        local labelwidth=""
        local pad=""
        local labelclr="${SGND_UI_LABEL:-${SGND_UI_TEXT:-}}"
        local inputclr="${SGND_UI_INPUT:-${SGND_UI_TEXT:-}}"
        local colorize="both"

        local _rsp=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)          label="$2"; shift 2 ;;
                --var)            varname="$2"; shift 2 ;;
                --choices)        choices="$2"; shift 2 ;;
                --instantchoices) instantchoices="$2"; shift 2 ;;
                --displaychoices) displaychoices="$2"; shift 2 ;;
                --keepasking)     keepasking="$2"; shift 2 ;;
                --preservecase)   preserve_case="$2"; shift 2 ;;
                --labelwidth)     labelwidth="$2"; shift 2 ;;
                --pad)            pad="$2"; shift 2 ;;
                --labelclr)       labelclr="$2"; shift 2 ;;
                --inputclr)       inputclr="$2"; shift 2 ;;
                --colorize)       colorize="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    [[ -z "$label" ]] && label="$1"
                    shift
                    ;;
            esac
        done

        if [[ -n "$choices" && "$displaychoices" -eq 1 ]]; then
            label+=" [$choices]"
        fi

        while :; do
            local key=""
            local key_sequence=""
            local buffer=""
            local candidate=""
            local prompt=""

            # --- Use shared prompt builder --------------------------------------
            prompt="$(_ask_build_prompt \
                "$label" \
                "$labelwidth" \
                "$pad" \
                "$labelclr" \
                "$inputclr" \
                "$colorize" \
                0)"

            printf '%s' "$prompt" >/dev/tty

            while true; do
                IFS= read -r -s -n 1 key </dev/tty || return 1

                if [[ "$key" == $'\e' ]]; then
                    key_sequence=""
                    IFS= read -r -s -n 2 -t 0.05 key_sequence </dev/tty || true

                    case "$key_sequence" in
                        '[D')
                            if _ask_choice_is_valid "<" "$instantchoices"; then
                                key="<"
                            else
                                continue
                            fi
                            ;;
                        '[C')
                            if _ask_choice_is_valid ">" "$instantchoices"; then
                                key=">"
                            else
                                continue
                            fi
                            ;;
                        *)
                            continue
                            ;;
                    esac
                elif [[ "$key" == $'\x12' ]]; then
                    key="CTRL-R"
                fi

                case "$key" in
                    "")
                        if [[ -n "$buffer" ]]; then
                            printf '\n' >/dev/tty
                            _rsp="$buffer"
                            break
                        fi
                        ;;

                    $'\177'|$'\b')
                        if [[ -n "$buffer" ]]; then
                            buffer="${buffer%?}"
                            printf '\b \b' >/dev/tty
                        fi
                        ;;

                    *)
                        if (( preserve_case )); then
                            candidate="$key"
                        else
                            candidate="${key^^}"
                        fi

                        # --- Instant choice handling -----------------------------
                        if [[ -n "$instantchoices" ]] && _ask_choice_is_valid "$candidate" "$instantchoices"; then
                            printf '\n' >/dev/tty
                            _rsp="$candidate"
                            break
                        fi

                        buffer+="$key"

                        # --- Input coloring (match ask behavior) ----------------
                        if [[ "$colorize" == "both" || "$colorize" == "input" ]]; then
                            printf '%s%s%s' "${inputclr:-}" "$key" "${RESET:-}" >/dev/tty
                        else
                            printf '%s' "$key" >/dev/tty
                        fi
                        ;;
                esac
            done

            [[ -z "$choices" ]] && break

            if _ask_choice_is_valid "$_rsp" "$choices"; then
                break
            fi

            saywarning "Invalid choice: $_rsp"
            (( keepasking )) || break
        done

        printf -v "$varname" '%s' "$_rsp"
    }

    # fn: ask_prompt_form - Prompt for multiple named fields
        # . Purpose
        #   Prompt the user for a list of field specifications and assign each response to its target variable.
        #
        # . Behavior
        #   - Accepts field specifications in KEY|LABEL|DEFAULT|VALIDATOR format.
        #   - Uses the current variable value as the editable default when available.
        #   - Falls back to the field default when the target variable is empty.
        #   - Optionally auto-aligns labels based on the widest field label.
        #   - Skips invalid shell variable names with a warning.
        #
        # . options
        #   --labelwidth WIDTH
        #       Visible label width for all fields.
        #   --autoalign
        #       Calculates label width from the supplied field labels.
        #   --colorize MODE
        #       Colorize mode passed to ask.
        #   --pad COUNT
        #       Number of spaces inserted before each prompt label.
        #   --labelclr ANSI
        #       ANSI sequence used for labels.
        #   --inputclr ANSI
        #       ANSI sequence used for input.
        #
        # . Arguments
        #   FIELD_SPEC...
        #       One or more KEY|LABEL|DEFAULT|VALIDATOR records.
        #
        # Outputs (globals):
        #   Variables named by the KEY component of each valid field specification.
        #
        # . Returns
        #   0 after all valid fields have been prompted.
        #
        # . Usage
        #   ask_prompt_form --autoalign \
        #       "TARGET_DIR|Target directory|/tmp|sgnd_validate_dir_exists" \
        #       "RETRY_COUNT|Retry count|3|sgnd_validate_int"
    ask_prompt_form() {
        local labelwidth=0
        local autoalign=0
        local colorize="both"
        local pad=0
        local labelclr="${SGND_UI_LABEL:-${SGND_UI_TEXT:-}}"
        local inputclr="${SGND_UI_INPUT:-${SGND_UI_TEXT:-}}"

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --labelwidth)
                    labelwidth="$2"
                    shift 2
                    ;;
                --autoalign)
                    autoalign=1
                    shift
                    ;;
                --colorize)
                    colorize="$2"
                    shift 2
                    ;;
                --pad)
                    pad="$2"
                    shift 2
                    ;;
                --labelclr)
                    labelclr="$2"
                    shift 2
                    ;;
                --inputclr)
                    inputclr="$2"
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

        local line=""
        local key=""
        local label=""
        local def=""
        local validator=""
        local current=""
        local chosen=""
        local maxw=0

        # --- auto-align pass -------------------------------------------------------
        if (( autoalign )) && (( labelwidth <= 0 )); then
            for line in "$@"; do
                _ask_parse_fieldspec "$line"

                key="${_ask_field_key:-}"
                label="${_ask_field_label:-}"

                [[ -n "$key" ]] || continue
                _ask_is_ident "$key" || continue

                [[ -n "$label" ]] || label="$key"
                ((${#label} > maxw)) && maxw=${#label}
            done

            labelwidth="$maxw"
        fi

        # --- prompt pass -----------------------------------------------------------
        for line in "$@"; do
            _ask_parse_fieldspec "$line"

            key="${_ask_field_key:-}"
            label="${_ask_field_label:-}"
            def="${_ask_field_default:-}"
            validator="${_ask_field_validate:-}"

            if ! _ask_is_ident "$key"; then
                saywarning "Skipping invalid field key: '$key'"
                continue
            fi

            [[ -n "$label" ]] || label="$key"

            current="${!key-}"
            if [[ -n "$current" ]]; then
                chosen="$current"
            else
                chosen="$def"
            fi

            if [[ -n "$validator" ]]; then
                if [[ -n "$labelclr" && -n "$inputclr" ]]; then
                    ask \
                        --label "$label" \
                        --var "$key" \
                        --default "$chosen" \
                        --validate "$validator" \
                        --colorize "$colorize" \
                        --labelwidth "$labelwidth" \
                        --pad "$pad" \
                        --labelclr "$labelclr" \
                        --inputclr "$inputclr"
                elif [[ -n "$labelclr" ]]; then
                    ask \
                        --label "$label" \
                        --var "$key" \
                        --default "$chosen" \
                        --validate "$validator" \
                        --colorize "$colorize" \
                        --labelwidth "$labelwidth" \
                        --pad "$pad" \
                        --labelclr "$labelclr"
                else
                    ask \
                        --label "$label" \
                        --var "$key" \
                        --default "$chosen" \
                        --validate "$validator" \
                        --colorize "$colorize" \
                        --labelwidth "$labelwidth" \
                        --pad "$pad"
                fi
            else
                if [[ -n "$labelclr" && -n "$inputclr" ]]; then
                    ask \
                        --label "$label" \
                        --var "$key" \
                        --default "$chosen" \
                        --colorize "$colorize" \
                        --labelwidth "$labelwidth" \
                        --pad "$pad" \
                        --labelclr "$labelclr" \
                        --inputclr "$inputclr"
                elif [[ -n "$labelclr" ]]; then
                    ask \
                        --label "$label" \
                        --var "$key" \
                        --default "$chosen" \
                        --colorize "$colorize" \
                        --labelwidth "$labelwidth" \
                        --pad "$pad" \
                        --labelclr "$labelclr"
                else
                    ask \
                        --label "$label" \
                        --var "$key" \
                        --default "$chosen" \
                        --colorize "$colorize" \
                        --labelwidth "$labelwidth" \
                        --pad "$pad"
                fi
            fi
        done
    }



