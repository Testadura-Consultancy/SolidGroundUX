# =====================================================================================
# SolidGroundUX - UI Messaging
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
#   Checksum    : 8b62b80de4ed98f84c6e24ff4d1a7034eae940a51767119989d6894662f9c585
#   Source      : ui-say.sh
#   Type        : library
#   Group       : UI
#   Purpose     : Provide standardized console messaging helpers
#
# Description:
#   Implements consistent message output helpers for console applications.
#
#   The library:
#     - Provides a unified message API via `say` and typed wrappers (info, ok, warn, etc.)
#     - Applies consistent formatting, prefixes, and optional colorization
#     - Supports console output control via verbosity, debug flags, and message-type filtering
#     - Ensures all messages follow a unified visual and structural style
#     - Optionally performs best-effort file logging when enabled
#
# Design principles:
#   - Consistent message semantics across all scripts
#   - Separation of message intent (type) from rendering and output policy
#   - Respect the framework log-level policy consistently
#   - Keep output predictable and script-friendly
#
# Role in framework:
#   - Core messaging layer used by all SolidGroundUX scripts
#   - Serves as the primary mechanism for user-facing output and diagnostics
#   - Works alongside ui.sh for rendering and formatting
#
# Non-goals:
#   - Persistent logging frameworks or advanced log management
#   - Complex formatting beyond message-level styling
#   - Replacement for dedicated logging systems
#
# Notes:
#   - Console output is governed by SGND_CONSOLE_LOG_LEVEL; file output is governed by SGND_FILE_LOG_LEVEL.
#   - File logging is optional and best-effort; failures do not affect execution.
#   - Logfile writing is independent from console visibility.
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
# - Global defaults ----------------------------------------------------------------
    # Can be overridden in:
    #   - environment
    #   - styles/*.sh
    SAY_DATE_DEFAULT="${SAY_DATE_DEFAULT:-0}"              # 0 = no date, 1 = add date
    SAY_SHOW_DEFAULT="${SAY_SHOW_DEFAULT:-label}"         # label|icon|symbol|all|label,icon|...
    SAY_COLORIZE_DEFAULT="${SAY_COLORIZE_DEFAULT:-label}" # none|label|msg|both|all|date
    SAY_WRITELOG_DEFAULT="${SAY_WRITELOG_DEFAULT:-0}"     # 0 = no log, 1 = log
    SAY_DATE_FORMAT="${SAY_DATE_FORMAT:-%Y-%m-%d %H:%M:%S}"  # date format for --date

    SGND_LINEBREAK_PENDING=0  # Internal flag to track if a line break is needed before the next message (used by sayprogress)

# - Helpers ------------------------------------------------------------------------
    # fn: _say_normalize_log_level - Normalize a log level name
        # . Purpose
        #   Convert aliases and legacy log-level names into a canonical
        #   SolidGroundUX log-level value.
        #
        # . Parameters
        #   $1 Requested log level.
        #
        # . Behavior
        #   - Accepts legacy aliases.
        #   - Returns a canonical log-level name.
        #
        # . Output
        #   Writes the normalized log-level name to stdout.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _say_normalize_log_level "example"
    _say_normalize_log_level() {

        case "${1,,}" in

            off|none|silent)
                printf '%s\n' 'silent'
                ;;

            warn|quiet)
                printf '%s\n' 'quiet'
                ;;

            normal|'')
                printf '%s\n' 'normal'
                ;;

            verbose)
                printf '%s\n' 'verbose'
                ;;

            debug)
                printf '%s\n' 'debug'
                ;;

            trace|all)
                printf '%s\n' 'trace'
                ;;

            *)
                printf '%s\n' 'silent'
                ;;

        esac
    }

    # fn: _say_should_print_console - Determine whether a message should be written to the console
        # . Purpose
        #   Determine whether a message of the specified type should be
        #   written to the console based on the current log level.
        #
        # . Parameters
        #   $1 Message type (START, INFO, WARN, FAIL, DEBUG, TRACE, ...)
        #
        # . Behavior
        #   - Evaluates SGND_CONSOLE_LOG_LEVEL.
        #   - Applies the SolidGroundUX log-level visibility rules.
        #   - Returns success when the message should be displayed.
        #
        # . Globals (read)
        #   SGND_CONSOLE_LOG_LEVEL
        #
        # . Returns
        #   0 if the message should be displayed.
        #   1 if the message should be suppressed.
        #
        # . Usage
        #   _say_should_print_console "example"
    _say_should_print_console() {

        local type="${1^^}"
        local level

        level="$(_say_normalize_log_level "${SGND_CONSOLE_LOG_LEVEL:-silent}")"

        case "$level" in

            silent)
                return 1
                ;;

            quiet)
                case "$type" in
                    WARN|WARNING|FAIL|ERROR)
                        return 0
                        ;;
                    *)
                        return 1
                        ;;
                esac
                ;;

            normal)
                case "$type" in
                    START|STRT|OK|WARN|WARNING|FAIL|ERROR|CANCEL|CNCL|END)
                        return 0
                        ;;
                    *)
                        return 1
                        ;;
                esac
                ;;

            verbose)
                case "$type" in
                    DEBUG|TRACE)
                        return 1
                        ;;
                    *)
                        return 0
                        ;;
                esac
                ;;

            debug)
                case "$type" in
                    TRACE)
                        return 1
                        ;;
                    *)
                        return 0
                        ;;
                esac
                ;;

            trace)
                return 0
                ;;

        esac

        return 1
    }

    # fn: _say_should_write_log - Determine whether a message should be written to the logfile
        # . Purpose
        #   Apply the file log level independently from console visibility.
        #
        # . Arguments
        #   $1  TYPE - Message type.
        #
        # Inputs (globals):
        #   SGND_FILE_LOG_LEVEL
        #
        # . Returns
        #   0 when the message should be logged.
        #   1 when the message should be suppressed.
        #
        # . Usage
        #   _say_should_write_log "example"
    _say_should_write_log() {
        local type="${1^^}"
        local level

        level="$(_say_normalize_log_level "${SGND_FILE_LOG_LEVEL:-verbose}")"

        case "$level" in
            silent) return 1 ;;
            quiet)
                [[ "$type" =~ ^(WARN|WARNING|FAIL|ERROR)$ ]]
                ;;
            normal)
                [[ "$type" =~ ^(START|STRT|OK|WARN|WARNING|FAIL|ERROR|CANCEL|CNCL|END)$ ]]
                ;;
            verbose)
                [[ "$type" != DEBUG && "$type" != TRACE ]]
                ;;
            debug)
                [[ "$type" != TRACE ]]
                ;;
            trace) return 0 ;;
            *) return 1 ;;
        esac
    }

    # fn: _say_caller - Say caller
        # . Purpose
        #   Determine the script or function context that emitted a say message.
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
        #   _say_caller 1
    _say_caller() {
        local i
        for ((i=1; i<${#FUNCNAME[@]}; i++)); do
            case "${FUNCNAME[$i]}" in
                say|sayinfo|saystart|saywarning|sayfail|saycancel|sayok|sayend|saydebug|justsay)
                    continue
                    ;;
                *)
                    printf '%s\t%s\t%s' \
                        "${FUNCNAME[$i]}" \
                        "${BASH_SOURCE[$i]}" \
                        "${BASH_LINENO[$((i-1))]}"
                    return
                    ;;
            esac
        done
        printf '<main>\t<unknown>\t?'
    }

    # fn: _say_write_log - Say write log
        # . Purpose
        #   Append a formatted say message to the active SolidGroundUX log file.
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
        # Outputs (globals):
        #   Updates SolidGroundUX UI/runtime globals documented by the function body.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   _say_write_log "example" "example-2" "2026-07-31"
    _say_write_log() {
        local type="${1^^}"
        local msg="$2"
        local date_str="$3"

        : "${SGND_LOG_MAX_BYTES:=$((25 * 1024 * 1024))}"
        : "${SGND_LOG_KEEP:=5}"
        : "${SGND_LOG_COMPRESS:=0}"

        _say_should_write_log "$type" || return 0

        local logfile
        logfile="$(_sgnd_logfile)" || return 0
        [[ -n "$logfile" ]] || return 0

        local log_ts log_user caller_func caller_file caller_line clean_msg log_line

        if [[ -n "$date_str" ]]; then
            log_ts="$date_str"
        else
            log_ts="$(date "+${SAY_DATE_FORMAT}")"
        fi

        log_user="$(id -un 2>/dev/null || printf '%s' "${USER:-unknown}")"
        IFS=$'\t' read -r caller_func caller_file caller_line <<< "$(_say_caller)"

        clean_msg="$msg"
        clean_msg="$(printf '%s' "$clean_msg" | sed -r 's/\x1B\[[0-9;]*[[:alpha:]]//g')"
        clean_msg="${clean_msg//$'\r'/}"
        clean_msg="${clean_msg//$'\n'/\\n}"
        clean_msg="${clean_msg//$'\t'/\\t}"

        log_line="${log_ts} user=${log_user} type=${type} caller=${caller_func}:${caller_file}:${caller_line} msg=${clean_msg}"

        local size add_bytes
        size=$(stat -c %s "$logfile" 2>/dev/null || echo 0)
        add_bytes=$(( ${#log_line} + 1 ))   # +1 for '\n'

        if (( size + add_bytes >= SGND_LOG_MAX_BYTES )); then
            _sgnd_rotate_logs "$logfile"
        fi

        printf '%s\n' "$log_line" >>"$logfile" 2>/dev/null || true
    }

    # fn: _sgnd_rotate_logs - Rotate logs
        # . Purpose
        #   Rotate log files when log retention settings require it.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # Outputs (globals):
        #   Updates SolidGroundUX UI/runtime globals documented by the function body.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   _sgnd_rotate_logs "/tmp/sgnd-example.txt"
    _sgnd_rotate_logs() {
            # . Usage _sgnd_rotate_logs "/path/to/logfile"
            local logfile="$1"
            [[ -n "$logfile" ]] || return 0
            [[ -f "$logfile" ]] || return 0

            # If not exceeding, do nothing (caller can pre-check; keep safe here too)
            local size
            size="$(wc -c < "$logfile" 2>/dev/null)" || return 0
            (( size >= SGND_LOG_MAX_BYTES )) || return 0

            local i src dst
            # Shift: logfile.N(.gz) -> logfile.(N+1)(.gz)
            for (( i=SGND_LOG_KEEP; i>=1; i-- )); do
                src="${logfile}.${i}"
                dst="${logfile}.$((i+1))"
                [[ -f "$src" ]] && mv -f -- "$src" "$dst" 2>/dev/null || true
                [[ -f "${src}.gz" ]] && mv -f -- "${src}.gz" "${dst}.gz" 2>/dev/null || true
            done

            # Move current to .1
            mv -f -- "$logfile" "${logfile}.1" 2>/dev/null || true

            # Recreate (keep perms reasonable; adjust if you manage perms elsewhere)
            : > "$logfile" 2>/dev/null || true

            # Compress rotated file
            if (( SGND_LOG_COMPRESS )) && [[ -f "${logfile}.1" ]]; then
                gzip -f "${logfile}.1" 2>/dev/null || true
            fi

            # Trim oldest beyond keep
            rm -f -- "${logfile}.$((SGND_LOG_KEEP+1))" "${logfile}.$((SGND_LOG_KEEP+1)).gz" 2>/dev/null || true
    }

    # fn: _sgnd_logfile - Logfile
        # . Purpose
        #   Resolve the active SolidGroundUX log file path.
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
        #   _sgnd_logfile
    _sgnd_logfile() {
        
        # Determine logfile path according to priority:
        # 1. SGND_LOG_PATH if set and usable
        if [[ -n "${SGND_LOG_PATH:-}" ]] && sgnd_can_append "$SGND_LOG_PATH"; then
            printf '%s' "$SGND_LOG_PATH"
            return 0
        fi

        # 2. SGND_ALTLOG_PATH if set and usable
        if [[ -n "${SGND_ALTLOG_PATH:-}" ]] && sgnd_can_append "$SGND_ALTLOG_PATH"; then
            printf '%s' "$SGND_ALTLOG_PATH"
            return 0
        fi

        return 1
    }

    # fn: _sayprogress_write_slot - Sayprogress write slot
        # . Purpose
        #   Render one progress slot in the active sayprogress line.
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
        # Outputs (globals):
        #   Updates SolidGroundUX UI/runtime globals documented by the function body.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   _sayprogress_write_slot "example" "SolidGroundUX example"
    _sayprogress_write_slot() {
        local slot="${1:-0}"
        local text="${2:-}"

        (( slot >= 0 )) || slot=0

        if (( ${SGND_PROGRESS_RESERVED:-0} == 0 )); then
            sayprogress_begin --slots "$(( slot + 1 ))"
        elif (( slot >= SGND_PROGRESS_RESERVED )); then
            slot=$(( SGND_PROGRESS_RESERVED - 1 ))
        fi

        printf '\033[u' >&2

        if (( slot > 0 )); then
            printf '\033[%dB' "$slot" >&2
        fi

        printf '\r\033[2K%-140s' "$text" >&2
        printf '\033[u' >&2

        SGND_LINEBREAK_PENDING=1
    }

    # fn: _sgnd_ensure_linebreak - Ensure linebreak
        # . Purpose
        #   Ensure the next message starts on a clean line after progress output.
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
        # Outputs (globals):
        #   Updates SolidGroundUX UI/runtime globals documented by the function body.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   _sgnd_ensure_linebreak "example"
    _sgnd_ensure_linebreak() {
        if (( ${SGND_LINEBREAK_PENDING:-0} )); then
            printf '\n' >&2
            SGND_LINEBREAK_PENDING=0
        fi
    }

# - Public API ---------------------------------------------------------------------q
    # fn: say - Say
        # . Purpose
        #   Emit a standardized SolidGroundUX console message.
        #
        # . Behavior
        #   - Renders a message using the framework message style maps.
        #   - Supports typed messages such as INFO, STRT, WARN, FAIL, CNCL, OK, END,
        #     DEBUG, and EMPTY.
        #   - Accepts the message type either as a positional first argument or through
        #     the --type option.
        #   - Applies optional date, label, icon, and symbol prefixes according to the
        #     active style configuration.
        #   - Applies optional colorization to the label, message, date, or all visible
        #     message parts.
        #   - Respects SGND_CONSOLE_LOG_LEVEL for console visibility.
        #   - Applies SGND_FILE_LOG_LEVEL independently and writes matching messages, even when console
        #     output is suppressed by the current log level.
        #   - Ensures pending progress output is followed by a clean line break before
        #     printing a normal message.
        #
        # . Arguments
        #   $1...  TYPE and/or MESSAGE
        #          When the first positional argument is a known message type, it is
        #          treated as TYPE and the remaining arguments form the message.
        #          Otherwise all positional arguments form the message and TYPE defaults
        #          to EMPTY.
        #   
        # . options
        #   --type TYPE
        #       Explicitly set the message type.
        #   
        #   --date
        #       Prefix the message with the current date/time using SAY_DATE_FORMAT.
        #
        #   --show VALUE
        #       Select which prefix elements are shown. Supported values are label,
        #       icon, symbol, all, or combinations using comma or plus separators.
        #
        #   --colorize VALUE
        #       Select which parts are colorized. Supported values are none, label,
        #       msg, date, both, and all.
        #
        #   --delay VALUE
        #       Delay after handling the message. The default is 0 (no delay).
        #       Positive values are passed to sleep and may be fractional.
        #       -1 waits for a single keypress.
        #
        # Inputs (globals):
        #   SAY_DATE_DEFAULT, SAY_SHOW_DEFAULT, SAY_COLORIZE_DEFAULT, SAY_DATE_FORMAT
        #   SGND_CONSOLE_LOG_LEVEL, SGND_FILE_LOG_LEVEL, SGND_LINEBREAK_PENDING
        #   LBL_*, ICO_*, SYM_*, MSG_CLR_*, RESET
        #
        # . Outputs
        #   Prints the rendered message to stdout when allowed by SGND_CONSOLE_LOG_LEVEL.
        #   Appends a timestamped best-effort logfile record when allowed by SGND_FILE_LOG_LEVEL.
        #
        # . Returns
        #   0 always. Unknown message types are normalized to EMPTY.
        #
        # . Usage
        #   say INFO "Starting workspace deployment"
        #   say --type WARN --date "Configuration file not found"
        #   say --show label,icon --colorize all OK "Deployment completed"
        #   say "Plain output without a message prefix"
    say() {
      # -- Declarations
        local type="EMPTY"
        local add_date="${SAY_DATE_DEFAULT:-0}"
        local show="${SAY_SHOW_DEFAULT:-label}"
        local colorize="${SAY_COLORIZE_DEFAULT:-label}"
        local delay=0

        local explicit_type=0
        local msg=""
        local s_label=0 s_icon=0 s_symbol=0
        local prefixlength=0

      # -- Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --type)
                    type="${2^^}"
                    explicit_type=1
                    shift 2
                    ;;
                --date)
                    add_date=1
                    prefixlength=$((prefixlength + 19))
                    shift
                    ;;
                --show)
                    show="$2"
                    shift 2
                    ;;
                --colorize)
                    colorize="$2"
                    shift 2
                    ;;
                --delay)
                    delay="${2:?missing value for --delay}"
                    shift 2
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    # Positional TYPE: say STRT "message"
                    if (( ! explicit_type )); then
                        local maybe="${1^^}"
                        case "$maybe" in
                            INFO|STRT|WARN|FAIL|CNCL|OK|END|DEBUG|EMPTY)
                                type="$maybe"
                                explicit_type=1
                                shift
                                continue
                                ;;
                        esac
                    fi
                    break
                    ;;
            esac
        done

        msg="${*:-}"

        # Normalize TYPE
        type="${type^^}"
        case "$type" in
            INFO|STRT|WARN|FAIL|CNCL|OK|END|DEBUG|EMPTY) ;;
            *) type="EMPTY" ;;
        esac

        # EMPTY = print message only (no prefix), still eligible for logging
        if [[ "$type" == "EMPTY" ]]; then
            if _say_should_print_console "EMPTY"; then
                printf '%s\n' "$msg"
            fi
            _say_write_log "EMPTY" "$msg" ""

            case "$delay" in
                -1) read -r -n 1 -s ;;
                0) ;;
                *) sleep "$delay" ;;
            esac

            return 0
        fi

      # -- Resolve style tokens for this TYPE via maps (LBL_*, ICO_*, SYM_*, MSG_CLR_*)
        local lbl icn smb clr
        local w

        w="LBL_${type}";     lbl="${!w:-$type}"
        w="ICO_${type}";     icn="${!w:-}"
        w="SYM_${type}";     smb="${!w:-}"
        w="MSG_CLR_${type}"; clr="${!w:-}"

      # -- Decode --show (supports "label,icon", "label+symbol", "all")
        local sel p
        IFS=',+' read -r -a sel <<<"$show"
        if [[ "${#sel[@]}" -eq 0 ]]; then
            sel=(label)
        fi

        for p in "${sel[@]}"; do
            case "${p,,}" in
                label)  s_label=1;  prefixlength=$((prefixlength + 8)) ;;
                icon)   s_icon=1;   prefixlength=$((prefixlength + 1)) ;;
                symbol) s_symbol=1; prefixlength=$((prefixlength + 3)) ;;
                all)
                    s_label=1; s_icon=1; s_symbol=1
                    prefixlength=$((prefixlength + 16))
                    ;;
            esac
        done

        if (( s_label + s_icon + s_symbol == 0 )); then
            s_label=1
            prefixlength=$((prefixlength + 8))
        fi

      # -- Decode colorize: none|label|msg|date|both|all
        local c_label=0 c_msg=0 c_date=0
        case "${colorize,,}" in
            none) ;;
            label) c_label=1 ;;
            msg)   c_msg=1 ;;
            date)  c_date=1 ;;
            both|all) c_label=1; c_msg=1; c_date=1 ;;
            *) c_label=1 ;;
        esac

      # -- Build final output line and print
        local fnl=""
        local date_str=""
        local rst="${RESET:-}"
        local prefix_parts=()

        _sgnd_ensure_linebreak

        if (( add_date )); then
            date_str="$(date "+${SAY_DATE_FORMAT}")"
            if (( c_date )); then
                prefix_parts+=("${clr}${date_str}${rst}")
            else
                prefix_parts+=("$date_str")
            fi
        fi

        local l_len pad_lbl
        l_len=$(sgnd_visible_len "$lbl")
        pad_lbl=""
        if (( l_len < 8 )); then
            printf -v pad_lbl '%*s' $((8 - l_len)) ''
        fi
        lbl="${lbl}${pad_lbl}"

        if (( s_label )); then
            if (( c_label )); then
                prefix_parts+=("${clr}${lbl}${rst}")
            else
                prefix_parts+=("$lbl")
            fi
        fi

        if (( s_icon )); then
            if (( c_label )); then
                prefix_parts+=("${clr}${icn}${rst}")
            else
                prefix_parts+=("$icn")
            fi
        fi

        if (( s_symbol )); then
            if (( c_label )); then
                prefix_parts+=("${clr}${smb}${rst}")
            else
                prefix_parts+=("$smb")
            fi
        fi

        if ((${#prefix_parts[@]} > 0)); then
            fnl+="${prefix_parts[*]} "
            prefixlength=$((prefixlength + 1))
        fi

        local v_len
        v_len=$(sgnd_visible_len "$fnl")

        local pad_col=""
        if (( v_len < prefixlength )); then
            printf -v pad_col '%*s' $((prefixlength - v_len)) ''
        else
            pad_col=" "
        fi
        fnl+="$pad_col"

        if (( c_msg )); then
            fnl+="${clr}${msg}${rst}"
        else
            fnl+="$msg"
        fi

        if _say_should_print_console "$type"; then
            if (( SGND_LINEBREAK_PENDING )); then
                printf '\n' >&2
                SGND_LINEBREAK_PENDING=0
            fi
            printf '%s\n' "$fnl $RESET"
        fi

        _say_write_log "$type" "$msg" "$date_str"

        case "$delay" in
            -1) read -r -n 1 -s ;;
            0) ;;
            *) sleep "$delay" ;;
        esac
    }

    # doc: sayprogress usage patterns - Sayprogress Usage Patterns
        # . Purpose
        #   Describe the intended usage patterns for the sayprogress family.
        #
        # Details:
        #   sayprogress renders one or more transient progress lines. It is useful for
        #   long-running loops where the user should see progress without flooding the
        #   console with a new line for every iteration.
        #
        #   For simple one-line progress output, sayprogress can be called directly.
        #   When no progress region has been reserved yet, the first call automatically
        #   reserves enough space for the requested slot.
        #
        # Usage pattern - simple progress:
        #   total=100
        #   for ((i=1; i<=total; i++)); do
        #       sayprogress --current "$i" --total "$total" --label "Processing files"
        #   done
        #   sayprogress_done
        #
        #   For multi-line progress output, reserve the required number of slots first.
        #   Each subsequent sayprogress call targets a slot. Slot numbering starts at 0.
        #
        # Usage pattern - multiple progress lines:
        #   sayprogress_begin --slots 2
        #   for ((i=1; i<=total; i++)); do
        #       sayprogress --slot 0 --current "$i" --total "$total" --label "Copying files"
        #       sayprogress --slot 1 --current "$i" --total "$total" --label "Updating metadata"
        #   done
        #   sayprogress_done
        #
        # Notes:
        #   - Always call sayprogress_done when a progress region has been used.
        #   - Normal say output will force a line break when progress output is pending.
        #   - The --type option is a bit mask: 1 shows current/total, 2 shows percent,
        #     and 4 shows the progress bar. The default value 7 shows all three.
        #   - Use --width to control the progress bar width and --padleft to indent
        #     the rendered progress line.

    # fn: sayprogress_begin - Sayprogress Begin
        # . Purpose
        #   Reserve one or more console lines for transient progress output.
        #
        # . Behavior
        #   - Prints the requested number of blank lines to stderr.
        #   - Moves the cursor back up to the start of the reserved progress region.
        #   - Stores the reserved slot count in SGND_PROGRESS_RESERVED.
        #   - Marks a pending line break so later normal messages can restore clean
        #     output formatting.
        #
        # . options
        #   --slots COUNT
        #       Number of progress lines to reserve. Values less than 1 are normalized
        #       to 1.
        #
        # . Outputs
        #   Writes terminal cursor control sequences to stderr.
        #
        # . Returns
        #   0 on success.
        #   1 when an unknown argument is supplied.
        #
        # . Usage
        #   sayprogress_begin --slots 2
    sayprogress_begin() {
        local slots=1

        while (($#)); do
            case "$1" in
                --slots) slots="${2:?missing value for --slots}"; shift 2 ;;
                --) shift; break ;;
                *) return 1 ;;
            esac
        done

        (( slots > 0 )) || slots=1

        local i
        for (( i=0; i<slots; i++ )); do
            printf '\n' >&2
        done

        printf '\033[%dA' "$slots" >&2
        printf '\033[s' >&2

        SGND_PROGRESS_RESERVED="$slots"
        SGND_LINEBREAK_PENDING=1
    }

    # fn: sayprogress - Sayprogress
        # . Purpose
        #   Render or update a transient progress line.
        #
        # . Behavior
        #   - Calculates progress from --current and --total.
        #   - Optionally renders current/total, percentage, and a progress bar.
        #   - Writes the rendered line into the selected progress slot.
        #   - Automatically reserves a progress region when none exists yet.
        #   - Clamps invalid progress values to safe ranges.
        #   - Throttles redraws for slot 1 and deeper to reduce terminal I/O.
        #   - Always redraws the first item and the final 10 items.
        #
        # . options
        #   --current VALUE
        #       Current progress value. Values below 0 are normalized to 0.
        #
        #   --total VALUE
        #       Total progress value. Values below 1 are normalized to 1.
        #
        #   --label TEXT
        #       Text appended to the progress indicators.
        #
        #   --type MASK
        #       Bit mask controlling visible indicators. 1 shows current/total,
        #       2 shows percentage, and 4 shows the progress bar.
        #
        #   --barcolor VALUE
        #       Color token used for the progress bar.
        #
        #   --labelcolor VALUE
        #       Color token used for the label.
        #
        #   --indicatorcolor VALUE
        #       Color token used for numeric progress indicators.
        #
        #   --interval COUNT
        #       Redraw interval for throttled progress slots. Applies only to slot 1
        #       and deeper. When omitted, the interval defaults to total / 100,
        #       with a minimum of 1.
        #
        #   --padleft COUNT
        #       Number of spaces to prefix before the progress text.
        #
        #   --slot INDEX
        #       Reserved progress slot to update. Slot numbering starts at 0.
        #
        #   --width COUNT
        #       Width of the progress bar.
        #
        # . Outputs
        #   Writes terminal cursor control sequences and progress text to stderr.
        #
        # . Returns
        #   0 on success.
        #   1 when an unknown argument is supplied.
        #
        # . Usage
        #   sayprogress "example" "example-2"
    sayprogress() {
        local current=0
        local slot=0
        local total=1
        local interval=""
        local label=""
        local progress_type=7
        local bar_color="${PROG_BAR_CLR:-CYAN}"
        local label_color="${PROG_TEXT_CLR:-WHITE}"
        local indicator_color="${PROG_IND_CLR:-CYAN}"
        local padleft=0
        local width=30

        local percent=0
        local filled=0
        local empty=0
        local bar_filled=""
        local bar_empty=""
        local text=""
        local part=""
        local prefix=""
        local reset="${RESET-}"

        while (($#)); do
            case "$1" in
                --current)        current="${2:-0}"; shift 2 ;;
                --total)          total="${2:?missing value for --total}"; shift 2 ;;
                --label)          label="${2:?missing value for --label}"; shift 2 ;;
                --type)           progress_type="${2:-0}"; shift 2 ;;
                --barcolor)       bar_color="${2-}"; shift 2 ;;
                --labelcolor)     label_color="${2-}"; shift 2 ;;
                --indicatorcolor) indicator_color="${2-}"; shift 2 ;;
                --interval)       interval="${2:?missing value for --interval}"; shift 2 ;;
                --padleft)        padleft="${2:?missing value for --padleft}"; shift 2 ;;
                --slot)           slot="${2:?missing value for --slot}"; shift 2 ;;
                --width)          width="${2:?missing value for --width}"; shift 2 ;;
                --) shift; break ;;
                *) return 1 ;;
            esac
        done

        (( total > 0 )) || total=1
        (( current < 0 )) && current=0
        (( current > total )) && current=$total
        (( progress_type > 0 )) || progress_type=1
        (( width > 0 )) || width=30
        (( padleft >= 0 )) || padleft=0

        # Progress throttling.
        # Slot 0 always redraws.
        # Slot 1 and deeper are throttled by --interval or, when omitted,
        # by a default interval derived from total.
        if (( slot >= 1 )); then
            if [[ -z "$interval" ]]; then
                if (( total > 1000 )); then
                    interval=$(( total / 250 ))
                elif (( total > 500 )); then
                    interval=$(( total / 100 ))
                elif (( total > 100 )); then
                    interval=$(( total / 20 ))
                else
                    interval=$(( total / 5 ))
                fi
            fi

            (( interval > 0 )) || interval=1

            # Always update first item and last 10 items.
            # Otherwise only update every interval.
            if (( current > 1 && current < total - 9 && current % interval != 0 )); then
                return 0
            fi
        fi

        percent=$(( current * 100 / total ))
        filled=$(( current * width / total ))
        empty=$(( width - filled ))

        if (( padleft > 0 )); then
            printf -v prefix '%*s' "$padleft" ''
        fi

        # Progress bar
        if (( progress_type & 4 )); then
            [[ -n "$text" ]] && text+="  "

            printf -v bar_filled '%*s' "$filled" ''
            bar_filled="${bar_filled// /#}"

            printf -v bar_empty '%*s' "$empty" ''
            bar_empty="${bar_empty// /.}"

            part="[${bar_filled}${bar_empty}]"

            if [[ -n "$bar_color" ]]; then
                part="${bar_color}${part}${reset}"
            fi

            text+="$part"
        fi

        # Percentage indicator
        if (( progress_type & 2 )); then
            [[ -n "$text" ]] && text+="  "

            printf -v part '%3d%%' "$percent"

            if [[ -n "$indicator_color" ]]; then
                part="${indicator_color}${part}${reset}"
            fi

            text+="$part"
        fi

        # Absolute progress indicator
        if (( progress_type & 1 )); then
            [[ -n "$text" ]] && text+="  "

            part="${current}/${total}"

            if [[ -n "$indicator_color" ]]; then
                part="${indicator_color}${part}${reset}"
            fi

            text+="$part"
        fi

        # Label
        if [[ -n "$label" ]]; then
            [[ -n "$text" ]] && text+="  "

            part="$label"

            if [[ -n "$label_color" ]]; then
                part="${label_color}${part}${reset}"
            fi

            text+="$part"
        fi

        text="${prefix}${text}"

        _sayprogress_write_slot "$slot" "$text"
    }

    # fn: sayprogress_done - Sayprogress Done
        # . Purpose
        #   Clear the reserved progress region and return output to normal flow.
        #
        # . Behavior
        #   - Clears all reserved progress slots.
        #   - Moves the cursor below the progress region.
        #   - Resets SGND_PROGRESS_RESERVED and SGND_LINEBREAK_PENDING.
        #
        # . Outputs
        #   Writes terminal cursor control sequences to stderr.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   sayprogress_done "Package installation complete"
    sayprogress_done() {
        local slots="${SGND_PROGRESS_RESERVED:-0}"
        local i

        (( slots > 0 )) || return 0

        printf '\033[u' >&2

        for (( i=0; i<slots; i++ )); do
            (( i > 0 )) && printf '\033[1B' >&2
            printf '\r\033[2K' >&2
        done

        printf '\033[u' >&2
        printf '\033[%dB' "$slots" >&2

        SGND_PROGRESS_RESERVED=0
        SGND_LINEBREAK_PENDING=0
    }

    # -- Convenience wrappers for say() with a fixed TYPE.
            # fn: sayinfo - Write an informational message
                # . Purpose
                #   Write a normal informational message through the SolidGroundUX message layer.
                #
                # . Arguments
                #   $@ - Message text to write.
                #
                # . Output
                #   Writes the formatted message to the configured console/log targets.
                #
                # . Returns
                #   0 when the message was handled.
                #
                # . Usage
                #   sayinfo "SolidGroundUX example"
        sayinfo() {
            say INFO "$@"
        }

            # fn: saystart - Write a start/progress message
                # . Purpose
                #   Announce the start of an operation through the SolidGroundUX message layer.
                #
                # . Arguments
                #   $@ - Message text to write.
                #
                # . Output
                #   Writes the formatted start message to the configured console/log targets.
                #
                # . Returns
                #   0 when the message was handled.
                #
                # . Usage
                #   saystart "Starting SolidGroundUX example"
        saystart() {
            say STRT "$@"
        }

        # fn: saywarning
            # . Purpose
            #   Emit a WARN message.
            #
            # . Behavior
            #   - Delegates to say WARN.
            #   - Defaults to SGND_UI_WARNING_DELAY (fallback 0.5); an explicit --delay supplied by the caller overrides it.
            #
            # . Usage
            #   saywarning "Example warning"
            #
            # Examples:
            #   saywarning "Configuration missing"
        saywarning() {
            say WARN --delay "${SGND_UI_WARNING_DELAY:-0.5}" "$@"
        }

            # fn: sayfail - Write a failure message
                # . Purpose
                #   Report a failed operation through the SolidGroundUX message layer.
                #
                # . Behavior
                #   - Delegates to say FAIL.
                #   - Defaults to SGND_UI_ERROR_DELAY (fallback 0.5); an explicit --delay supplied by the caller overrides it.
                #
                # . Arguments
                #   $@ - Message text to write.
                #
                # . Output
                #   Writes the formatted failure message to the configured console/log targets.
                #
                # . Returns
                #   0 when the message was handled.
                #
                # . Usage
                #   sayfail "Example failure"
        sayfail() {
            say FAIL --delay "${SGND_UI_ERROR_DELAY:-0.5}" "$@"
        }

            # fn: saycancel - Write a cancellation message
                # . Purpose
                #   Report a cancelled operation through the SolidGroundUX message layer.
                #
                # . Arguments
                #   $@ - Message text to write.
                #
                # . Output
                #   Writes the formatted cancellation message to the configured console/log targets.
                #
                # . Returns
                #   0 when the message was handled.
                #
                # . Usage
                #   saycancel "Operation cancelled"
        saycancel() {
            say CNCL "$@"
        }

            # fn: sayok - Write a success message
                # . Purpose
                #   Report a successful operation through the SolidGroundUX message layer.
                #
                # . Arguments
                #   $@ - Message text to write.
                #
                # . Output
                #   Writes the formatted success message to the configured console/log targets.
                #
                # . Returns
                #   0 when the message was handled.
                #
                # . Usage
                #   sayok "Operation completed"
        sayok() {
            say OK "$@"
        }

            # fn: sayend - Write an operation-complete message
                # . Purpose
                #   Mark the end of an operation through the SolidGroundUX message layer.
                #
                # . Arguments
                #   $@ - Message text to write.
                #
                # . Output
                #   Writes the formatted end message to the configured console/log targets.
                #
                # . Returns
                #   0 when the message was handled.
                #
                # . Usage
                #   sayend "SolidGroundUX example complete"
        sayend() {
            say END "$@"
        }

        # justsay
            # . Purpose
            #   Emit plain text without formatting or logging.
            #
            # . Behavior
            #   - Prints directly to stdout.
            #
            # . Usage
            #   justsay "Hello world"
            #
            # Examples:
            #   justsay "Raw output"
            # fn: justsay - Write plain message text
                # . Purpose
                #   Write message text without applying a semantic say-state such as ok, fail, or warning.
                #
                # . Arguments
                #   $@ - Message text to write.
                #
                # . Output
                #   Writes the message to the configured console/log targets.
                #
                # . Returns
                #   0 when the message was handled.
                #
                # . Usage
                #   justsay "Raw status line"
        justsay() {
            printf '%s\n' "$@"
        }

        # fn: saydebug - Write a debug message
                # . Purpose
                #   Write diagnostic output when debug messaging is enabled by the runtime configuration.
                #
                # . Arguments
                #   $@ - Debug message text to write.
                #
                # . Output
                #   Writes the debug message to the configured console/log targets when enabled.
                #
                # . Returns
                #   0 when the message was ignored or handled.
                #
                # . Usage
                #   saydebug "Example debug message"
        saydebug() {
            local src="${BASH_SOURCE[1]##*/}"
            local func="${FUNCNAME[1]}"
            local line="${BASH_LINENO[0]}"

            say DEBUG "$@" "[$src:$func:$line]"
            return 0
        }

