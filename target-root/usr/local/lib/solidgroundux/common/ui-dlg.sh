# =====================================================================================
# SolidGroundUX - UI Dialogs
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627412
#   Checksum    : 6fff59dd2ae92c589a548ac322d16348ce1aff68c89bb5a5e84d14cda9991b56
#   Source      : ui-dlg.sh
#   Type        : library
#   Group       : UI
#   Purpose     : Provide dialog-style user interaction helpers
#
# Description:
#   Implements dialog-oriented interaction patterns for console applications.
#
#   The library:
#     - Provides higher-level dialog constructs built on top of ui-ask
#     - Supports timed prompts with auto-continue behavior
#     - Normalizes user responses into consistent action tokens
#     - Enables structured interaction flows such as confirmations and selections
#     - Integrates with UI rendering for consistent look and feel
#
# Design principles:
#   - Build on top of primitive input helpers (ui-ask)
#   - Normalize interaction results for predictable scripting
#   - Keep dialogs lightweight and composable
#   - Support both interactive and semi-automated scenarios
#
# Role in framework:
#   - Intermediate interaction layer between raw input (ui-ask) and applications
#   - Used by scripts requiring structured or timed user decisions
#
# Non-goals:
#   - Full-screen or TUI-style dialog systems
#   - Complex workflow/state engines
#   - Persistent dialog sessions
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
# - Internal helpers ------------------------------------------------------------------
    # fn: _dlg_keymap - Dlg keymap
        # . Purpose
        #   Return the dialog key/action mapping used by custom dialog controls.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   _dlg_keymap "example" "example-2"
    _dlg_keymap(){
        local choices="$1"
        local keymap=""
        local paused="${2:-0}"

        [[ "$choices" == *"E"* ]] && keymap+="Enter=continue; "
        [[ "$choices" == *"R"* ]] && keymap+="R=redo; "
        [[ "$choices" == *"C"* ]] && keymap+="C/Esc=cancel; "

        [[ "$choices" == *"Q"* ]] && keymap+="Q=quit; "
        [[ "$choices" == *"A"* ]] && keymap+="Press any key to continue; "
        
        if [[ "$choices" == *"P"* ]]; then
            if (( paused )); then
                keymap+="P/Space=resume; "
            else
                keymap+="P/Space=pause; "
            fi
        fi

        # Trim trailing "; "
        keymap="${keymap%; }"

        printf '%s' "$keymap"
    }

    # fn: sgnd_decision_expand_choices - Decision expand choices
        # . Purpose
        #   Expand decision aliases into canonical/alias records.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_decision_expand_choices "example"
    sgnd_decision_expand_choices() {
        local spec="${1-}"
        local group=""
        local canonical=""
        local alias=""
        local IFS=','

        for group in $spec; do
            canonical=""
            IFS='|' read -r -a _aliases <<< "$group"

            for alias in "${_aliases[@]}"; do
                alias="${alias#"${alias%%[![:space:]]*}"}"
                alias="${alias%"${alias##*[![:space:]]}"}"
                alias="${alias^^}"

                [[ -n "$alias" ]] || continue

                if [[ -z "$canonical" ]]; then
                    canonical="$alias"
                fi

                printf '%s|%s\n' "$canonical" "$alias"
            done
        done
    }


    # fn: sgnd_decision_normalize - Decision normalize
        # . Purpose
        #   Normalize a typed decision alias to its canonical value.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_decision_normalize "dark" "example-2" "dark"
    sgnd_decision_normalize() {
        local value="${1-}"
        local choices="${2-}"
        local default_value="${3-}"
        local line=""
        local canonical=""
        local alias=""

        if [[ -z "$value" ]]; then
            value="$default_value"
        fi

        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        value="${value^^}"

        while IFS='|' read -r canonical alias; do
            [[ "$value" == "$alias" ]] || continue
            printf '%s\n' "$canonical"
            return 0
        done < <(sgnd_decision_expand_choices "$choices")

        return 1
    }

    # fn: sgnd_decision_display_choices - Decision display choices
        # . Purpose
        #   Build a compact display string from a decision choice specification.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_decision_display_choices "example"
    sgnd_decision_display_choices() {
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

            if [[ -n "$out" ]]; then
                out+="/"
            fi
            out+="$first"
        done

        printf '%s\n' "$out"
    }


    # fn: sgnd_decision_from_dialog_rc - Decision from dialog rc
        # . Purpose
        #   Map a dialog return code to a canonical decision value.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_decision_from_dialog_rc "example" "example-2" "dark"
    sgnd_decision_from_dialog_rc() {
        local rc="${1:-}"
        local choices="${2-}"
        local default_value="${3-}"
        local mapped=""

        case "$rc" in
            0|1)
                mapped="$(sgnd_decision_normalize "$default_value" "$choices" "$default_value")" || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            2)
                mapped="$(sgnd_decision_normalize "CANCEL" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || mapped="$(sgnd_decision_normalize "NO" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || mapped="$(sgnd_decision_normalize "QUIT" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            3)
                mapped="$(sgnd_decision_normalize "REDO" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            4)
                mapped="$(sgnd_decision_normalize "QUIT" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || mapped="$(sgnd_decision_normalize "CANCEL" "$choices" "$default_value" 2>/dev/null || true)"
                [[ -n "$mapped" ]] || return 1
                printf '%s\n' "$mapped"
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    }

# - Public API ---------------------------------------------------------------------
    # fn: sgnd_dlg_autocontinue - Dlg autocontinue
        # . Purpose
        #   Show an interruptible dialog-based auto-continue prompt.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_dlg_autocontinue "example" "example-2" "example-3"
    sgnd_dlg_autocontinue() {
        local seconds="${1:-5}"
        local msg="${2:-}"
        local dlgchoices="${3:-AERCPQ}"
        dlgchoices="${dlgchoices^^}"

        local tty="/dev/tty"
        [[ -r "$tty" && -w "$tty" ]] || return 0

        # --- Helpers ---------------------------------------------------------------
        # Reserved keys are matched case-insensitively.
        local reserved="AERCPQH"

        # Build a de-duplicated list of custom keys in encounter order.
        # Excludes reserved letters (A/E/R/C/P/Q/H), but allows Enter/Space/Esc behavior
        # through the existing logic.
        local custom_keys=""
        local _ch=""
        local i=0

        for (( i=0; i<${#dlgchoices}; i++ )); do
            _ch="${dlgchoices:i:1}"
            # Normalize to uppercase for reserved detection
            if [[ "$reserved" == *"$_ch"* ]]; then
                continue
            fi
            # Skip duplicates
            if [[ "$custom_keys" == *"$_ch"* ]]; then
                continue
            fi
            custom_keys+="${_ch}"
        done

        # Return code for a custom key, or empty if not a custom key.
        # Custom keys are matched exactly as provided, but also accept case-insensitive
        # match if the provided key is alphabetic.
        # fn: sgnd_dlg_custom_rc_for_key - Dlg custom rc for key
            # . Purpose
            #   Return the dialog return code associated with a configured key.
            #
            # . Behavior
            #   - Preserves the existing SolidGroundUX console/UI behavior.
            #   - Uses current palette, style, runtime, or logging globals where applicable.
            #
            # . Arguments
            #   $@ - Values consumed by the helper. See usage for the expected call shape.
            #
            # . Output
            #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
            #
            # . Returns
            #   0 on success.
            #   Non-zero when validation, resolution, I/O, or user cancellation fails.
            #
            # . Usage
            #   sgnd_dlg_custom_rc_for_key "example"
        sgnd_dlg_custom_rc_for_key() {
            local pressed="${1:-}"
            local j=0
            local k=""

            for (( j=0; j<${#custom_keys}; j++ )); do
                k="${custom_keys:j:1}"
                if [[ "$pressed" == "$k" ]]; then
                    printf '%d' "$((10 + j))"
                    return 0
                fi
                # If both are letters, accept case-insensitive match
                if [[ "$pressed" =~ ^[A-Za-z]$ && "$k" =~ ^[A-Za-z]$ ]]; then
                    if [[ "${pressed^^}" == "${k^^}" ]]; then
                        printf '%d' "$((10 + j))"
                        return 0
                    fi
                fi
            done

            return 1
        }

        # --- Runtime state --------------------------------------------------------
        local paused=0
        local key=""
        local got=0

        local lines=1
        local hide_keymap=0
        if [[ "$dlgchoices" == *"H"* ]]; then
            hide_keymap=1
        else
            hide_keymap=0
            ((lines++))
        fi

        if [[ -n "$msg" ]]; then
            ((lines++))
        fi

        local clr
        clr="$(sgnd_sgr "$WHITE" "$FX_ITALIC")"

        while true; do
            local line_keymap
            line_keymap="$(_dlg_keymap "$dlgchoices" "$paused")"

            # Message line (optional)
            if [[ -n "$msg" ]]; then
                printf '\r\e[K%s\n' "${SGND_UI_TEXT}${msg}${RESET}" >"$tty"
            fi

            # Keymap line
            if (( ! hide_keymap )); then
                printf '\r\e[K%s\n' "${SGND_UI_TEXT}${line_keymap}${RESET}" >"$tty"
            fi

            if (( paused )); then
                printf '\r\e[K%sPaused... Press P or Space to resume countdown%s' \
                    "$clr" "$RESET" >"$tty"
            else
                printf '\r\e[K%sContinuing in %ds...%s' \
                    "$clr" "$seconds" "$RESET" >"$tty"
            fi

            # Read key
            got=0
            key=""
            if (( paused )); then
                if IFS= read -r -n 1 -s key <"$tty"; then got=1; fi
            else
                if IFS= read -r -n 1 -s -t 1 key <"$tty"; then got=1; fi
            fi

            # Move cursor back up to redraw block next iteration (IMPORTANT: to tty)
                # We move (lines-1) lines up (to the start of the block) and return to column 0,
                # so the next print redraws the block in place.
                # Assumes the block is exactly 'lines' lines tall (message + optional keymap + countdown)
            if (( lines > 1 )); then
                printf '\e[%dA' "$((lines-1))" >"$tty"
            fi
            printf '\r' >"$tty"

            if (( got )); then
                [[ -z "$key" ]] && key=$'\n'

                case "$key" in
                    p|P|" ")
                        [[ "$dlgchoices" == *"P"* ]] || continue
                        (( paused )) && paused=0 || paused=1
                        continue
                        ;;

                    r|R)
                        [[ "$dlgchoices" == *"R"* ]] || continue
                        printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                        return 3
                        ;;

                    c|C|$'\e')
                        [[ "$dlgchoices" == *"C"* ]] || continue
                        printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                        return 2
                        ;;

                    q|Q)
                        [[ "$dlgchoices" == *"Q"* ]] || continue
                        printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                        return 4
                        ;;

                    $'\n'|$'\r')
                        [[ "$dlgchoices" == *"E"* ]] || continue
                        # If you want Enter to count as "any key", use:
                        # [[ "$dlgchoices" == *"E"* || "$dlgchoices" == *"A"* ]] || continue
                        printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                        return 0
                        ;;

                    *)
                        # 1) Custom key? return 10+
                        local rc=""
                        rc="$(sgnd_dlg_custom_rc_for_key "$key" 2>/dev/null || true)"
                        if [[ -n "$rc" ]]; then
                            printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                            return "$rc"
                        fi

                        # 2) Fallback to "any key continues" if enabled
                        [[ "$dlgchoices" == *"A"* ]] || continue
                        printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                        return 0
                        ;;
                esac
            fi


            if (( ! paused )); then      
                ((seconds--))
                if (( seconds < 0 )); then
                    printf '\r\e[%dB\n' "$((lines-1))" >"$tty"
                    saydebug '%s\n' "${SGND_UI_TEXT}Auto-continued.${RESET}" >"$tty"
                    return 1
                fi
            fi
        done
    }

    # fn: sgnd_prompt_fromlist - Prompt fromlist
        # . Purpose
        #   Prompt the user to select one value from a list.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --labelwidth VALUE
        #   --autoalign VALUE
        #   --colorize VALUE
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_prompt_fromlist --labelwidth --autoalign --colorize
    sgnd_prompt_fromlist() {
        local labelwidth=0
        local autoalign=0
        local colorize="both"

        # ---- parse optional parameters ---------------------------------
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
                --)
                    shift
                    break
                    ;;
                *)
                    break
                    ;;
            esac
        done

        # ---- compute labelwidth if autoalign is enabled -----------------
        if (( autoalign )) && (( labelwidth <= 0 )); then
            local line key label def validator
            local w=0

            for line in "$@"; do
                sgnd_parse_statespec "$line"
                key="$(sgnd_trim "$_statekey")"
                label="$(sgnd_trim "$_statelabel")"

                _td_is_ident "$key" || continue
                [[ -n "$label" ]] || label="$key"

                ((${#label} > w)) && w=${#label}
            done

            labelwidth="$w"
        fi

        # ---- main prompt loop ------------------------------------------
        local line key label def validator
        local current chosen

        for line in "$@"; do
            sgnd_parse_statespec "$line"

            key="$(sgnd_trim "$_statekey")"
            label="$(sgnd_trim "$_statelabel")"
            def="$(sgnd_trim "$_statedefault")"
            validator="$(sgnd_trim "$_statevalidate")"

            _td_is_ident "$key" || { saywarning "Skipping invalid state key: '$key'"; continue; }
            [[ -n "$label" ]] || label="$key"

            # ---- optional label alignment --------------------------------
            if (( labelwidth > 0 )); then
                label="$(sgnd_fill_right "$label" "$labelwidth" " ")"
            fi

            current="${!key-}"
            if [[ -n "$current" ]]; then
                chosen="$current"
            else
                chosen="$def"
            fi

            if [[ -n "$validator" ]]; then
                ask --label "$label" --var "$key" \
                    --default "$chosen" \
                    --validate "$validator" \
                    --colorize "$colorize"
            else
                ask --label "$label" --var "$key" \
                    --default "$chosen" \
                    --colorize "$colorize"
            fi
        done
    }

    # fn: sgnd_ask_decision - Ask decision
        # . Purpose
        #   Ask a constrained symbolic decision using the dialog helpers when available.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --label VALUE
        #   --choices VALUE
        #   --default VALUE
        #   --var VALUE
        #   --seconds VALUE
        #   --dlgchoices VALUE
        #   --displaychoices VALUE
        #   --colorize VALUE
        #   --labelclr VALUE
        #   --inputclr VALUE
        #   --labelwidth VALUE
        #   --pad VALUE
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_ask_decision "example" "example-2"
    sgnd_ask_decision() {
        local label=""
        local choices=""
        local default_value=""
        local var_name="decision"
        local seconds=0
        local dlgchoices="ERCPQTH"
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
        local dlg_message=""
        local dlg_rc=0

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)          label="$2"; shift 2 ;;
                --choices)        choices="$2"; shift 2 ;;
                --default)        default_value="$2"; shift 2 ;;
                --var)            var_name="$2"; shift 2 ;;
                --seconds)        seconds="$2"; shift 2 ;;
                --dlgchoices)     dlgchoices="$2"; shift 2 ;;
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
            display="$(sgnd_decision_display_choices "$choices")"
            [[ -n "$display" ]] && prompt_label+=" [$display]"
        fi

        # optional timed phase
        if [[ "$seconds" =~ ^[0-9]+$ ]] && (( seconds > 0 )); then
            dlg_message="$prompt_label"
            sgnd_dlg_autocontinue "$seconds" "$dlg_message" "$dlgchoices"
            dlg_rc=$?

            canonical="$(sgnd_decision_from_dialog_rc "$dlg_rc" "$choices" "$default_value" 2>/dev/null || true)"
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

            canonical="$(sgnd_decision_normalize "$typed" "$choices" "$default_value")" && break

            saywarning "Invalid choice: $typed"
        done

        printf -v "$var_name" '%s' "$canonical"
    }


