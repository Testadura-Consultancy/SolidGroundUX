# =====================================================================================
# SolidGroundUX - UI Rendering
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.2
#   Build       : 2630700
#   Checksum    : 928452490f1bf5edd81aaa13eee5058089849ae6928fc67a1cb5711d1cc6b951
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
# Library usage:
#   Load via the SolidGroundUX framework bootstrap or source it after the framework
#   has initialized its UI colors and required helpers:
#   ```bash
#   source "${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/ui.sh"
#   sgnd_print --text "Ready"
#   ```
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
# - UI functions --------------------------------------------------------------------
    # fn: _sh_err - Emit a compatibility error message
        # . Purpose
        #   Report an error using say when available, with a plain stderr fallback.
        #
        # . Behavior
        #   - Call say --type FAIL when say is a defined function.
        #   - Otherwise print the joined message, or (no message), to stderr.
        #
        # . Arguments
        #   - `$@` — Words combined into the error message.
        # . Output
        #   Writes through say or to stderr.
        #
        # . Returns
        #   Exit status of the selected output command.
        #
        # . Usage
        #   ```bash
        #   _sh_err "Palette configuration not found"
        #   ```
    _sh_err() {
        if declare -f say >/dev/null 2>&1; then
            say --type FAIL "$*"
        else
            printf '%s\n' "${*:-(no message)}" >&2
        fi
    }
    # fn: confirm - Request a Yes/No confirmation
        # . Purpose
        #   Ask for a confirmation with No as the default.
        #
        # . Behavior
        #   - Use ask with Yes/No validation when available.
        #   - Otherwise use a plain read -rp confirmation prompt.
        #   - Accept Y/y as affirmative; every other answer is negative.
        #
        # . Arguments
        #   - `$1` — (optional) - Prompt; defaults to Are you sure?.
        # . Output
        #   Prompts via ask or a terminal read.
        #
        # . Returns
        #   0 for Yes; nonzero for No or input/prompt failure.
        #
        # . Usage
        #   ```bash
        #   if confirm "Delete this item?"; then
        #       sgnd_print --text "Confirmed"
        #   fi
        #   ```
        #
        # . Notes
        #   Requires a terminal/input stream; the fallback does not use the framework ask UI.
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
    # fn: _sgnd_ui_resolve_theme_file - Locate a readable theme palette or style file
        # . Purpose
        #   Resolve a palette/style name or file path to a readable .sh file.
        #
        # . Behavior
        #   - Treat values containing / or ending in .sh as file paths.
        #   - Otherwise locate <SGND_UI_THEME_DIR>/<kind>/<name>.sh.
        #   - Do not source the resolved file.
        #
        # . Arguments
        #   - `$1` — Theme subdirectory kind (e.g. palettes or styles).
        #   - `$2` — Theme name or explicit path.
        # . Inputs (globals)
        #   SGND_UI_THEME_DIR when resolving by name.
        #
        # . Output
        #   Writes the resolved path to stdout without a final newline; errors to stderr.
        #
        # . Returns
        #   - 0 found; 2 missing specification; 3 unreadable explicit path;
        #   - 4 missing theme directory; 5 named theme not found.
        #
        # . Usage
        #   ```bash
        #   palette_file="$(_sgnd_ui_resolve_theme_file palettes default-ui-palette)"
        #   ```
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
    # fn: sgnd_strip_ansi - Remove ANSI CSI sequences from text
        # . Purpose
        #   Remove supported ANSI control sequences from a string.
        #
        # . Behavior
        #   Use sed to strip ESC-[...] sequences ending with an alphabetic code.
        #
        # . Arguments
        #   - `$1` — Text that may contain CSI sequences.
        # . Output
        #   Writes the stripped text followed by a newline.
        #
        # . Returns
        #   Exit status of sed.
        #
        # . Usage
        #   ```bash
        #   plain="$(sgnd_strip_ansi "$styled_text")"
        #   ```
    sgnd_strip_ansi() {
        sed -r $'s/\x1B\\[[0-9;?]*[[:alpha:]]//g' <<<"$1"
    }
    # fn: sgnd_visible_len - Measure text length without ANSI escapes
        # . Purpose
        #   Calculate a string length after removing ANSI control sequences.
        #
        # . Behavior
        #   Strip supported ANSI escapes, then use Bash string length.
        #
        # . Arguments
        #   - `$1` — Text to measure.
        # . Output
        #   Writes the length as a decimal integer without a newline.
        #
        # . Returns
        #   Exit status of printf.
        #
        # . Usage
        #   ```bash
        #   columns="$(sgnd_visible_len "$styled_label")"
        #   ```
        #
        # . Notes
        #   Measures Bash characters, not terminal display cells; wide Unicode glyphs may occupy more than one cell.
    sgnd_visible_len() {
        local plain
        plain="$(sgnd_strip_ansi "$1")"
        printf '%s' "${#plain}"
    }
    # fn: sgnd_ui_set_theme - Load a palette and UI style into the current shell
        # . Purpose
        #   Select and source a palette and style file for the current shell session.
        #
        # . Behavior
        #   - Resolve palette and style files against SGND_UI_THEME_DIR or explicit paths.
        #   - Source palette before style, and check that palette defines RESET.
        #   - Set SGND_UI_PALETTE_FILE and SGND_UI_STYLE_FILE only after both load.
        #
        # . Arguments
        #   - `--palette NAME|PATH` — Palette name or file path.
        #   - `--style NAME|PATH` — Style name or file path.
        #   - `--default` — Use the built-in default palette and style.
        #   - `-h`, `--help` — Display help.
        #   - `PALETTE STYLE` — Alternatively, pass palette and style as positional values.
        # . Inputs (globals)
        #   SGND_UI_THEME_DIR; optionally SGND_FRAMEWORK_ROOT.
        #
        # . Outputs (globals)
        #   Palette/style shell variables; SGND_UI_PALETTE_FILE; SGND_UI_STYLE_FILE.
        #
        # . Output
        #   Writes help or diagnostics; otherwise no output on success.
        #
        # . Returns
        #   - 0 when the palette and style load successfully, or for `--help`.
        #   - 2 for unexpected arguments.
        #   - 3–5 for theme file lookup errors; 10–12 for palette/style load errors.
        #
        # . Usage
        #   ```bash
        #   sgnd_ui_set_theme --default
        #   sgnd_ui_set_theme --palette default-ui-palette --style 00-style-default
        #   ```
        #
        # . Notes
        #   Sourcing theme files can modify the current shell even if a later validation fails.
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

    # fn: sgnd_theme - Show or change the selected semantic UI style
        # . Purpose
        #   Display the active theme name or select and optionally persist another style.
        #
        # . Behavior
        #   - Without THEME, report SGND_UI_STYLE or the default style.
        #   - Resolve short names against numbered *-style-*.sh files in SGND_STYLE_DIR.
        #   - Set SGND_UI_STYLE and load it using sgnd_load_ui_style.
        #   - When available, write the style to SGND_FRAMEWORK_STATEFILE.
        #   - With --save, write SGND_UI_STYLE to SGND_FRAMEWORK_USRCFG_FILE.
        #   - Attempt to restore the previous in-memory theme on a failed load/save.
        #
        # . Arguments
        #   - `THEME` — (optional) - Short theme name, numbered style file, or path. --save - Persist the selected style to the user configuration. -h, --help - Display help.
        # . Inputs (globals)
        #   SGND_UI_STYLE, SGND_STYLE_DIR, framework state/user configuration paths.
        #
        # . Outputs (globals)
        #   SGND_UI_STYLE and optionally framework state/user configuration.
        #
        # . Output
        #   Prints current theme, help or errors; selection is otherwise silent.
        #
        # . Returns
        #   - 0 for display, help or successful selection; 1 for theme/load/save errors;
        #   - 2 for invalid arguments.
        #
        # . Usage
        #   ```bash
        #   sgnd_theme
        #   sgnd_theme dark
        #   sgnd_theme fantasy --save
        #   ```
        #
        # . Notes
        #   A failure during --save may occur after framework state was already updated.
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
    # fn: sgnd_ui_set_default_theme - Restore the framework default palette and style
        # . Purpose
        #   Load the framework default theme into the current shell.
        #
        # . Behavior
        #   Delegate to sgnd_ui_set_theme --default.
        #
        # . Output
        #   Diagnostics from sgnd_ui_set_theme, if any.
        #
        # . Returns
        #   Exit status of sgnd_ui_set_theme.
        #
        # . Usage
        #   ```bash
        #   sgnd_ui_set_default_theme
        #   ```
    sgnd_ui_set_default_theme() {
        sgnd_ui_set_theme --default
    }
    # fn: sgnd_sgr - Compose an ANSI SGR sequence
        # . Purpose
        #   Compose one ANSI Select Graphic Rendition sequence from supplied parameters.
        #
        # . Behavior
        #   - Ignore empty tokens and unsupported token forms.
        #   - Accept semicolon/comma lists and extract numeric parameters from SGR sequences.
        #   - Return RESET when no valid parameters remain.
        #
        # . Arguments
        #   - `$@` — Numeric SGR values, lists of numeric values, or ANSI SGR sequences.
        # . Inputs (globals)
        #   RESET for the no-parameter case.
        #
        # . Output
        #   Writes the escape sequence without a newline.
        #
        # . Returns
        #   Exit status of printf.
        #
        # . Usage
        #   ```bash
        #   bold_blue="$(sgnd_sgr "$BRIGHT_BLUE" "$FX_BOLD")"
        #   ```
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
    # fn: sgnd_fg - Compose a foreground color and text effects
        # . Purpose
        #   Build a foreground SGR sequence with optional text effects.
        #
        # . Behavior
        #   Forward the requested color and effects to sgnd_sgr.
        #
        # . Arguments
        #   - `$1` — Foreground color sequence or SGR parameter.
        #   - `$2...` — Optional effects.
        # . Output
        #   Writes an ANSI sequence without a newline.
        #
        # . Returns
        #   Exit status of sgnd_sgr.
        #
        # . Usage
        #   ```bash
        #   color="$(sgnd_fg "$BRIGHT_BLUE" "$FX_BOLD")"
        #   ```
    sgnd_fg() {
        local fg="${1:-}"
        shift || true
        sgnd_sgr "$fg" "" "$@"
    }

    # fn: sgnd_bg - Compose a background color and text effects
        # . Purpose
        #   Build a background SGR sequence with optional text effects.
        #
        # . Behavior
        #   Forward the background color and effects to sgnd_sgr.
        #
        # . Arguments
        #   - `$1` — Background color sequence or SGR parameter.
        #   - `$2...` — Optional effects.
        # . Output
        #   Writes an ANSI sequence without a newline.
        #
        # . Returns
        #   Exit status of sgnd_sgr.
        #
        # . Usage
        #   ```bash
        #   background="$(sgnd_bg "$BG_BLUE" "$FX_BOLD")"
        #   ```
    sgnd_bg() {
        local bg="${1:-}"
        shift || true
        sgnd_sgr "" "$bg" "$@"
    }

 # -- Runmode indicators ----------------------------------------------------------
    # fn: sgnd_update_runmode - Refresh the displayed dry-run/commit indicator
        # . Purpose
        #   Set RUN_MODE to the styled DRYRUN or COMMIT label according to FLAG_DRYRUN.
        #
        # . Behavior
        #   - Use sgnd_runmode_color to choose the current mode color.
        #   - Append RESET after the DRYRUN or COMMIT text.
        #
        # . Inputs (globals)
        #   FLAG_DRYRUN, SGND_UI_DRYRUN, SGND_UI_COMMIT, RESET.
        #
        # . Outputs (globals)
        #   RUN_MODE in the current shell.
        #
        # . Returns
        #   Exit status of the final assignment (normally 0).
        #
        # . Usage
        #   ```bash
        #   sgnd_update_runmode
        #   sgnd_print_titlebar
        #   ```
    sgnd_update_runmode() {
        if (( FLAG_DRYRUN )); then
            RUN_MODE="$(sgnd_runmode_color)DRYRUN${RESET}"
        else
            RUN_MODE="$(sgnd_runmode_color)COMMIT${RESET}"
        fi
    }
    # fn: sgnd_runmode_color - Get the color for the current run mode
        # . Purpose
        #   Return the semantic color for dry-run or commit mode.
        #
        # . Inputs (globals)
        #   FLAG_DRYRUN, SGND_UI_DRYRUN, SGND_UI_COMMIT.
        #
        # . Output
        #   Writes the selected color sequence without a newline.
        #
        # . Returns
        #   Exit status of printf.
        #
        # . Usage
        #   ```bash
        #   runmode_color="$(sgnd_runmode_color)"
        #   ```
    sgnd_runmode_color() {
        (( FLAG_DRYRUN )) && printf '%s' "$SGND_UI_DRYRUN" || printf '%s' "$SGND_UI_COMMIT"
    }

    # -- Rendering primitives --------------------------------------------------------
    # fn: sgnd_terminal_width - Determine the available terminal width
        # . Purpose
        #   Return the number of columns available for console rendering.
        #
        # . Behavior
        #   - Try tput cols on /dev/tty without reading application stdin.
        #   - Next try tput on stdout when stdout is a terminal.
        #   - Otherwise use valid COLUMNS; finally fall back to 80.
        #
        # . Inputs (globals)
        #   COLUMNS when terminal probing fails.
        #
        # . Output
        #   Writes a positive column count followed by a newline.
        #
        # . Returns
        #   0 after printing the selected width.
        #
        # . Usage
        #   ```bash
        #   terminal_columns="$(sgnd_terminal_width)"
        #   ```
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

    # fn: sgnd_render_width - Clamp the requested render width to the terminal
        # . Purpose
        #   Choose an effective width no larger than the current terminal width.
        #
        # . Behavior
        #   - Read the terminal width on every call.
        #   - Use the requested width only when positive and narrower than the terminal.
        #
        # . Arguments
        #   - `$1` — (optional) - Requested positive width; 0/empty/invalid uses full terminal width.
        # . Output
        #   Writes an integer width followed by a newline.
        #
        # . Returns
        #   0 after printing the width.
        #
        # . Usage
        #   ```bash
        #   width="$(sgnd_render_width 120)"
        #   ```
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
    # fn: sgnd_print_labeledvalue - Print one styled label and value
        # . Purpose
        #   Render a single aligned label/value line using current UI colors.
        #
        # . Behavior
        #   - Return without output for an empty label.
        #   - Truncate the value to the available width before printing.
        #   - Format the label in a fixed-width field.
        #
        # . Arguments
        #   - `--label TEXT` — Label to display.
        #   - `--value TEXT` — Associated value.
        #   - `--sep TEXT` — Separator (default: colon).
        #   - `--labelwidth N` — Label field width (default: 25).
        #   - `--maxwidth N` — Maximum total width, capped to terminal width.
        #   - `--pad N` — Left padding in spaces (default: 0).
        #   - `--labelclr ANSI` — Label color override.
        #   - `--valueclr ANSI` — Value color override.
        #   - `LABEL VALUE` — Positional form is also accepted.
        # . Inputs (globals)
        #   SGND_UI_LABEL, SGND_UI_VALUE, RESET.
        #
        # . Output
        #   Writes one styled label/value line to stdout.
        #
        # . Returns
        #   0 for an empty label or successful rendering; printf status otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_print_labeledvalue --label "Host" --value "td-dev" --pad 2
        #   sgnd_print_labeledvalue "Status" "Ready" --labelwidth 18 --maxwidth 80
        #   ```
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

    # fn: sgnd_print_labeledmultivalue - Print wrapped or multiple values under one label
        # . Purpose
        #   Render a label with wrapped value lines aligned in one value column.
        #
        # . Behavior
        #   - Print the label and separator only on the first line.
        #   - Align continuation and wrapped lines to the initial value column.
        #   - Wrap using sgnd_wrap_words and preserve explicit empty items or lines.
        #
        # . Arguments
        #   - `--label TEXT` — - Required label.
        #   - `--value TEXT` — - Single possibly multiline value.
        #   --items ITEM... - Remaining arguments are separate items (must be last).
        #   - `--valuewidth N` — - Positive value-column width, capped to available width.
        #   - `--sep TEXT` — - Separator (default colon).
        #   - `--labelwidth N` — - Label field width (default 25).
        #   - `--maxwidth N` — - Total width, capped to terminal width.
        #   - `--pad N` — - Left padding (default 0).
        #   - `--labelclr ANSI` — / --valueclr ANSI - Color overrides.
        #
        # . Inputs (globals)
        #   SGND_UI_LABEL, SGND_UI_VALUE, RESET.
        #
        # . Output
        #   Writes one or more styled lines to stdout.
        #
        # . Returns
        #   - 0 after rendering
        #   - 2 if label is missing or a numeric option is invalid.
        #
        # . Usage
        #   ```bash
        #   sgnd_print_labeledmultivalue \
        #       --label "Changed files" \
        #       --items "first.sh" "second.sh"
        #   sgnd_print_labeledmultivalue --label "Description" --value "$description" --valuewidth 60
        #   ```
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

        # fn: _sgnd_labeledmultivalue_emit - Emit one line of a labeled multivalue block
            # . Purpose
            #   Write one wrapped value line and track whether it is the first line.
            #
            # . Behavior
            #   - On the first call, print the label, separator and value.
            #   - On later calls, print an aligned continuation without the label.
            #
            # . Arguments
            #   - `$1` — Already-wrapped value line.
            # . Inputs (globals)
            #   Closure-local variables in sgnd_print_labeledmultivalue, including label, colors, padding and continuation_prefix.
            #
            # . Outputs (globals)
            #   Closure-local first_output and emitted flags.
            #
            # . Output
            #   Writes one styled line to stdout.
            #
            # . Returns
            #   Exit status of the assignment to emitted (normally 0).
            #
            # . Usage
            #   ```bash
            #   # Inside sgnd_print_labeledmultivalue only:
            #   _sgnd_labeledmultivalue_emit "$wrapped_line"
            #   ```
            #
            # . Notes
            #   This dynamically defined helper is removed with unset -f before the outer function returns.
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
    # fn: sgnd_print_fill - Print left and right text separated by fill characters
        # . Purpose
        #   Render one line whose left/right texts are separated by repeated fill characters.
        #
        # . Behavior
        #   - Calculate fill from visible text lengths and requested padding.
        #   - Inherit the left color for the right when no right color is specified.
        #   - Never use a negative fill count.
        #
        # . Arguments
        #   - `--left TEXT` — Text at the left end.
        #   - `--right TEXT` — Text at the right end.
        #   - `--padleft N` — Left padding in characters (default: 2).
        #   - `--padright N` — Right padding in characters (default: 1).
        #   - `--maxwidth N` — Maximum width, capped to the terminal.
        #   - `--fillchar CHAR` — Fill character (only the first character is used).
        #   - `--leftclr ANSI` — Left text color override.
        #   - `--rightclr ANSI` — Right text color override.
        #   - `LEFT RIGHT` — Positional form is also accepted.
        # . Inputs (globals)
        #   SGND_UI_TEXT, RESET.
        #
        # . Output
        #   Writes one styled filled line to stdout.
        #
        # . Returns
        #   Exit status of printf.
        #
        # . Usage
        #   ```bash
        #   sgnd_print_fill --left "Source" --right "Destination" --fillchar .
        #   sgnd_print_fill "Queued" "12 items" --fillchar - --maxwidth 60
        #   ```
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
    # fn: sgnd_print_titlebar - Render a themed application title bar
        # . Purpose
        #   Render a title block with script metadata, run mode and optional subtitle.
        #
        # . Behavior
        #   - Start with script title, version/build and RUN_MODE when no overrides apply.
        #   - Mark non-root installations with NON-ROOT in the default left title.
        #   - Compose the bar using sgnd_print, sgnd_print_fill and sgnd_print_sectionheader.
        #
        # . Arguments
        #   - `--left TEXT` — Main left title; overrides metadata default.
        #   - `--right TEXT` — Right title/run mode; overrides metadata default.
        #   - `--sub TEXT` — Subtitle below the main title.
        #   - `--subjust L|C|R` — Subtitle justification.
        #   - `--leftclr ANSI` — Left title color override.
        #   - `--rightclr ANSI` — Right title color override.
        #   - `--subclr ANSI` — Subtitle color override.
        #   - `--border CHAR` — Border character.
        #   - `--borderclr ANSI` — Border color override.
        #   - `--padleft N` — Left padding.
        #   - `--maxwidth N` — Maximum render width.
        #
        # . Inputs (globals)
        #   SGND_SCRIPT_* metadata, RUN_MODE, SGND_FRAMEWORK_ROOT, title/style globals.
        #
        # . Output
        #   Writes the themed title bar to stdout.
        #
        # . Returns
        #   Exit status of the final sgnd_print_sectionheader call.
        #
        # . Usage
        #   ```bash
        #   # Use the default title from script metadata.
        #   sgnd_print_titlebar
        #
        #   # Override the title, run-mode label and subtitle.
        #   sgnd_print_titlebar --left "Smoke tests" --right "DRYRUN" --sub "System checks"
        #   ```
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
    # fn: sgnd_print_sectionheader - Render a themed section heading or border
        # . Purpose
        #   Print a section heading with optional leading/trailing border characters.
        #
        # . Behavior
        #   - With no heading, print a full-width border.
        #   - With a heading, align optional border fill to the render width.
        #   - Strip ANSI escapes only for plain-text length preparation.
        #
        # . Arguments
        #   - `--text TEXT` — - Section heading; omit for a full-width border.
        #   - `--textclr ANSI` — / --borderclr ANSI - Colors.
        #   - `--border CHAR` — - Border string.
        #   - `--padleft N` — - Border characters before heading (default 4).
        #   --padend 0|1 - Whether to fill the right side (default 1).
        #   - `--maxwidth N` — - Maximum render width.
        #
        # . Inputs (globals)
        #   SGND_SECTION_* and SGND_UI_* theme variables; RESET.
        #
        # . Output
        #   Writes one themed line to stdout.
        #
        # . Returns
        #   0 on successful printing; printf status otherwise.
        #
        # . Usage
        #   ```bash
        #   sgnd_print_sectionheader --text "Network settings"
        #   sgnd_print_sectionheader --border =
        #   ```
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
    # fn: sgnd_print - Print optionally wrapped and aligned themed text
        # . Purpose
        #   Render console text with theme color, padding, alignment and automatic wrapping.
        #
        # . Behavior
        #   - With empty text, write a blank line via sgnd_print_single.
        #   - When wrapping is enabled, wrap with sgnd_wrap_words.
        #   - Delegate each rendered line to sgnd_print_single.
        #
        # . Arguments
        #   - `--text TEXT` — Text to print; also accepts the first positional value.
        #   - `--textclr ANSI` — Text color sequence.
        #   - `--justify L|C|R` — Alignment (default: left).
        #   - `--wrap 0|1` — Explicit wrapping; otherwise wrap when text exceeds the available width.
        #   - `--pad N` — Left padding in spaces.
        #   - `--rightmargin N` — Right margin in spaces.
        #   - `--maxwidth N` — Maximum content width, capped at terminal width.
        #
        # . Inputs (globals)
        #   SGND_UI_TEXT, RESET.
        #
        # . Output
        #   Writes one or more styled console lines to stdout.
        #
        # . Returns
        #   0 for an empty-text call; otherwise final rendering status.
        #
        # . Usage
        #   ```bash
        #   sgnd_print --text "Ready" --pad 2
        #   sgnd_print --text "$description" --wrap 1 --maxwidth 80
        #   ```
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
    # fn: sgnd_print_single - Render one aligned non-wrapped line
        # . Purpose
        #   Print a single themed line using left, center or right alignment.
        #
        # . Behavior
        #   - Print an empty line for empty text.
        #   - Measure visible width without ANSI sequences.
        #   - If text is too long, strip styling and truncate to available length.
        #   - Pad the line to its effective width.
        #
        # . Arguments
        #   - `--text TEXT` — Text to render; the first positional argument is also accepted.
        #   - `--textclr ANSI` — Text color override.
        #   - `--justify L|C|R` — Alignment (default: left).
        #   - `--pad N` — Outer padding in spaces (default: 0).
        #   - `--maxwidth N` — Maximum render width.
        #
        # . Inputs (globals)
        #   SGND_UI_TEXT, RESET.
        #
        # . Output
        #   Writes one ANSI-styled line and a newline to stdout.
        #
        # . Returns
        #   0 for an empty-text call; otherwise printf status.
        #
        # . Usage
        #   ```bash
        #   sgnd_print_single --text "Ready" --justify C --maxwidth 80
        #   sgnd_print_single "Waiting for input" --justify L --pad 2
        #   ```
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
    # fn: sgnd_print_file - Display a file as plain text or rendered Markdown
        # . Purpose
        #   Display a readable file, selecting a Markdown renderer and pager when available.
        #
        # . Behavior
        #   - Detect Markdown by .md extension (case-insensitive).
        #   - For Markdown, prefer glow, then mdcat, bat, or pandoc if installed.
        #   - For other files or when no renderer is available, use less in interactive output or cat.
        #   - Do not invoke less for non-interactive stdout.
        #
        # . Arguments
        #   - `$1` — Required path to the file to display.
        # . Output
        #   Displays file contents, rendered output, or errors.
        #
        # . Returns
        #   - 2 if a provided path is empty or unreadable; otherwise status from the selected renderer, pager or cat.
        #
        # . Usage
        #   ```bash
        #   sgnd_print_file /etc/hosts
        #   sgnd_print_file "$README_PATH"
        #   ```
        #
        # . Notes
        #   With set -u active, omitting $1 entirely triggers Bash unbound-variable handling before the missing-path check.
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
    # fn: sgnd_print_cell - Print a string padded to a visible column width
        # . Purpose
        #   Print styled text followed by spaces to meet a requested column width.
        #
        # . Behavior
        #   - Measure width after stripping supported ANSI sequences.
        #   - Never truncate strings longer than the requested width.
        #
        # . Arguments
        #   - `$1` — Target width in characters.
        #   - `$2` — Text, optionally containing ANSI CSI sequences.
        # . Output
        #   Writes the original text and trailing spaces without a newline.
        #
        # . Returns
        #   Exit status of printf.
        #
        # . Usage
        #   ```bash
        #   sgnd_print_cell 20 "Host"
        #   ```
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
    # fn: sgnd_module_show_metadata - Display registered module or script metadata
        # . Purpose
        #   Look up and display SGND_* metadata for a module or script.
        #
        # . Behavior
        #   - Use an SGND_* prefix directly or derive one from the real file path.
        #   - Read the corresponding *_FILE, *_TITLE, *_VERSION and other metadata variables.
        #   - Print each available field through sgnd_print_labeled_value.
        #   - Print a separate Description section when a description exists.
        #
        # . Arguments
        #   - `$1` — Required SGND_* prefix or script filename.
        # . Inputs (globals)
        #   SGND_<MODULE>_* metadata variables; sgnd_print_labeled_value helper.
        #
        # . Output
        #   Writes labeled metadata fields and optional description to stdout.
        #
        # . Returns
        #   - 1 if readlink -f fails; otherwise 0 after printing. An omitted $1 triggers Bash missing-argument expansion.
        #
        # . Usage
        #   ```bash
        #   sgnd_module_show_metadata SGND_UI
        #   sgnd_module_show_metadata "$SGND_SCRIPT_FILE"
        #   ```
        #
        # . Notes
        #   This function calls sgnd_print_labeled_value (with an underscore); confirm that helper is defined by the runtime.
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

    # fn: sgnd_clear - Clear the visible terminal screen
        # . Purpose
        #   Clear the visible terminal display and move the cursor to the top-left.
        #
        # . Behavior
        #   - Print ESC[H followed by ESC[2J.
        #   - Leave scrollback history untouched.
        #
        # . Output
        #   Writes two ANSI control sequences to stdout.
        #
        # . Returns
        #   Exit status of printf.
        #
        # . Usage
        #   ```bash
        #   sgnd_clear
        #   ```
    sgnd_clear() {
        #printf '\033[H\033[2J\033[3J'
        printf '\033[H\033[2J'
    }
    # fn: sgnd_color_samples - Preview named palette colors and effects
        # . Purpose
        #   Display sample colors and text effects from the active palette.
        #
        # . Behavior
        #   - Print a fixed sample heading.
        #   - Use sgnd_sample_row for the predefined color families.
        #
        # . Inputs (globals)
        #   Palette variables and effect variables used by sgnd_sample_row.
        #
        # . Output
        #   Prints a collection of color/effect samples.
        #
        # . Returns
        #   Exit status of the last sgnd_sample_row invocation.
        #
        # . Usage
        #   ```bash
        #   sgnd_color_samples
        #   ```
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
    # fn: sgnd_sample_row - Preview a row of palette variables and effects
        # . Purpose
        #   Render sample output for each supplied palette variable name.
        #
        # . Behavior
        #   - Resolve each name through Bash eval.
        #   - Display the name/color and bold, faint, italic, underline, reverse and strike samples.
        #
        # . Arguments
        #   - `$@` — Names of already-defined color variables (not literal color values).
        # . Inputs (globals)
        #   Named palette variables and FX_* effect sequences; RESET.
        #
        # . Output
        #   Prints one demonstration line per supplied variable, then a blank line.
        #
        # . Returns
        #   Exit status of the final printf.
        #
        # . Usage
        #   ```bash
        #   sgnd_sample_row BLUE BRIGHT_BLUE DARK_BLUE
        #   ```
        #
        # . Notes
        #   Pass trusted variable names only; implementation resolves the names with eval.
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

    # fn: _sgnd_style_color_description - Describe a resolved semantic color value
        # . Purpose
        #   Convert a selected ANSI color value into a readable palette name or color code.
        #
        # . Behavior
        #   - First compare the value with known palette variables.
        #   - Then decode 24-bit foreground colors as #RRGGBB.
        #   - Then decode indexed foreground colors as xterm-N.
        #   - Return custom for other sequences.
        #
        # . Arguments
        #   - `$1` — Resolved ANSI foreground color sequence.
        # . Inputs (globals)
        #   Named palette variables.
        #
        # . Output
        #   Writes one descriptive string followed by a newline.
        #
        # . Returns
        #   0 after printing the description.
        #
        # . Usage
        #   ```bash
        #   color_name="$(_sgnd_style_color_description "$SGND_UI_BORDER")"
        #   ```
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

    # fn: sgnd_style_samples - Showcase the currently active UI style
        # . Purpose
        #   Display a non-interactive demonstration of theme colors and UI primitives.
        #
        # . Behavior
        #   - Show the current theme name in a title bar.
        #   - Demonstrate message labels, text rendering, labeled values and prompt styling.
        #   - Display run modes, validation states and progress styling.
        #   - List resolved semantic colors by palette name, RGB hex or indexed color.
        #
        # . Inputs (globals)
        #   SGND_UI_STYLE, MSG_CLR_*, PROG_*, LBL_* and UI theme variables.
        #
        # . Output
        #   Writes a full theme showcase to the terminal.
        #
        # . Returns
        #   0 after completing the demonstration.
        #
        # . Usage
        #   ```bash
        #   sgnd_style_samples
        #   ```
        #
        # . Notes
        #   Uses sayprogress_begin/sayprogress and pauses briefly with sleep 1.
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





