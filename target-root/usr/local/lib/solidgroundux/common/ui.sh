# =====================================================================================
# SolidGroundUX - UI Rendering
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627322
#   Checksum    : 7d1e8b764491c3ea8d171489d551c2a95a60897b95468049a5fc1a7ae5cd392f
#   Source      : ui.sh
#   Type        : library
#   Group       : UI
#   Purpose     : Provide terminal rendering utilities for styled console output
#
# Description:
#   Provides the core rendering layer for styled terminal output within
#   the SolidGroundUX framework.
#
#   The library:
#     - Defines reusable rendering helpers for text and layout
#     - Applies ANSI colors and text attributes through centralized helpers
#     - Renders labeled values, section headers, title bars, and filled lines
#     - Supports width-aware formatting for terminal output
#     - Provides standardized message and presentation conventions
#
# Design principles:
#   - Centralized styling without inline ANSI codes in consuming modules
#   - Readability over visual complexity
#   - Graceful degradation when styling is disabled or unavailable
#   - Consistent rendering semantics across all console tools
#
# Role in framework:
#   - Core visual layer for console-based SolidGroundUX tooling
#   - Supports higher-level interaction modules such as ui-ask and sgnd-console
#
# Non-goals:
#   - Input handling or dialog flow control
#   - Full terminal capability abstraction beyond framework needs
#   - Graphical or window-based user interface functionality
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
# - Compatibility overrides --------------------------------------------------------
    # Shims to integrate with legacy helpers if present (say/ask), with safe fallbacks.
    # These overrides are intentionally small and policy-free.

    # _sh_err
        # . Purpose
        #   Compatibility shim for legacy "_sh_err" error reporting.
        #
        # . Behavior
        #   - If say() exists, emits a FAIL message via say --type FAIL.
        #   - Otherwise prints the message directly to stderr.
        #
        # . Arguments
        #   $*  MESSAGE
        #       Error text to report.
        #
        # . Side effects
        #   - Writes one error line to stderr, directly or via say().
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _sh_err "SolidGroundUX example error"
        #
        # Examples:
        #   _sh_err "Palette file missing"
    # fn: _sh_err - Sh err
        # . Purpose
        #   Write an error message through say when available, otherwise stderr.
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
        #   _sh_err "$value"
    _sh_err() {
        if declare -f say >/dev/null 2>&1; then
            say --type FAIL "$*"
        else
            printf '%s\n' "${*:-(no message)}" >&2
        fi
    }

    # fn: confirm - Confirm
        # . Purpose
        #   Ask the user for a yes/no confirmation and return success for yes.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   confirm "example"
    confirm() {
        if declare -f ask >/dev/null 2>&1; then
            local _ans

            ask \
                --label "${1:-Are you sure?}" \
                --var _ans \
                --default "N" \
                --validate validate_yesno \
                --colorize both \
                --echo

            [[ "$_ans" =~ ^[Yy]$ ]]
        else
            # fallback to the simple core behavior
            read -rp "${1:-Are you sure?} [y/N]: " _a
            [[ "$_a" =~ ^[Yy]$ ]]
        fi
    }

# - Helpers ------------------------------------------------------------------------
    # fn: _sgnd_ui_resolve_theme_file - Ui resolve theme file
        # . Purpose
        #   Resolve a palette or style name to a readable theme file path.
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
        #   _sgnd_ui_resolve_theme_file "/tmp/sgnd-example.txt" "/tmp/sgnd-example.txt"
    _sgnd_ui_resolve_theme_file() {
        local kind="$1"
        local spec="$2"
        local base
        local file

        if [[ -z "$spec" ]]; then
            printf '_sgnd_ui_resolve_theme_file: missing %s spec\n' "$kind" >&2
            return 2
        fi

        # Treat as explicit file path if it looks like a path or ends with .sh
        if [[ "$spec" == */* || "$spec" == *.sh ]]; then
            file="$spec"
            [[ "$file" != *.sh ]] && file="${file}.sh"
            if [[ -r "$file" ]]; then
                printf '%s' "$file"
                return 0
            fi
            printf 'UI theme %s file not found/readable: %s\n' "$kind" "$file" >&2
            return 3
        fi

        # Name resolution under theme dir
        base="${SGND_UI_THEME_DIR-}"
        if [[ -z "$base" ]]; then
            printf 'UI theme directory not set (SGND_UI_THEME_DIR/SGND_FRAMEWORK_ROOT missing)\n' >&2
            return 4
        fi

        file="${base%/}/${kind}/${spec}.sh"
        if [[ -r "$file" ]]; then
            printf '%s' "$file"
            return 0
        fi

        printf 'UI theme %s "%s" not found at: %s\n' "$kind" "$spec" "$file" >&2
        return 5
    }

# - Public API ---------------------------------------------------------------------
 # -- Public helpers --------------------------------------------------------------
    # fn: sgnd_strip_ansi - Strip ansi
        # . Purpose
        #   Remove ANSI escape sequences from text.
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
        #   sgnd_strip_ansi "example"
    sgnd_strip_ansi() {
        sed -r $'s/\x1B\\[[0-9;?]*[[:alpha:]]//g' <<<"$1"
    }

    # fn: sgnd_visible_len - Visible len
        # . Purpose
        #   Return the visible character length of text after ANSI escape sequences are removed.
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
        #   sgnd_visible_len "example"
    sgnd_visible_len() {
        local plain
        plain="$(sgnd_strip_ansi "$1")"
        printf '%s' "${#plain}"
    }

 # -- Theme loading ---------------------------------------------------------------
    # fn: sgnd_ui_set_theme - Ui set theme
        # . Purpose
        #   Load a SolidGroundUX UI palette and style into the current shell session.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --palette VALUE
        #   --style VALUE
        #   --default VALUE
        #   --help VALUE
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
        #   sgnd_ui_set_theme "example" "example-2"
    sgnd_ui_set_theme() {
        local palette_spec=""
        local style_spec=""
        local use_default=0

        local a
        while (($#)); do
            a="$1"
            case "$a" in
                --palette) palette_spec="${2-}"; shift 2 ;;
                --style)   style_spec="${2-}"; shift 2 ;;
                --default) use_default=1; shift ;;
                -h|--help)
                    printf '%s\n' \
                        "sgnd_ui_set_theme --palette <file|name> --style <file|name>" \
                        "sgnd_ui_set_theme --default"
                    return 0
                    ;;
                *)
                    # allow shorthand: sgnd_ui_set_theme palette style
                    if [[ -z "$palette_spec" ]]; then
                        palette_spec="$a"
                    elif [[ -z "$style_spec" ]]; then
                        style_spec="$a"
                    else
                        printf 'sgnd_ui_set_theme: unexpected argument: %s\n' "$a" >&2
                        return 2
                    fi
                    shift
                    ;;
            esac
        done

        if (( use_default )); then
            palette_spec="default-ui-palette"
            style_spec="00-style-default"
        fi

        # Theme root (where palettes/ and styles/ live)
        if [[ -z "${SGND_UI_THEME_DIR-}" ]]; then
            if [[ -n "${SGND_FRAMEWORK_ROOT-}" ]]; then
                SGND_UI_THEME_DIR="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/ui"
            else
                # fallback: relative to this file if possible
                SGND_UI_THEME_DIR=""
            fi
        fi

        # resolve palette/style -------------------------------------------------
        local palette_file
        local style_file

        palette_file="$(_sgnd_ui_resolve_theme_file "palettes" "$palette_spec")" || return $?
        style_file="$(_sgnd_ui_resolve_theme_file "styles"   "$style_spec")"   || return $?

        # load palette first, then style ---------------------------------------
        # shellcheck disable=SC1090
        source "$palette_file" || {
            printf 'sgnd_ui_set_theme: failed to load palette: %s\n' "$palette_file" >&2
            return 10
        }

        # Minimal sanity: palette should define RESET
        if [[ -z "${RESET-}" ]]; then
            printf 'sgnd_ui_set_theme: palette did not define RESET: %s\n' "$palette_file" >&2
            return 11
        fi

        # shellcheck disable=SC1090
        source "$style_file" || {
            printf 'sgnd_ui_set_theme: failed to load style: %s\n' "$style_file" >&2
            return 12
        }

        SGND_UI_PALETTE_FILE="$palette_file"
        SGND_UI_STYLE_FILE="$style_file"

        return 0
    }

    # fn: sgnd_theme - Display or switch the active UI theme
        # . Purpose
        #   Display the current theme or switch the semantic UI style used by the
        #   current SolidGroundUX session.
        #
        # . Behavior
        #   - With no theme argument, displays the currently configured theme.
        #   - Resolves a short theme name such as "dark" to its numbered style file.
        #   - Accepts an explicit numbered style filename such as "10-style-dark.sh".
        #   - Loads the selected style immediately through sgnd_load_ui_style.
        #   - With --save, stores SGND_UI_STYLE in the user framework cfg after the
        #     theme has loaded successfully.
        #   - Leaves the active theme unchanged when validation or loading fails.
        #
        # . Arguments
        #   THEME
        #       Optional theme name or style filename.
        #
        # . Options
        #   --save
        #       Save the selected theme in the user framework configuration.
        #
        #   -h, --help
        #       Display usage information.
        #
        # Outputs (globals):
        #   SGND_UI_STYLE
        #
        # . Output
        #   Displays the current theme when no theme is supplied.
        #   Reports validation, loading, or persistence failures to stderr.
        #
        # . Returns
        #   0 when the current theme is displayed or the requested theme is loaded.
        #   1 when the theme cannot be found, loaded, or saved.
        #   2 when invalid arguments are supplied.
        #
        # . Usage
        #   sgnd_theme
        #   sgnd_theme dark
        #   sgnd_theme fantasy --save
    sgnd_theme() {
        local theme=""
        local save=0
        local style_file=""
        local candidate=""
        local previous_style="${SGND_UI_STYLE:-00-style-default.sh}"

        while (($#)); do
            case "$1" in
                --save)
                    save=1
                    shift
                    ;;
                -h|--help)
                    printf '%s\n' \
                        "Usage: sgnd_theme [THEME] [--save]" \
                        "       sgnd_theme"
                    return 0
                    ;;
                --*)
                    printf 'sgnd_theme: unknown option: %s\n' "$1" >&2
                    return 2
                    ;;
                *)
                    if [[ -n "$theme" ]]; then
                        printf 'sgnd_theme: unexpected argument: %s\n' "$1" >&2
                        return 2
                    fi
                    theme="$1"
                    shift
                    ;;
            esac
        done

        if [[ -z "$theme" ]]; then
            theme="${SGND_UI_STYLE:-00-style-default.sh}"
            theme="${theme##*/}"
            theme="${theme%.sh}"
            if [[ "$theme" =~ ^[0-9][0-9]-style-(.+)$ ]]; then
                theme="${BASH_REMATCH[1]}"
            else
                theme="${theme#style-}"
                [[ "$theme" == "default-ui-style" ]] && theme="default"
            fi
            printf 'Current theme: %s\n' "$theme"
            return 0
        fi

        if [[ "$theme" == */* ]]; then
            candidate="$theme"
            [[ "$candidate" == *.sh ]] || candidate="${candidate}.sh"
            [[ -r "$candidate" ]] && style_file="$candidate"
        elif [[ "$theme" =~ ^[0-9][0-9]-style-.+\.sh$ ]]; then
            candidate="${SGND_STYLE_DIR%/}/${theme##*/}"
            [[ -r "$candidate" ]] && style_file="${theme##*/}"
        else
            theme="${theme##*/}"
            theme="${theme%.sh}"
            theme="${theme#style-}"
            [[ "$theme" == "default-ui-style" ]] && theme="default"
            while IFS= read -r candidate; do
                style_file="$candidate"
                break
            done < <(
                find "$SGND_STYLE_DIR" -maxdepth 1 -type f \
                    -name "[0-9][0-9]-style-${theme}.sh" \
                    -printf '%f\n' | LC_ALL=C sort
            )
        fi

        if [[ -z "$style_file" ]]; then
            printf 'sgnd_theme: theme not found: %s\n' "$theme" >&2
            return 1
        fi

        SGND_UI_STYLE="$style_file"
        if ! sgnd_load_ui_style; then
            SGND_UI_STYLE="$previous_style"
            sgnd_load_ui_style >/dev/null 2>&1 || true
            printf 'sgnd_theme: failed to load theme: %s\n' "$theme" >&2
            return 1
        fi

        if [[ -n "${SGND_FRAMEWORK_STATEFILE:-}" ]] && declare -F sgnd_state_set >/dev/null; then
            if ! sgnd_state_set --file "$SGND_FRAMEWORK_STATEFILE" SGND_UI_STYLE "$style_file"; then
                SGND_UI_STYLE="$previous_style"
                sgnd_load_ui_style >/dev/null 2>&1 || true
                printf 'sgnd_theme: failed to update framework state: %s\n' "$SGND_FRAMEWORK_STATEFILE" >&2
                return 1
            fi
        fi

        if (( save )); then
            if [[ -z "${SGND_FRAMEWORK_USRCFG_FILE:-}" ]] || ! declare -F _sgnd_kv_set >/dev/null; then
                SGND_UI_STYLE="$previous_style"
                sgnd_load_ui_style >/dev/null 2>&1 || true
                printf 'sgnd_theme: framework user configuration is unavailable\n' >&2
                return 1
            fi

            if ! _sgnd_kv_set "$SGND_FRAMEWORK_USRCFG_FILE" "SGND_UI_STYLE" "$style_file"; then
                SGND_UI_STYLE="$previous_style"
                sgnd_load_ui_style >/dev/null 2>&1 || true
                printf 'sgnd_theme: failed to save theme in: %s\n' "$SGND_FRAMEWORK_USRCFG_FILE" >&2
                return 1
            fi
        fi

        return 0
    }

    # fn: sgnd_ui_set_default_theme - Ui set default theme
        # . Purpose
        #   Load the default SolidGroundUX UI palette and style.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . Arguments
        #   $@ - Values consumed by the helper. See usage for the expected call shape.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_ui_set_default_theme "steelblue"
    sgnd_ui_set_default_theme() {
        sgnd_ui_set_theme --default
    }

 # -- Styling helpers -------------------------------------------------------------
    # fn: sgnd_sgr - Sgr
        # . Purpose
        #   Build an ANSI SGR escape sequence from numeric codes or existing SGR fragments.
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
        #   style="$(sgnd_sgr 97 44 1)"; printf '%bSolidGroundUX%b\n' "$style" "${RESET:-$'\e[0m'}"
    sgnd_sgr() {
        local -a parts=()
        local -a subparts=()
        local arg=""
        local inner=""
        local sub=""

        for arg in "$@"; do
            [[ -z "${arg:-}" ]] && continue

            # Numeric: treat as single SGR parameter
            if [[ "$arg" =~ ^[0-9]+$ ]]; then
                parts+=( "$arg" )
                continue
            fi

            # Numeric list: allow comma or semicolon separated params
            if [[ "$arg" =~ ^[0-9]+([,;][0-9]+)+$ ]]; then
                inner="${arg//,/;}"
                IFS=';' read -r -a subparts <<< "$inner"

                for sub in "${subparts[@]}"; do
                    [[ -n "$sub" ]] && parts+=( "$sub" )
                done
                continue
            fi

            # Escape: extract inner params from $'\e[...m'
            if [[ "$arg" == $'\e['*m ]]; then
                inner="${arg#$'\e['}"
                inner="${inner%m}"

                if [[ "$inner" =~ ^[0-9]+([;][0-9]+)*$ ]]; then
                    IFS=';' read -r -a subparts <<< "$inner"

                    for sub in "${subparts[@]}"; do
                        [[ -n "$sub" ]] && parts+=( "$sub" )
                    done
                fi
                continue
            fi
        done

        if (( ${#parts[@]} == 0 )); then
            printf '%s' "${RESET-}"
            return 0
        fi

        printf $'\e[%sm' "$(IFS=';'; echo "${parts[*]}")"
    }

    # fn: sgnd_fg - Fg
        # . Purpose
        #   Build a foreground-color SGR sequence.
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
        #   sgnd_fg "example"
    sgnd_fg() {  # fn: sgnd_fg <fg> [fx...]
        local fg="${1:-}"
        shift || true
        sgnd_sgr "$fg" "" "$@"
    }

    # fn: sgnd_bg - Bg
        # . Purpose
        #   Bg.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   sgnd_bg 24
    sgnd_bg() {  # fn: sgnd_bg <bg> [fx...]
        local bg="${1:-}"
        shift || true
        sgnd_sgr "" "$bg" "$@"
    }

 # -- Runmode indicators ----------------------------------------------------------
    # fn: sgnd_update_runmode - Update runmode
        # . Purpose
        #   Update runmode.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   sgnd_update_runmode
    sgnd_update_runmode() {
        if (( FLAG_DRYRUN )); then
            RUN_MODE="$(sgnd_runmode_color)DRYRUN${RESET}"
        else
            RUN_MODE="$(sgnd_runmode_color)COMMIT${RESET}"
        fi
    }

    # fn: sgnd_runmode_color - Runmode color
        # . Purpose
        #   Return the UI color associated with the current or supplied run mode.
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
        #   sgnd_runmode_color
    sgnd_runmode_color() {
        (( FLAG_DRYRUN )) && printf '%s' "$SGND_UI_DRYRUN" || printf '%s' "$SGND_UI_COMMIT"
    }

    # -- Rendering primitives --------------------------------------------------------
        # fn: sgnd_terminal_width - Return the current terminal width
        # . Purpose
        #   Return the number of columns available to console rendering.
        #
        # . Behavior
        #   - Uses tput cols against the controlling terminal when one is available.
        #   - Does not read from application stdin, which may contain piped data.
        #   - Falls back to tput cols on stdout when stdout is attached to a terminal.
        #   - Falls back to the COLUMNS environment variable.
        #   - Falls back to 80 when no terminal width is available.
        #
        # . Output
        #   Writes one positive integer to stdout.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   sgnd_terminal_width
    sgnd_terminal_width() {
        local width=""
        local tty_fd=""

        # Prefer the controlling terminal without consuming application stdin.
        if { exec {tty_fd}</dev/tty; } 2>/dev/null; then
            if command -v tput >/dev/null 2>&1; then
                width="$(tput cols <&"$tty_fd" 2>/dev/null || true)"
            fi

            exec {tty_fd}<&-
        fi

        # Fall back to stdout when it is attached to a terminal.
        if [[ ! "$width" =~ ^[1-9][0-9]*$ ]] \
            && [[ -t 1 ]] \
            && command -v tput >/dev/null 2>&1; then
            width="$(tput cols 2>/dev/null || true)"
        fi

        [[ "$width" =~ ^[1-9][0-9]*$ ]] || width="${COLUMNS:-}"
        [[ "$width" =~ ^[1-9][0-9]*$ ]] || width=80

        printf '%s\n' "$width"
    }

    # fn: sgnd_render_width - Resolve an effective console render width
        # . Purpose
        #   Resolve the width used by SolidGroundUX console rendering primitives.
        #
        # . Behavior
        #   - Measures the current terminal width whenever the function is called.
        #   - Uses an explicit requested width when supplied and smaller than the terminal.
        #   - Otherwise uses the full current terminal width.
        #   - Treats a requested width of 0 as the current terminal width.
        #   - Never exceeds the current terminal width.
        #
        # . Arguments
        #   $1  REQUESTED_WIDTH (optional)
        #       Requested render width.
        #       Empty or 0 uses the current terminal width.
        #
        # . Output
        #   Writes the resolved width to stdout.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   sgnd_render_width
        #   sgnd_render_width 120
    sgnd_render_width() {
        local requested="${1:-0}"
        local terminal_width

        terminal_width="$(sgnd_terminal_width)"

        # No explicit width, or an explicit width of 0, means:
        # use the full terminal width measured for this draw.
        [[ "$requested" =~ ^[0-9]+$ ]] || requested=0

        if (( requested > 0 && requested < terminal_width )); then
            printf '%s\n' "$requested"
        else
            printf '%s\n' "$terminal_width"
        fi
    }

    # fn: sgnd_print_labeledvalue - Print labeledvalue
        # . Purpose
        #   Print a formatted label/value row.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --label VALUE
        #   --value VALUE
        #   --sep VALUE
        #   --labelwidth VALUE
        #   --maxwidth VALUE
        #   --pad VALUE
        #   --labelclr VALUE
        #   --valueclr VALUE
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   labelwidth="$(printf '%s\n' "Hostname" "Primary IPv4" "SolidGround sudo" | awk '{ if (length > max) max = length } END { print max }')"
        #   sgnd_print_labeledvalue --label "Hostname" --value "$hostname" --labelwidth "$labelwidth"
        #   sgnd_print_labeledvalue --label "Primary IPv4" --value "$primary_ip" --labelwidth "$labelwidth"
        #   sgnd_print_labeledvalue --label "SolidGround sudo" --value "$sudo_state" --labelwidth "$labelwidth"
    sgnd_print_labeledvalue() {
        local label=""
        local value=""

        local sep=":"
        local labelwidth=25
        local maxwidth=""
        local pad=0
        local labelclr="${SGND_UI_LABEL}"
        local valueclr="${SGND_UI_VALUE}"

        # Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)
                    label="$2"
                    shift 2
                    ;;
                --value)
                    value="$2"
                    shift 2
                    ;;
                --sep)
                    sep="$2"
                    shift 2
                    ;;
                --labelwidth)
                    labelwidth="$2"
                    shift 2
                    ;;
                --maxwidth)
                    maxwidth="$2"
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
                --valueclr)
                    valueclr="$2"
                    shift 2
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    # Allow positional fallback: label value
                    if [[ -z "$label" ]]; then
                        label="$1"
                    elif [[ -z "$value" ]]; then
                        value="$1"
                    fi
                    shift
                    ;;
            esac
        done

        [[ -z "$label" ]] && return 0

        # Width / pad safety
        [[ "$labelwidth" =~ ^[0-9]+$ ]] || labelwidth=22
        [[ "$pad"   =~ ^[0-9]+$ ]] || pad=4
        maxwidth="$(sgnd_render_width "$maxwidth")"

        local valuewidth=$(( maxwidth - pad - labelwidth - ${#sep} - 2 ))
        (( valuewidth < 0 )) && valuewidth=0
        if (( $(sgnd_visible_len "$value") > valuewidth )); then
            value="${value:0:valuewidth}"
        fi

        printf '%*s%s %s %s\n' \
            "$pad" "" \
            "${labelclr}$(printf "%-*.*s" "$labelwidth" "$labelwidth" "$label")${RESET}" \
            "$sep" \
            "${valueclr}${value}${RESET}"
    }

    # fn: sgnd_print_labeledmultivalue
        # . Purpose
        #   Print one label followed by a value that may span multiple aligned lines.
        #
        # . Behavior
        #   - Renders the label and separator only on the first output line.
        #   - Aligns continuation lines with the first value column.
        #   - Accepts either one large value or an array of discrete items.
        #   - Starts every supplied item on a new value line.
        #   - Wraps long values and items to the requested or available value width.
        #   - Applies the configured label and value colors to every rendered line.
        #
        # . options
        #   --label VALUE
        #       Label rendered on the first line.
        #   --value VALUE
        #       One value that may contain long text or embedded newlines.
        #   --items ITEM...
        #       Remaining arguments are treated as individual values. This option must
        #       be the final option in the call.
        #   --valuewidth WIDTH
        #       Maximum visible width of the value column. Defaults to the available
        #       width after padding, label, and separator are accounted for.
        #   --sep VALUE
        #       Separator between label and first value. Defaults to a colon.
        #   --labelwidth WIDTH
        #       Visible width reserved for the label. Defaults to 25.
        #   --maxwidth WIDTH
        #       Maximum total render width.
        #   --pad COUNT
        #       Number of spaces before the label. Defaults to 0.
        #   --labelclr ANSI
        #       ANSI sequence used for the label.
        #   --valueclr ANSI
        #       ANSI sequence used for the value lines.
        #
        # . Output
        #   Writes one or more aligned labeled-value lines to stdout.
        #
        # . Returns
        #   0 after rendering.
        #   2 when no label is supplied or a numeric option is invalid.
        #
        # . Usage
        #   labelwidth="$(printf '%s\n' "Changed files" "Warnings" "Description" | awk '{ if (length > max) max = length } END { print max }')"
        #   sgnd_print_labeledmultivalue \
        #       --label "Changed files" \
        #       --labelwidth "$labelwidth" \
        #       --items "file-one.sh" "file-two.sh"
        #
        #   sgnd_print_labeledmultivalue \
        #       --label "Description" \
        #       --labelwidth "$labelwidth" \
        #       --value "$description" \
        #       --valuewidth 60
    sgnd_print_labeledmultivalue() {
        local label=""
        local value=""
        local sep=":"
        local labelwidth=25
        local valuewidth=""
        local maxwidth=""
        local pad=0
        local labelclr="${SGND_UI_LABEL}"
        local valueclr="${SGND_UI_VALUE}"
        local input_mode="value"
        local -a items=()

        local available_width=0
        local continuation_width=0
        local continuation_prefix=""
        local item=""
        local raw_line=""
        local wrapped_line=""
        local first_output=1
        local emitted=0

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --label)      label="$2"; shift 2 ;;
                --value)      value="$2"; input_mode="value"; shift 2 ;;
                --items)
                    shift
                    items=("$@")
                    input_mode="items"
                    break
                    ;;
                --valuewidth) valuewidth="$2"; shift 2 ;;
                --sep)        sep="$2"; shift 2 ;;
                --labelwidth) labelwidth="$2"; shift 2 ;;
                --maxwidth)   maxwidth="$2"; shift 2 ;;
                --pad)        pad="$2"; shift 2 ;;
                --labelclr)   labelclr="$2"; shift 2 ;;
                --valueclr)   valueclr="$2"; shift 2 ;;
                --)           shift; break ;;
                *)
                    if [[ -z "$label" ]]; then
                        label="$1"
                    elif [[ -z "$value" ]]; then
                        value="$1"
                    fi
                    shift
                    ;;
            esac
        done

        [[ -n "$label" ]] || return 2
        [[ "$labelwidth" =~ ^[0-9]+$ ]] || return 2
        [[ "$pad" =~ ^[0-9]+$ ]] || return 2
        [[ -z "$valuewidth" || "$valuewidth" =~ ^[1-9][0-9]*$ ]] || return 2

        maxwidth="$(sgnd_render_width "$maxwidth")"
        continuation_width=$(( pad + labelwidth + 1 + ${#sep} + 1 ))
        available_width=$(( maxwidth - continuation_width ))
        (( available_width < 1 )) && available_width=1

        if [[ -z "$valuewidth" ]] || (( valuewidth > available_width )); then
            valuewidth="$available_width"
        fi

        printf -v continuation_prefix '%*s' "$continuation_width" ''

        _sgnd_labeledmultivalue_emit() {
            local line="$1"

            if (( first_output )); then
                printf '%*s%s %s %s%s%s\n' \
                    "$pad" "" \
                    "${labelclr}$(printf "%-*.*s" "$labelwidth" "$labelwidth" "$label")${RESET}" \
                    "$sep" \
                    "$valueclr" "$line" "$RESET"
                first_output=0
            else
                printf '%s%s%s%s\n' \
                    "$continuation_prefix" \
                    "$valueclr" "$line" "$RESET"
            fi
            emitted=1
        }

        if [[ "$input_mode" == "items" ]]; then
            for item in "${items[@]}"; do
                if [[ -z "$item" ]]; then
                    _sgnd_labeledmultivalue_emit ""
                    continue
                fi

                while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
                    if [[ -z "$raw_line" ]]; then
                        _sgnd_labeledmultivalue_emit ""
                        continue
                    fi

                    while IFS= read -r wrapped_line || [[ -n "$wrapped_line" ]]; do
                        _sgnd_labeledmultivalue_emit "$wrapped_line"
                    done < <(sgnd_wrap_words --width "$valuewidth" --text "$raw_line")
                done < <(printf '%s' "$item")
            done
        else
            while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
                if [[ -z "$raw_line" ]]; then
                    _sgnd_labeledmultivalue_emit ""
                    continue
                fi

                while IFS= read -r wrapped_line || [[ -n "$wrapped_line" ]]; do
                    _sgnd_labeledmultivalue_emit "$wrapped_line"
                done < <(sgnd_wrap_words --width "$valuewidth" --text "$raw_line")
            done < <(printf '%s' "$value")
        fi

        (( emitted )) || _sgnd_labeledmultivalue_emit ""
        unset -f _sgnd_labeledmultivalue_emit
        return 0
    }

    # fn: sgnd_print_fill - Print fill
        # . Purpose
        #   Print a left/right line filled to a target width.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #   - Uses the current terminal width when --maxwidth is omitted.
        #
        # . options
        #   --left VALUE
        #   --right VALUE
        #   --padleft VALUE
        #   --padright VALUE
        #   --maxwidth VALUE
        #   --fillchar VALUE
        #   --leftclr VALUE
        #   --rightclr VALUE
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_print_fill "example" "example-2"
    sgnd_print_fill() {
        local left="" right=""
        local padleft=2 padright=1 maxwidth=""
        local fillchar=" "
        local leftclr="${SGND_UI_TEXT}"
        local rightclr=""

        # Parse options (with positional fallback)
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --left)     left="$2"; shift 2 ;;
                --right)    right="$2"; shift 2 ;;
                --padleft)  padleft="$2"; shift 2 ;;
                --padright) padright="$2"; shift 2 ;;
                --maxwidth) maxwidth="$2"; shift 2 ;;
                --fillchar) fillchar="$2"; shift 2 ;;
                --leftclr)  leftclr="$2"; shift 2 ;;
                --rightclr) rightclr="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    if [[ -z "$left" ]]; then
                        left="$1"
                    elif [[ -z "$right" ]]; then
                        right="$1"
                    fi
                    shift
                    ;;
            esac
        done

        # Defaults / safety
        [[ "$padleft"  =~ ^[0-9]+$ ]] || padleft=2
        [[ "$padright" =~ ^[0-9]+$ ]] || padright=1
        maxwidth="$(sgnd_render_width "$maxwidth")"

        # right color inherits left color
        [[ -z "$rightclr" ]] && rightclr="$leftclr"

        # fillchar: single visible char only
        [[ -n "$fillchar" ]] || fillchar=" "
        fillchar="${fillchar:0:1}"

        local fill=$(( maxwidth
                - padleft
                - $(sgnd_visible_len "$left")
                - $(sgnd_visible_len "$right")
                - padright ))

        (( fill < 0 )) && fill=0

        # Render (colors applied last)
        printf '%s%s%s%s%s%s\n' \
            "$(sgnd_string_repeat "$fillchar" "$padleft")" \
            "${leftclr}${left}${RESET}" \
            "$(sgnd_string_repeat "$fillchar" "$fill")" \
            "$(sgnd_string_repeat "$fillchar" "$padright")" \
            "${rightclr}${right}${RESET}" \
            ""
    }

    # fn: sgnd_print_titlebar - Print titlebar
        # . Purpose
        #   Print the standard SolidGroundUX title bar.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --left VALUE
        #   --leftclr VALUE
        #   --right VALUE
        #   --rightclr VALUE
        #   --sub VALUE
        #   --subclr VALUE
        #   --subjust VALUE
        #   --border VALUE
        #   --borderclr VALUE
        #   --padleft VALUE
        #   --maxwidth VALUE
        #
        # Outputs (globals):
        #   Updates SolidGroundUX UI/runtime globals documented by the function body.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_print_titlebar "example" "example-2"
    sgnd_print_titlebar() {

        local left="${SGND_SCRIPT_TITLE:-$SGND_SCRIPT_BASE}"
        local right="${RUN_MODE:-}"

        if [[ -n "${SGND_SCRIPT_VERSION:-}" && -n "${SGND_SCRIPT_BUILD:-}" ]]; then
            left+=" (v. ${SGND_SCRIPT_VERSION}.${SGND_SCRIPT_BUILD})"
        elif [[ -n "${SGND_SCRIPT_VERSION:-}" ]]; then
            left+=" (v. ${SGND_SCRIPT_VERSION})"
        fi
        if [[ "${SGND_FRAMEWORK_ROOT:-/}" != "/" ]]; then
            left+=" ${MSG_CLR_WARN}NON-ROOT${RESET}"
        fi
        
        local leftclr="${SGND_TITLE_TEXTCLR:-$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")}"
        local rightclr="${SGND_TITLE_RIGHTCLR:-${SGND_TITLE_TEXTCLR:-$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")}}"
        local sub="${SGND_SCRIPT_DESC:-""}"
        local subclr="${SGND_TITLE_SUBTEXTCLR:-$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_ITALIC")}"
        local subjust="C"
        local border="${SGND_TITLE_BORDER:-$DL_H}"
        local borderclr="${SGND_TITLE_BORDERCLR:-$SGND_UI_BORDER}"
        local padleft=4
        local maxwidth=""

        # Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --left)      left="$2"; shift 2 ;;
                --leftclr)   leftclr="$2"; shift 2 ;;
                --right)     right="$2"; shift 2 ;;
                --rightclr)  rightclr="$2"; shift 2 ;;
                --sub)       sub="$2"; shift 2 ;;
                --subclr)    subclr="$2"; shift 2 ;;
                --subjust)   subjust="$2"; shift 2 ;;
                --border)    border="$2"; shift 2 ;;
                --borderclr) borderclr="$2"; shift 2 ;;
                --padleft)   padleft="$2"; shift 2 ;;
                --maxwidth)  maxwidth="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    [[ -z "$left" ]] && left="$1"
                    shift
                    ;;
            esac
        done

        # Numeric safety
        [[ "$padleft"  =~ ^[0-9]+$ ]] || padleft=4
        maxwidth="$(sgnd_render_width "$maxwidth")"
        (( padleft < 0 )) && padleft=0

        sgnd_print
        sgnd_print_sectionheader \
            --border "$border" \
            --borderclr "$borderclr" \
            --maxwidth "$maxwidth"

        sgnd_print_fill \
            --left "$left" \
            --right "$right" \
            --padleft "$padleft" \
            --maxwidth "$maxwidth" \
            --leftclr "$leftclr" \
            --rightclr "$rightclr"

        if [[ "${sub}" != "" ]]; then
           sgnd_print \
            --text "$sub" \
            --justify "$subjust" \
            --textclr "$subclr" \
            --rightmargin "$(sgnd_visible_len "$right")" \
            --maxwidth "$maxwidth"
        fi

        sgnd_print_sectionheader \
            --border "$border" \
            --borderclr "$borderclr" \
            --maxwidth "$maxwidth"
    }

    # fn: sgnd_print_sectionheader - Print sectionheader
        # . Purpose
        #   Print a section header or horizontal border line.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --text VALUE
        #   --textclr VALUE
        #   --border VALUE
        #   --borderclr VALUE
        #   --padleft VALUE
        #   --padend VALUE
        #   --maxwidth VALUE
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_print_sectionheader "example" "example-2"
    sgnd_print_sectionheader() {
        local text=""
        local textclr="${SGND_SECTION_TEXTCLR:-$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")}"
        local border="${SGND_SECTION_BORDER:-$LN_H}"
        local borderclr="${SGND_SECTION_BORDERCLR:-$SGND_UI_BORDER}"
        local padleft=4
        local padend=1
        local maxwidth=""
   
        # Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --text)      text="$2"; shift 2 ;;
                --textclr)   textclr="$2"; shift 2 ;;
                --border)    border="$2"; shift 2 ;;
                --borderclr) borderclr="$2"; shift 2 ;;
                --padleft)   padleft="$2"; shift 2 ;;
                --padend)    padend="$2"; shift 2 ;;
                --maxwidth)  maxwidth="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    # positional fallback
                    [[ -z "$text" ]] && text="$1"
                    shift
                    ;;
            esac
        done

        # Numeric safety
        [[ "$padleft"  =~ ^[0-9]+$ ]] || padleft=4
        [[ "$padend"   =~ ^(0|1)$   ]] || padend=1
        maxwidth="$(sgnd_render_width "$maxwidth")"
        (( padleft < 0 )) && padleft=0

        # Assemble line (PLAIN parts first; add color last)
        local left_plain="" mid_plain="" right_plain="" fnl=""
        local remaining=0

        # If no text: full-width border line
        if [[ -z "$text" ]]; then
            fnl="${borderclr}$(sgnd_string_repeat "$border" "$maxwidth")${RESET}"
            printf '%s\n' "$fnl"
            return 0
        fi

        # Left: "---- " (padleft times border + a space)
        if [[ -n "$border" && $padleft -gt 0 ]]; then
            left_plain="$(sgnd_string_repeat "$border" "$padleft") "
        fi

        # Middle: "Text"
        mid_plain="$(sgnd_strip_ansi "$text")"

        if (( padend )); then
            # Use the same visible-width calculation as sgnd_print_fill so section
            # headers terminate at exactly the same render edge as titlebar rows.
            local spent=0
            spent=$(( $(sgnd_visible_len "$left_plain")
                    + $(sgnd_visible_len "$text")
                    + 1 ))   # space before right fill

            remaining=$(( maxwidth - spent ))
            (( remaining < 0 )) && remaining=0

            if [[ -n "$border" && $remaining -gt 0 ]]; then
                right_plain="$(sgnd_string_repeat "$border" "$remaining")"
            fi

            if [[ -n "$right_plain" ]]; then
                fnl="${borderclr}${left_plain}${RESET}${textclr}${text}${RESET} ${borderclr}${right_plain}${RESET}"
            else
                fnl="${borderclr}${left_plain}${RESET}${textclr}${text}${RESET}"
            fi
        else
            fnl="${borderclr}${left_plain}${textclr}${text}${RESET}"
        fi

        printf '%s\n' "$fnl"
    }

    # fn: sgnd_print - Print
        # . Purpose
        #   Print styled, optionally padded, wrapped, or justified text.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #   - Automatically wraps text when its visible width exceeds the available width.
        #   - --wrap 1 forces wrapping; --wrap 0 disables wrapping.
        #   - Ignores ANSI escape sequences when measuring text for wrapping and justification.
        #
        # . options
        #   --text VALUE
        #   --textclr VALUE
        #   --justify VALUE
        #   --wrap VALUE
        #   --pad VALUE
        #   --rightmargin VALUE
        #   --maxwidth VALUE
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_print "example" "example-2"
    sgnd_print() {
        local text=""
        local textclr="${SGND_UI_TEXT:-}"
        local wrap=0
        local wrap_explicit=0
        local pad=0
        local rightmargin=0
        local justify="L"   # L = left, C = center, R = right
        local maxwidth=""

        # Parse options --------------------------------------------------------
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --text)         text="$2"; shift 2 ;;
                --textclr)      textclr="$2"; shift 2 ;;
                --justify)      justify="${2^^}"; shift 2 ;;
                --wrap)         wrap="$2"; wrap_explicit=1; shift 2 ;;
                --pad)          pad="$2"; shift 2 ;;
                --rightmargin)  rightmargin="$2"; shift 2 ;;
                --maxwidth)     maxwidth="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    [[ -z "$text" ]] && text="$1"
                    shift
                    ;;
            esac
        done

        # Empty call => newline
        if [[ -z "$text" ]]; then
            sgnd_print_single
            return 0
        fi

        # Safety defaults ------------------------------------------------------
        (( pad < 0 )) && pad=0
        (( rightmargin < 0 )) && rightmargin=0
        maxwidth="$(sgnd_render_width "$maxwidth")"

        # Available width for auto-wrap decision -------------------------------
        local avail=$(( maxwidth - (pad * 2) - rightmargin ))
        (( avail < 1 )) && avail=1

        # Auto-wrap if not explicitly specified --------------------------------
        # Use visible width so embedded ANSI styling does not influence layout.
        if (( ! wrap_explicit )); then
            (( $(sgnd_visible_len "$text") > avail )) && wrap=1 || wrap=0
        fi

        # Render ---------------------------------------------------------------
        if (( wrap )); then
            local mw_eff=$(( maxwidth - rightmargin ))
            (( mw_eff < 1 )) && mw_eff=1

            while IFS= read -r line; do
                sgnd_print_single \
                    --text "$line" \
                    --textclr "$textclr" \
                    --pad "$pad" \
                    --justify "$justify" \
                    --maxwidth "$mw_eff"
            done < <(sgnd_wrap_words --width "$avail" --text "$text")
        else
            sgnd_print_single \
                --text "$text" \
                --textclr "$textclr" \
                --pad "$pad" \
                --justify "$justify" \
                --maxwidth "$maxwidth"
        fi
    }

    # fn: sgnd_print_single - Print single
        # . Purpose
        #   Print a single styled line without wrapping.
        #
        # . Behavior
        #   - Preserves the existing SolidGroundUX console/UI behavior.
        #   - Uses current palette, style, runtime, or logging globals where applicable.
        #
        # . options
        #   --text VALUE
        #   --textclr VALUE
        #   --justify VALUE
        #   --pad VALUE
        #   --maxwidth VALUE
        #
        # . Output
        #   Writes formatted text or computed values to stdout unless the function targets /dev/tty.
        #
        # . Returns
        #   0 on success.
        #   Non-zero when validation, resolution, I/O, or user cancellation fails.
        #
        # . Usage
        #   sgnd_print_single "example" "example-2"
    sgnd_print_single() {
        local text=""
        local textclr="${SGND_UI_TEXT:-}"
        local pad=0
        local justify="L"
        local maxwidth=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --text)      text="$2"; shift 2 ;;
                --textclr)   textclr="$2"; shift 2 ;;
                --justify)   justify="${2^^}"; shift 2 ;;
                --pad)       pad="$2"; shift 2 ;;
                --maxwidth)  maxwidth="$2"; shift 2 ;;
                --) shift; break ;;
                *)
                    [[ -z "$text" ]] && text="$1"
                    shift
                    ;;
            esac
        done

        if [[ -z "$text" ]]; then
            printf "\n"
            return 0
        fi

        (( pad < 0 )) && pad=0
        maxwidth="$(sgnd_render_width "$maxwidth")"

        local textlen=0
        local plain_text=""

        local avail=$(( maxwidth - (pad * 2) ))
        (( avail < 1 )) && avail=1

        textlen="$(sgnd_visible_len "$text")"

        # Avoid splitting an ANSI escape sequence when truncation is required.
        if (( textlen > avail )); then
            plain_text="$(sgnd_strip_ansi "$text")"
            text="${plain_text:0:avail}"
            textlen="${#text}"
        fi

        local leftspace=0 rightspace=0
        case "$justify" in
            C)
                leftspace=$(( (avail - textlen) / 2 ))
                rightspace=$(( avail - textlen - leftspace ))
                ;;
            R)
                leftspace=$(( avail - textlen ))
                ;;
            *)
                rightspace=$(( avail - textlen ))
                ;;
        esac

        (( leftspace < 0 )) && leftspace=0
        (( rightspace < 0 )) && rightspace=0

        local line=""
        line+="$(printf '%*s' "$pad" "")"
        line+="$(printf '%*s' "$leftspace" "")"
        line+="$text"
        line+="$(printf '%*s' "$rightspace" "")"
        line+="$(printf '%*s' "$pad" "")"

        printf "%b\n" "${textclr}${line}${RESET}"
    }

    # fn: sgnd_print_file - Print file
        # . Purpose
        #   Print the contents of a file using sgnd_print formatting.
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
        #   sgnd_print_file "/tmp/sgnd-example.txt"
    sgnd_print_file() {
        local file="$1"
        
        [[ -n "${file:-}" ]] || { printf "ERROR: sgnd_print_file: missing file\n" >&2; return 2; }
        [[ -r "$file" ]]      || { printf "ERROR: sgnd_print_file: not readable: %s\n" "$file" >&2; return 2; }

        
        local ext="${file##*.}"
        local is_tty=0
        [[ -t 1 ]] && is_tty=1

        # Pager (only if interactive)
        local pager_cmd=()
        if (( is_tty )); then
            if command -v less >/dev/null 2>&1; then
                pager_cmd=( less -FRSX )
            fi
        fi

        # Markdown render if possible
        if [[ "${ext,,}" == "md" ]]; then
            if command -v glow >/dev/null 2>&1; then
                # glow pages itself; use -p for pager mode
                glow -p "$file"
                return $?
            fi

            if command -v mdcat >/dev/null 2>&1; then
                if (( is_tty )) && ((${#pager_cmd[@]})); then
                    mdcat "$file" | "${pager_cmd[@]}"
                else
                    mdcat "$file"
                fi
                return $?
            fi

            if command -v bat >/dev/null 2>&1; then
                # bat handles paging/highlighting nicely
                bat --language=md --style=plain --paging=auto "$file"
                return $?
            fi

            if command -v pandoc >/dev/null 2>&1; then
                # Render to plain text
                if (( is_tty )) && ((${#pager_cmd[@]})); then
                    pandoc -t plain "$file" | "${pager_cmd[@]}"
                else
                    pandoc -t plain "$file"
                fi
                return $?
            fi
        fi

        # Plain text fallback
        if (( is_tty )) && ((${#pager_cmd[@]})); then
            "${pager_cmd[@]}" "$file"
        else
            cat -- "$file"
        fi
    }
    
    # fn: sgnd_print_cell - Print cell
        # . Purpose
        #   Print a fixed-width styled cell without a trailing newline.
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
        #   sgnd_print_cell 20 "example-2"
    sgnd_print_cell() {
        local width="$1"
        local s="$2"

        # Strip ANSI CSI sequences for visible length calculation
        local plain
        plain="$(printf '%s' "$s" | sed -E $'s/\x1B\\[[0-9;]*[[:alpha:]]//g')"

        local vislen="${#plain}"
        local pad=$(( width - vislen ))
        (( pad < 0 )) && pad=0

        printf '%s%*s' "$s" "$pad" ""
    }

    # fn: sgnd_module_show_metadata - Module show metadata
        # . Purpose
        #   Print the metadata registered for the current module or script.
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
        #   sgnd_module_show_metadata "example"
    sgnd_module_show_metadata() {
        local module_ref="${1:?missing module prefix or file}"
        local prefix=""
        local file=""
        local base=""
        local key=""
        local var_name=""

        local v_file=""
        local v_dir=""
        local v_base=""
        local v_name=""
        local v_product=""
        local v_title=""
        local v_desc=""
        local v_version=""
        local v_build=""
        local v_checksum=""
        local v_source=""
        local v_type=""
        local v_purpose=""
        local v_developers=""
        local v_company=""
        local v_client=""
        local v_copyright=""
        local v_license=""

        # Resolve module prefix ----------------------------------------------------
        if [[ "$module_ref" == SGND_* ]]; then
            prefix="$module_ref"
        else
            file="$(readlink -f "$module_ref")" || return 1
            base="$(basename -- "$file")"
            key="${base%.sh}"
            key="${key//-/_}"
            prefix="SGND_${key^^}"
        fi

        # Resolve variables --------------------------------------------------------
        var_name="${prefix}_FILE";       v_file="${!var_name-}"
        var_name="${prefix}_DIR";        v_dir="${!var_name-}"
        var_name="${prefix}_BASE";       v_base="${!var_name-}"
        var_name="${prefix}_NAME";       v_name="${!var_name-}"
        var_name="${prefix}_PRODUCT";    v_product="${!var_name-}"
        var_name="${prefix}_TITLE";      v_title="${!var_name-}"
        var_name="${prefix}_DESC";       v_desc="${!var_name-}"
        var_name="${prefix}_VERSION";    v_version="${!var_name-}"
        var_name="${prefix}_BUILD";      v_build="${!var_name-}"
        var_name="${prefix}_CHECKSUM";   v_checksum="${!var_name-}"
        var_name="${prefix}_SOURCE";     v_source="${!var_name-}"
        var_name="${prefix}_TYPE";       v_type="${!var_name-}"
        var_name="${prefix}_PURPOSE";    v_purpose="${!var_name-}"
        var_name="${prefix}_DEVELOPERS"; v_developers="${!var_name-}"
        var_name="${prefix}_COMPANY";    v_company="${!var_name-}"
        var_name="${prefix}_CLIENT";     v_client="${!var_name-}"
        var_name="${prefix}_COPYRIGHT";  v_copyright="${!var_name-}"
        var_name="${prefix}_LICENSE";    v_license="${!var_name-}"

        # Output -------------------------------------------------------------------
        sgnd_print_labeled_value "Module"      "$prefix"
        sgnd_print_labeled_value "File"        "$v_file"
        sgnd_print_labeled_value "Directory"   "$v_dir"
        sgnd_print_labeled_value "Base"        "$v_base"
        sgnd_print_labeled_value "Name"        "$v_name"
        sgnd_print_labeled_value "Product"     "$v_product"
        sgnd_print_labeled_value "Title"       "$v_title"
        sgnd_print_labeled_value "Version"     "$v_version"
        sgnd_print_labeled_value "Build"       "$v_build"
        sgnd_print_labeled_value "Checksum"    "$v_checksum"
        sgnd_print_labeled_value "Source"      "$v_source"
        sgnd_print_labeled_value "Type"        "$v_type"
        sgnd_print_labeled_value "Purpose"     "$v_purpose"
        sgnd_print_labeled_value "Developers"  "$v_developers"
        sgnd_print_labeled_value "Company"     "$v_company"
        sgnd_print_labeled_value "Client"      "$v_client"
        sgnd_print_labeled_value "Copyright"   "$v_copyright"
        sgnd_print_labeled_value "License"     "$v_license"

        if [[ -n "$v_desc" ]]; then
            printf '\nDescription:\n%s\n' "$v_desc"
        fi

        return 0
    }

    # fn: sgnd_clear - Clear the visible terminal display
        #     . Purpose
        #       Clear the visible terminal display and move the cursor to the home position.
        #
        #     . Behavior
        #       - Uses explicit ANSI escape sequences instead of the external clear command.
        #       - Clears only the visible display.
        #       - Leaves the terminal scrollback buffer unchanged.
        #       - Moves the cursor to row 1, column 1.
        #
        #     . Output
        #       Writes terminal control sequences to stdout.
        #
        #     . Returns
        #       0 always.
        #
        #     . Usage
        #       sgnd_clear
    sgnd_clear() {
        #printf '\033[H\033[2J\033[3J'
        printf '\033[H\033[2J'
    }
 # -- Externals -------------------------------------------------------------------
 # -- Sample/demo renderers -------------------------------------------------------
    # fn: sgnd_color_samples - Color samples
        # . Purpose
        #   Print sample output for the currently loaded color palette.
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
        #   sgnd_color_samples
    sgnd_color_samples(){
        printf '\n%s\n\n' "---- Available foreground colors & effects in SolidGroundUX ----"

        sgnd_sample_row	BLUE	BRIGHT_BLUE	    DARK_BLUE	    BG_BLUE	    BG_DARK_BLUE
        sgnd_sample_row	BROWN	BRIGHT_BROWN	DARK_BROWN      BG_BROWN	BG_DARK_BROWN
        sgnd_sample_row	CYAN	BRIGHT_CYAN	    DARK_CYAN	    BG_CYAN	    BG_DARK_CYAN
        sgnd_sample_row	GOLD	BRIGHT_GOLD	    DARK_GOLD	    BG_GOLD	    BG_DARK_GOLD
        sgnd_sample_row	GREEN	BRIGHT_GREEN	DARK_GREEN	    BG_GREEN	BG_DARK_GREEN
        sgnd_sample_row	MAGENTA	BRIGHT_MAGENTA	DARK_MAGENTA	BG_MAGENTA	BG_DARK_MAGENTA
        sgnd_sample_row	ORANGE	BRIGHT_ORANGE	DARK_ORANGE	    BG_ORANGE	BG_DARK_ORANGE
        sgnd_sample_row	PINK	BRIGHT_PINK	    DARK_PINK	    BG_PINK	    BG_DARK_PINK
        sgnd_sample_row	PURPLE	BRIGHT_PURPLE	DARK_PURPLE	    BG_PURPLE	BG_DARK_PURPLE
        sgnd_sample_row	RED	    BRIGHT_RED	    DARK_RED	    BG_RED	    BG_DARK_RED
        sgnd_sample_row	TEAL	BRIGHT_TEAL	    DARK_TEAL	    BG_TEAL	    BG_DARK_TEAL
        sgnd_sample_row	WHITE	BRIGHT_WHITE	DARK_WHITE	    BG_WHITE	BG_DARK_WHITE
        sgnd_sample_row	YELLOW	BRIGHT_YELLOW	DARK_YELLOW	    BG_YELLOW	BG_DARK_YELLOW

    }

    # fn: sgnd_sample_row - Sample row
        # . Purpose
        #   Print one sample row for the style sample output.
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
        #   sgnd_sample_row "Status" "Operational"
    sgnd_sample_row(){
        local clr name val

        for clr in "$@"; do
            eval "val=\${$clr}"

            sgnd_print_cell 20 "$val$clr$RESET"

            # Bold
            printf "%sBOLD%s\t" \
                "$(sgnd_sgr "$val" "" "$FX_BOLD")" \
                "$RESET"

            # Faint / Dim
            printf "%sFAINT%s\t" \
                "$(sgnd_sgr "$val" "" "$FX_FAINT")" \
                "$RESET"

            # Italic
            printf "%sITALIC%s\t" \
                "$(sgnd_sgr "$val" "" "$FX_ITALIC")" \
                "$RESET"

            # Underline
            printf "%sUNDER%s\t" \
                "$(sgnd_sgr "$val" "" "$FX_UNDERLINE")" \
                "$RESET"

            # Reverse
            printf "%sREVERSE%s\t" \
                "$(sgnd_sgr "$val" "" "$FX_REVERSE")" \
                "$RESET"

            # Strikethrough
            printf "%sSTRIKE%s\t" \
                "$(sgnd_sgr "$val" "" "$FX_STRIKE")" \
                "$RESET"

            printf "\n"    
        done

        printf "\n"
    }

    # fn$: _sgnd_style_color_description - Resolve a semantic color to a palette name or RGB value
        # . Purpose
        #   Return a readable description for an already resolved ANSI color value.
        #
        # . Behavior
        #   - Prefers a matching named foreground palette variable when available.
        #   - Falls back to #RRGGBB for 24-bit foreground colors.
        #   - Falls back to xterm-N for indexed foreground colors.
        #   - Returns "custom" when the value cannot be recognized.
        #
        # . Arguments
        #   $1  COLOR_VALUE - Resolved ANSI foreground color sequence.
        #
        # . Output
        #   Writes the palette name, RGB hex value, indexed color, or "custom".
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   color_name="$(_sgnd_style_color_description "$SGND_UI_BORDER")"
    _sgnd_style_color_description() {
        local color_value="${1:-}"
        local palette_name=""
        local palette_value=""
        local params=""
        local r=""
        local g=""
        local b=""
        local index=""
        local -a palette_names=(
            BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE GRAY ORANGE SILVER PURPLE TEAL PINK GOLD BROWN
            DARK_RED DARK_GREEN DARK_YELLOW DARK_BLUE DARK_MAGENTA DARK_CYAN DARK_WHITE DARK_GRAY
            DARK_ORANGE DARK_SILVER DARK_PURPLE DARK_TEAL DARK_PINK DARK_GOLD DARK_BROWN
            BRIGHT_RED BRIGHT_GREEN BRIGHT_YELLOW BRIGHT_BLUE BRIGHT_MAGENTA BRIGHT_CYAN BRIGHT_WHITE
            BRIGHT_ORANGE BRIGHT_PURPLE BRIGHT_TEAL BRIGHT_PINK BRIGHT_GOLD BRIGHT_BROWN
            TD_MAROON TD_DARK_MAROON TD_GOLD TD_DARK_GOLD TD_SILVER TD_DARK_SILVER TD_WHITE
            SGND_BLUE SGND_DARK_BLUE SGND_GREEN SGND_DARK_GREEN SGND_RED SGND_DARK_RED SGND_GOLD SGND_DARK_GOLD
        )

        for palette_name in "${palette_names[@]}"; do
            [[ -v "$palette_name" ]] || continue
            palette_value="${!palette_name}"

            if [[ "$palette_value" == "$color_value" ]]; then
                printf '%s\n' "$palette_name"
                return 0
            fi
        done

        if [[ "$color_value" == $'\e['*m ]]; then
            params="${color_value#$'\e['}"
            params="${params%m}"

            if [[ "$params" =~ (^|;)38\;2\;([0-9]+)\;([0-9]+)\;([0-9]+)($|;) ]]; then
                r="${BASH_REMATCH[2]}"
                g="${BASH_REMATCH[3]}"
                b="${BASH_REMATCH[4]}"
                printf '#%02X%02X%02X\n' "$r" "$g" "$b"
                return 0
            fi

            if [[ "$params" =~ (^|;)38\;5\;([0-9]+)($|;) ]]; then
                index="${BASH_REMATCH[2]}"
                printf 'xterm-%s\n' "$index"
                return 0
            fi
        fi

        printf 'custom\n'
        return 0
    }

    # fn: sgnd_style_samples - Display the active UI theme
        # . Purpose
        #   Demonstrate the active SolidGroundUX theme and the rendering primitives
        #   used by framework console applications.
        #
        # . Behavior
        #   - Shows the current theme name through sgnd_print_titlebar.
        #   - Renders every message label directly through sgnd_print using its
        #     corresponding MSG_CLR_* semantic color.
        #   - Demonstrates the principal sgnd_print* rendering primitives by name.
        #   - Includes a non-interactive simulation of ask prompt/input styling.
        #   - Preserves the run-mode and validation/state specimens.
        #   - Shows message, progress, and UI semantic colors with their resolved
        #     palette name or RGB/indexed fallback.
        #
        # . Output
        #   Writes a visual theme and rendering showcase to the terminal.
        #
        # . Returns
        #   0 on success.
        #
        # . Usage
        #   sgnd_style_samples
    sgnd_style_samples() {
        local current_theme="${SGND_UI_STYLE##*/}"
        local message_type=""
        local label_var=""
        local color_var=""
        local label_value=""
        local color_value=""
        local color_description=""
        local group_spec=""
        local group_name=""
        local group_vars=""
        local theme_var=""
        local -a message_types=(STRT INFO OK WARN FAIL CNCL END DEBUG EMPTY)
        local -a theme_color_groups=(
            "Message colors|MSG_CLR_INFO MSG_CLR_STRT MSG_CLR_OK MSG_CLR_WARN MSG_CLR_FAIL MSG_CLR_CNCL MSG_CLR_END MSG_CLR_EMPTY MSG_CLR_DEBUG"
            "Progress colors|PROG_BAR_CLR PROG_IND_CLR PROG_TEXT_CLR"
            "UI colors|SGND_UI_BORDER SGND_UI_LABEL SGND_UI_VALUE SGND_UI_COMMIT SGND_UI_DRYRUN SGND_UI_ENABLED SGND_UI_DISABLED SGND_UI_ON SGND_UI_OFF SGND_UI_INPUT SGND_UI_PROMPT SGND_UI_INVALID SGND_UI_VALID SGND_UI_SUCCESS SGND_UI_ERROR SGND_UI_TEXT SGND_UI_DEFAULT"
        )

        current_theme="${current_theme%.sh}"
        if [[ "$current_theme" =~ ^[0-9][0-9]-style-(.+)$ ]]; then
            current_theme="${BASH_REMATCH[1]}"
        else
            current_theme="${current_theme#style-}"
        fi

        sgnd_print_titlebar \
            --left "sgnd_print_titlebar - SolidGroundUX Theme Showcase" \
            --right "$current_theme" \
            --sub "Semantic UI colors and framework rendering primitives"

        # Message styles
        sgnd_print
        sgnd_print_sectionheader --text "Message labels"

        for message_type in "${message_types[@]}"; do
            label_var="LBL_${message_type}"
            color_var="MSG_CLR_${message_type}"
            label_value="${!label_var:-}"
            color_value="${!color_var:-$SGND_UI_TEXT}"

            sgnd_print \
                --text "${label_var} = ${label_value}" \
                --textclr "$color_value" \
                --pad 2
        done

        # Rendering primitives
        sgnd_print
        sgnd_print_sectionheader --text "General UI elements"

        sgnd_print \
            --text "sgnd_print - wrapped or styled text output" \
            --pad 2

        sgnd_print_single \
            --text "sgnd_print_single - one non-wrapped rendered line" \
            --pad 2

        sgnd_print_labeledvalue \
            --label "sgnd_print_labeledvalue" \
            --value "Label / value rendering" \
            --pad 2

        sgnd_print_labeledmultivalue \
            --label "sgnd_print_labeledmultivalue" \
            --pad 2 \
            --items \
                "First aligned value" \
                "Second aligned value" \
                "A longer value demonstrates wrapping while continuation lines remain aligned"
        printf '  %sask (simulated)%s : %sSolidGroundUX%s\n' \
            "$SGND_UI_PROMPT" "$RESET" \
            "$SGND_UI_INPUT" "$RESET"

        # Run modes
        sgnd_print
        sgnd_print_sectionheader --text "Run modes"

        printf '  %sCOMMIT%s    %sDRY-RUN%s\n' \
            "$SGND_UI_COMMIT" "$RESET" \
            "$SGND_UI_DRYRUN" "$RESET"

        # State and validation styles
        sgnd_print_sectionheader --text "States and validation"

        printf '  %sENABLED%s   %sDISABLED%s\n' \
            "$SGND_UI_ENABLED" "$RESET" \
            "$SGND_UI_DISABLED" "$RESET"

        printf '  %sVALID%s     %sINVALID%s\n' \
            "$SGND_UI_VALID" "$RESET" \
            "$SGND_UI_INVALID" "$RESET"

        printf '  %sSUCCESS%s   %sERROR%s\n' \
            "$SGND_UI_SUCCESS" "$RESET" \
            "$SGND_UI_ERROR" "$RESET"

        # Progress styles
        sgnd_print
        
        sayprogress_begin --slots 1

        sayprogress \
            --current 65 \
            --total 100 \
            --label "PROG_TEXT_CLR / PROG_IND_CLR / PROG_BAR_CLR" \
            --type 7 \
            --barcolor "$PROG_BAR_CLR" \
            --labelcolor "$PROG_TEXT_CLR" \
            --indicatorcolor "$PROG_IND_CLR"
        sleep 1

        # Resolved semantic colors
        sgnd_print
        sgnd_print
        sgnd_print_sectionheader --text "Theme colors"

        for group_spec in "${theme_color_groups[@]}"; do
            IFS='|' read -r group_name group_vars <<< "$group_spec"

            sgnd_print
            sgnd_print_sectionheader \
                --text "$group_name" \
                --textclr "$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")"

            for theme_var in $group_vars; do
                color_value="${!theme_var:-}"
                [[ -n "$color_value" ]] || continue
                color_description="$(_sgnd_style_color_description "$color_value")"

                sgnd_print_labeledvalue \
                    --label "$theme_var" \
                    --value "$color_description" \
                    --labelwidth 24 \
                    --pad 2 \
                    --valueclr "$color_value"
            done
        done

       
        return 0
    }





