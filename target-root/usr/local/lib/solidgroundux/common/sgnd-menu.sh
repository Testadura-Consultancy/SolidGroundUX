# =====================================================================================
# SolidGroundUX - Menu Library
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627412
#   Checksum    : e0b271f75db3b35a454693399403a2fa6531dc860b7b518d9d3f4c4d08778872
#   Source      : sgnd-menu.sh
#   Group       : Common Core
#   Type        : library
#   Purpose     : Provide reusable menu definition, rendering, navigation, and dispatch
#
# Description:
#   Provides the reusable menu system used by the management console and other SolidGroundUX applications.
#
#   The library:
#     - Defines menu structures and item registration mechanisms
#     - Supports grouping, ordering, and labeling of menu items
#     - Integrates with rendering helpers to display menus consistently
#     - Handles user selection and dispatch to registered actions
#     - Enables modular extension by allowing external modules to register items
#
# Design principles:
#   - Modular menu composition through registration rather than hardcoding
#   - Clear separation between menu definition, rendering, and execution
#   - Predictable navigation and selection behavior
#   - Minimal coupling to specific applications or modules
#
# Role in framework:
#   - Reusable SolidGroundUX UI component
#   - Bridges UI rendering, input handling, and executable scripts
#   - Enables pluggable console applications through module-based menus
#
# Non-goals:
#   - Full TUI frameworks or complex screen management
#   - Persistent menu state beyond runtime session
#   - Business logic execution beyond dispatching actions
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
    # fn: _sgnd_flag_is_on - Evaluate whether a menu/framework flag is enabled
        # . Arguments
        #   $1  Value to evaluate.
        #
        # . Returns
        #   0 for 1, true, yes, or on (case-insensitive variants currently supported).
        #   1 otherwise.
        #
        # . Usage
        #   _sgnd_flag_is_on "${FLAG_DRYRUN:-0}"
    _sgnd_flag_is_on() {
        case "${1:-}" in
            1|true|TRUE|yes|YES|on|ON) return 0 ;;
            *) return 1 ;;
        esac
    }

# - Toggle formatting --------------------------------------------------------------
    # fn: _sgnd_console_toggleword - Render a toggle word with an emphasized hotkey
        # . Purpose
        #   Format one toggle label using the enabled/disabled color and underline its hotkey.
        #
        # . Arguments
        #   $1  WORD    - Toggle text.
        #   $2  HOTKEY  - Character to emphasize within WORD.
        #   $3  STATE   - Non-zero for enabled, zero for disabled.
        #   $4  ONCLR   - Optional enabled color.
        #   $5  OFFCLR  - Optional disabled color.
        #
        # . Output
        #   Writes the styled toggle word to stdout.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   _sgnd_console_toggleword "MODE" "M" 1 "$SGND_UI_ON" "$SGND_UI_OFF"
    _sgnd_console_toggleword() {
        local word="${1:?missing word}"
        local hotkey="${2:?missing hotkey}"
        local state="${3:-0}"

        local onclr="${4:-$SGND_UI_ON}"
        local offclr="${5:-$SGND_UI_OFF}"

        local word_style=""
        local key_style=""
        local prefix=""
        local suffix=""

        if (( state )); then
            word_style="$(sgnd_sgr "$onclr" "$FX_BOLD")"
            key_style="$(sgnd_sgr "$onclr" "$FX_BOLD" "$FX_UNDERLINE")"
        else
            if [[ "$word" == "DRYRUN" ]]; then
                word="COMMIT(D)"
            fi
            word_style="$(sgnd_sgr "$offclr")"
            key_style="$(sgnd_sgr "$offclr" "$FX_BOLD" "$FX_UNDERLINE")"
        fi

        prefix="${word%%"$hotkey"*}"
        suffix="${word#*"$hotkey"}"

        if [[ "$word" == "$prefix" ]]; then
            printf '%s%s%s' "$word_style" "$word" "$RESET"
            return 0
        fi

        printf '%s%s%s%s%s%s%s' \
            "$word_style" "$prefix" \
            "$key_style" "$hotkey" \
            "$RESET" \
            "$word_style" "$suffix" \
            "$RESET"
    }
    # fn: _sgnd_console_statusword - Render one status-bar fragment
        # . Arguments
        #   $1  LABEL  - Status label.
        #   $2  VALUE  - Display value.
        #   $3  COLOR  - Optional value color.
        #   $4  HOTKEY - Optional character to emphasize in LABEL.
        #
        # . Output
        #   Writes a styled LABEL: VALUE fragment to stdout.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   _sgnd_console_statusword "MODE" "DRY-RUN" "$SGND_UI_DRYRUN" "M"
    _sgnd_console_statusword() {
        local label="${1:?missing label}"
        local value="${2:?missing value}"
        local color="${3:-$SGND_UI_TEXT}"
        local hotkey="${4:-}"
        local label_text=""
        local prefix=""
        local suffix=""

        label_text="$(sgnd_sgr "$SGND_UI_LABEL")${label}${RESET}"

        if [[ -n "$hotkey" && "$label" == *"$hotkey"* ]]; then
            prefix="${label%%"$hotkey"*}"
            suffix="${label#*"$hotkey"}"
            label_text="$(sgnd_sgr "$SGND_UI_LABEL")${prefix}$(sgnd_sgr "$SGND_UI_LABEL" "" "$FX_BOLD" "$FX_UNDERLINE")${hotkey}${RESET}$(sgnd_sgr "$SGND_UI_LABEL")${suffix}${RESET}"
        fi

        printf '%s: %s%s%s' "$label_text" "$(sgnd_sgr "$color" "" "$FX_BOLD")" "$value" "$RESET"
    }

    # fn: _sgnd_console_onoff - Render a colored On/Off state
        # . Arguments
        #   $1  VALUE  - Boolean/numeric state.
        #   $2  ONCLR  - Optional enabled color.
        #   $3  OFFCLR - Optional disabled color.
        #
        # . Output
        #   Writes styled On or Off text to stdout.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   _sgnd_console_onoff "$FLAG_DRYRUN" "$SGND_UI_DRYRUN" "$SGND_UI_COMMIT"
    _sgnd_console_onoff() {
        local value="${1:-0}"
        local onclr="${2:-$SGND_UI_ON}"
        local offclr="${3:-$SGND_UI_OFF}"

        if (( value )); then
            printf '%sOn%s' "$(sgnd_sgr "$onclr")" "$RESET"
        else
            printf '%sOff%s' "$(sgnd_sgr "$offclr")" "$RESET"
        fi
    }
# - Toggle labels ------------------------------------------------------------------
    # fn: _sgnd_console_label_clearonrender - Build the clear-on-render label
        # . Output
        #   Writes the current Clear screen toggle label to stdout.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   _sgnd_console_label_clearonrender
    _sgnd_console_label_clearonrender() {
        : "${SGND_CLEAR_ONRENDER:=1}"
        printf 'Clear screen: %s' "$(_sgnd_console_onoff "$SGND_CLEAR_ONRENDER")"
    }
    # fn: _sgnd_console_label_dryrun - Build the dry-run label
        # . Output
        #   Writes the current Dry-run/Commit toggle label to stdout.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   _sgnd_console_label_dryrun
    _sgnd_console_label_dryrun() {
        : "${FLAG_DRYRUN:=0}"
        printf 'Dry-run: %s' "$(_sgnd_console_onoff "$FLAG_DRYRUN" "$SGND_UI_DRYRUN" "$SGND_UI_COMMIT")"
    }
    # fn: _sgnd_console_label_debug - Build the debug label
        # . Output
        #   Writes the current Debug toggle label to stdout.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   _sgnd_console_label_debug
    _sgnd_console_label_debug() {
        : "${FLAG_DEBUG:=0}"
        printf 'Debug: %s' "$(_sgnd_console_onoff "$FLAG_DEBUG")"
    }
    # fn: _sgnd_console_label_verbose - Build the verbose label
        # . Output
        #   Writes the current Verbose toggle label to stdout.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   _sgnd_console_label_verbose
    _sgnd_console_label_verbose() {
        : "${FLAG_VERBOSE:=0}"
        printf 'Verbose: %s' "$(_sgnd_console_onoff "$FLAG_VERBOSE")"
    }
    # fn: _sgnd_console_label_logfile - Build the logfile label
        # . Output
        #   Writes the current Logfile toggle label to stdout.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   _sgnd_console_label_logfile
    _sgnd_console_label_logfile() {
        : "${SGND_LOGFILE_ENABLED:=0}"
        printf 'Logfile: %s' "$(_sgnd_console_onoff "$SGND_LOGFILE_ENABLED")"
    }
# - Toggle actions -----------------------------------------------------------------
    # fn: _sgnd_console_toggle_clearonrender - Toggle clear-on-render
        # . Purpose
        #   Switch SGND_CLEAR_ONRENDER between enabled and disabled for the current session.
        #
        # Outputs (globals):
        #   SGND_CLEAR_ONRENDER
        #
        # . Returns
        #   0 after toggling.
        #
        # . Usage
        #   _sgnd_console_toggle_clearonrender
    _sgnd_console_toggle_clearonrender() {
        : "${SGND_CLEAR_ONRENDER:=1}"

        if (( SGND_CLEAR_ONRENDER )); then
            SGND_CLEAR_ONRENDER=0
            sayinfo "Clear-on-render disabled"
        else
            SGND_CLEAR_ONRENDER=1
            sayinfo "Clear-on-render enabled"
        fi
    }
    # fn: _sgnd_console_toggle_debug - Toggle debug mode
        # . Purpose
        #   Toggle FLAG_DEBUG and refresh the framework run mode.
        #
        # Outputs (globals):
        #   FLAG_DEBUG
        #
        # . Returns
        #   Status returned by sgnd_update_runmode.
        #
        # . Usage
        #   _sgnd_console_toggle_debug
    _sgnd_console_toggle_debug() {
        : "${FLAG_DEBUG:=0}"

        if (( FLAG_DEBUG )); then
            FLAG_DEBUG=0
            sayinfo "Debug disabled"
        else
            FLAG_DEBUG=1
            sayinfo "Debug enabled"
        fi
        sgnd_update_runmode
    }
    # fn: _sgnd_console_toggle_verbose - Toggle verbose mode
        # . Purpose
        #   Switch FLAG_VERBOSE for the current console session.
        #
        # Outputs (globals):
        #   FLAG_VERBOSE
        #
        # . Returns
        #   0 after toggling.
        #
        # . Usage
        #   _sgnd_console_toggle_verbose
    _sgnd_console_toggle_verbose() {
        : "${FLAG_VERBOSE:=0}"

        if (( FLAG_VERBOSE )); then
            FLAG_VERBOSE=0
            sayinfo "Verbose disabled"
        else
            FLAG_VERBOSE=1
            sayinfo "Verbose enabled"
        fi
    }

    # fn: _sgnd_console_theme_name - Return the active theme name
        # . Purpose
        #   Derive a human-readable theme name from SGND_UI_STYLE.
        #
        # . Output
        #   Writes the normalized theme name to stdout.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   theme="$(_sgnd_console_theme_name)"
    _sgnd_console_theme_name() {
        local style="${SGND_UI_STYLE##*/}"

        style="${style%.sh}"
        if [[ "$style" =~ ^[0-9][0-9]-style-(.+)$ ]]; then
            style="${BASH_REMATCH[1]}"
        else
            style="${style#style-}"
            [[ "$style" == "default-ui-style" ]] && style="default"
        fi

        printf '%s' "$style"
    }


# - Session actions ----------------------------------------------------------------
    # fn: _sgnd_console_set_lines_per_page - Set lines per page
        # . Purpose
        #   Prompt for and apply the number of menu lines available per page.
        #
        # . Returns
        #   0 on success; non-zero on cancellation or invalid input.
        #
        # . Usage
        #   _sgnd_console_set_lines_per_page
    _sgnd_console_set_lines_per_page() {
        local lines="${SGND_PAGE_MAX_ROWS:-25}"

        ask \
            --label "Lines per page" \
            --default "$lines" \
            --var lines || return $?

        if [[ ! "$lines" =~ ^[0-9]+$ ]] || (( lines < 5 )); then
            saywarning "Lines per page must be a whole number of at least 5"
            return 1
        fi

        SGND_PAGE_MAX_ROWS="$lines"
        SGND_PAGE_INDEX=0
        sayinfo "Menu lines per page set to $SGND_PAGE_MAX_ROWS"

        sgnd_state_set SGND_PAGE_MAX_ROWS "$SGND_PAGE_MAX_ROWS"
    }
    # fn: _sgnd_console_redraw - Request a menu redraw
        # . Returns
        #   0; the host loop redraws the menu on the next iteration.
        #
        # . Usage
        #   _sgnd_console_redraw
    _sgnd_console_redraw() {
        # Force layout-dependent caches to be recalculated on the next draw.
        # Terminal width itself is re-read from /dev/tty by sgnd_terminal_width.
        SGND_CONSOLE_LAYOUT_CACHE_KEY=""
        SGND_CONSOLE_LABEL_WIDTH_CACHE_SIGNATURE=""
        return 0
    }
    # fn: _sgnd_console_quit - Request menu termination
        # . Returns
        #   200, the menu termination sentinel.
        #
        # . Usage
        #   _sgnd_console_quit
    _sgnd_console_quit() {
        return 200
    }
    # fn: _sgnd_console_nextpage - Move to the next menu page
        # . Behavior
        #   - Rebuilds page boundaries when required.
        #   - Advances SGND_PAGE_INDEX only when another page exists.
        #
        # Outputs (globals):
        #   SGND_PAGE_INDEX
        #
        # . Returns
        #   0 after applying navigation.
        #
        # . Usage
        #   _sgnd_console_nextpage
    _sgnd_console_nextpage() {
        _sgnd_console_build_pages

        if (( SGND_PAGE_INDEX < ${#SGND_PAGE_STARTS[@]} - 1 )); then
            SGND_PAGE_INDEX=$(( SGND_PAGE_INDEX + 1 ))
        fi

        return 0
    }
    # fn: _sgnd_console_prevpage - Move to the previous menu page
        # Outputs (globals):
        #   SGND_PAGE_INDEX
        #
        # . Returns
        #   0 after applying navigation.
        #
        # . Usage
        #   _sgnd_console_prevpage
    _sgnd_console_prevpage() {
        if (( SGND_PAGE_INDEX > 0 )); then
            SGND_PAGE_INDEX=$(( SGND_PAGE_INDEX - 1 ))
        fi

        return 0
    }
# - Menu model cache ---------------------------------------------------------------
    # fn: _sgnd_console_refresh_model_cache - Materialize menu datatables into indexed caches
        # . Purpose
        #   Convert registered group/item rows into direct-index arrays used by layout and rendering.
        #
        # . Behavior
        #   - Rebuilds only when the registered group or item count changes.
        #   - Splits each datatable row once per rebuild.
        #   - Increments SGND_CONSOLE_MODEL_CACHE_GENERATION after rebuilding.
        #
        # Outputs (globals):
        #   SGND_GROUP_CACHE_*, SGND_ITEM_CACHE_*, and model-cache generation/count values.
        #
        # . Returns
        #   0 after rebuilding or when the cache is already current.
        #
        # . Usage
        #   _sgnd_console_refresh_model_cache
    _sgnd_console_refresh_model_cache() {
        local group_count="${#SGND_GROUP_ROWS[@]}"
        local item_count="${#SGND_ITEM_ROWS[@]}"
        local i
        local row=""
        local key=""
        local label=""
        local desc=""
        local source=""
        local builtin="0"
        local visible="1"
        local ord="1000"
        local group=""
        local handler=""
        local waitsecs="15"
        local indent="0"
        local status=""

        if (( SGND_CONSOLE_MODEL_CACHE_GROUP_COUNT == group_count &&
              SGND_CONSOLE_MODEL_CACHE_ITEM_COUNT == item_count )); then
            return 0
        fi

        SGND_GROUP_CACHE_KEY=()
        SGND_GROUP_CACHE_LABEL=()
        SGND_GROUP_CACHE_SOURCE=()
        SGND_GROUP_CACHE_BUILTIN=()
        SGND_GROUP_CACHE_VISIBLE=()
        SGND_GROUP_CACHE_ORD=()
        SGND_GROUP_CACHE_INDEX_BY_KEY=()

        for (( i=0; i<group_count; i++ )); do
            row="${SGND_GROUP_ROWS[$i]}"
            IFS='|' read -r key label desc source builtin visible ord <<< "$row"

            SGND_GROUP_CACHE_KEY[$i]="$key"
            SGND_GROUP_CACHE_LABEL[$i]="$label"
            SGND_GROUP_CACHE_SOURCE[$i]="$source"
            SGND_GROUP_CACHE_BUILTIN[$i]="${builtin:-0}"
            SGND_GROUP_CACHE_VISIBLE[$i]="${visible:-1}"
            SGND_GROUP_CACHE_ORD[$i]="${ord:-1000}"
            SGND_GROUP_CACHE_INDEX_BY_KEY["$key"]="$i"
        done

        SGND_ITEM_CACHE_KEY=()
        SGND_ITEM_CACHE_GROUP=()
        SGND_ITEM_CACHE_LABEL=()
        SGND_ITEM_CACHE_HANDLER=()
        SGND_ITEM_CACHE_DESC=()
        SGND_ITEM_CACHE_SOURCE=()
        SGND_ITEM_CACHE_BUILTIN=()
        SGND_ITEM_CACHE_WAITSECS=()
        SGND_ITEM_CACHE_VISIBLE=()
        SGND_ITEM_CACHE_INDENT=()
        SGND_ITEM_CACHE_STATUS=()

        for (( i=0; i<item_count; i++ )); do
            row="${SGND_ITEM_ROWS[$i]}"
            IFS='|' read -r key group label handler desc source builtin waitsecs visible indent status <<< "$row"

            SGND_ITEM_CACHE_KEY[$i]="$key"
            SGND_ITEM_CACHE_GROUP[$i]="$group"
            SGND_ITEM_CACHE_LABEL[$i]="$label"
            SGND_ITEM_CACHE_HANDLER[$i]="$handler"
            SGND_ITEM_CACHE_DESC[$i]="$desc"
            SGND_ITEM_CACHE_SOURCE[$i]="$source"
            SGND_ITEM_CACHE_BUILTIN[$i]="${builtin:-0}"
            SGND_ITEM_CACHE_WAITSECS[$i]="${waitsecs:-15}"
            SGND_ITEM_CACHE_VISIBLE[$i]="${visible:-1}"
            SGND_ITEM_CACHE_INDENT[$i]="${indent:-0}"
            SGND_ITEM_CACHE_STATUS[$i]="${status:-}"
        done

        SGND_CONSOLE_MODEL_CACHE_GROUP_COUNT="$group_count"
        SGND_CONSOLE_MODEL_CACHE_ITEM_COUNT="$item_count"
        SGND_CONSOLE_MODEL_CACHE_GENERATION=$(( SGND_CONSOLE_MODEL_CACHE_GENERATION + 1 ))
        return 0
    }

# - Menu model indexes -------------------------------------------------------------
    # fn: _sgnd_console_collect_group_render_indexes - Build ordered group indexes for the active source
        # . Purpose
        #   Build the cached group order used by the renderer for the currently active module source.
        #
        # . Behavior
        #   - Includes builtin groups and groups belonging to SGND_MENU_ACTIVE_SOURCE.
        #   - Sorts groups by configured order and original row position.
        #   - Reuses the cache until the menu model or active source changes.
        #
        # Outputs (globals):
        #   SGND_GROUP_RENDER_INDEXES and group-index cache metadata.
        #
        # . Returns
        #   0 after collecting indexes.
        #
        # . Usage
        #   _sgnd_console_collect_group_render_indexes
    _sgnd_console_collect_group_render_indexes() {
        _sgnd_console_refresh_model_cache

        if (( SGND_CONSOLE_GROUP_INDEX_CACHE_GENERATION == SGND_CONSOLE_MODEL_CACHE_GENERATION )) && \
           [[ "${SGND_CONSOLE_GROUP_INDEX_CACHE_SOURCE:-}" == "${SGND_MENU_ACTIVE_SOURCE:-}" ]]; then
            return 0
        fi

        local i
        local row_count=0
        local builtin="0"
        local ord="1000"
        local source=""

        local -a sortable_rows=()
        local -a sorted_rows=()

        SGND_GROUP_RENDER_INDEXES=()

        row_count="${#SGND_GROUP_ROWS[@]}"

        for (( i=0; i<row_count; i++ )); do
            builtin="${SGND_GROUP_CACHE_BUILTIN[$i]}"
            ord="${SGND_GROUP_CACHE_ORD[$i]}"
            source="${SGND_GROUP_CACHE_SOURCE[$i]:-}"

            if (( ! builtin )) && [[ -n "${SGND_MENU_ACTIVE_SOURCE:-}" && "$source" != "$SGND_MENU_ACTIVE_SOURCE" ]]; then
                continue
            fi
            : "${ord:=1000}"

            # sort key = builtin bucket | ord | original row index
            # non-builtin first, builtin last
            sortable_rows+=("$(printf '%d|%08d|%08d' "$builtin" "$ord" "$i")")
        done

        if (( ${#sortable_rows[@]} == 0 )); then
            return 0
        fi

        mapfile -t sorted_rows < <(printf '%s\n' "${sortable_rows[@]}" | sort -t '|' -k1,1n -k2,2n -k3,3n)

        for i in "${!sorted_rows[@]}"; do
            SGND_GROUP_RENDER_INDEXES+=("$((10#${sorted_rows[$i]##*|}))")
        done

        SGND_CONSOLE_GROUP_INDEX_CACHE_GENERATION="$SGND_CONSOLE_MODEL_CACHE_GENERATION"
        SGND_CONSOLE_GROUP_INDEX_CACHE_SOURCE="${SGND_MENU_ACTIVE_SOURCE:-}"
    }
    # fn: _sgnd_console_collect_visible_item_indexes - Build visible item indexes for the active source
        # . Purpose
        #   Cache menu rows that may be rendered or selected on the active module page.
        #
        # . Behavior
        #   - Filters non-builtin items by SGND_MENU_ACTIVE_SOURCE.
        #   - Includes visible and disabled-rendered states; excludes hidden rows.
        #   - Invalidates dependent layout caches when the visible signature changes.
        #
        # Outputs (globals):
        #   SGND_VISIBLE_ITEM_INDEXES and visibility-cache metadata.
        #
        # . Returns
        #   0 after collecting indexes.
        #
        # . Usage
        #   _sgnd_console_collect_visible_item_indexes
    _sgnd_console_collect_visible_item_indexes() {
        _sgnd_console_refresh_model_cache

        local gi
        local ii
        local item_row_count=0
        local group_key=""
        local group_builtin="0"
        local group_state="1"
        local item_group=""
        local item_builtin="0"
        local item_state="1"
        local item_source=""
        local visible_signature=""

        SGND_VISIBLE_ITEM_INDEXES=()

        _sgnd_console_collect_group_render_indexes
        item_row_count="${#SGND_ITEM_ROWS[@]}"

        for gi in "${SGND_GROUP_RENDER_INDEXES[@]}"; do
            group_builtin="${SGND_GROUP_CACHE_BUILTIN[$gi]}"
            (( group_builtin )) && continue

            group_state="${SGND_GROUP_CACHE_VISIBLE[$gi]}"
            (( group_state != 0 )) || continue


            group_key="${SGND_GROUP_CACHE_KEY[$gi]}"

            for (( ii=0; ii<item_row_count; ii++ )); do
                item_group="${SGND_ITEM_CACHE_GROUP[$ii]}"
                [[ "$item_group" == "$group_key" ]] || continue

                item_builtin="${SGND_ITEM_CACHE_BUILTIN[$ii]}"
                (( item_builtin )) && continue

                item_source="${SGND_ITEM_CACHE_SOURCE[$ii]:-}"
                if [[ -n "${SGND_MENU_ACTIVE_SOURCE:-}" && "$item_source" != "$SGND_MENU_ACTIVE_SOURCE" ]]; then
                    continue
                fi

                item_state="${SGND_ITEM_CACHE_VISIBLE[$ii]}"
                case "$item_state" in
                    1|2)
                        SGND_VISIBLE_ITEM_INDEXES+=("$ii")
                        ;;
                esac
            done
        done

        visible_signature="${SGND_VISIBLE_ITEM_INDEXES[*]}"
        if [[ "$visible_signature" != "$SGND_CONSOLE_VISIBLE_INDEX_CACHE_SIGNATURE" ]]; then
            SGND_CONSOLE_VISIBLE_INDEX_CACHE_SIGNATURE="$visible_signature"
            SGND_CONSOLE_VISIBLE_INDEX_CACHE_GENERATION=$(( SGND_CONSOLE_VISIBLE_INDEX_CACHE_GENERATION + 1 ))
        fi
    }
    # fn: _sgnd_console_visible_item_count - Return the visible item count
        # . Output
        #   Writes the number of currently visible/renderable menu items to stdout.
        #
        # . Returns
        #   0 after counting.
        #
        # . Usage
        #   count="$(_sgnd_console_visible_item_count)"
    _sgnd_console_visible_item_count() {
        printf '%s\n' "${#SGND_VISIBLE_ITEM_INDEXES[@]}"
    }
    # fn: _sgnd_console_get_visible_row_index - Resolve a visible position to its model row
        # . Arguments
        #   $1  VISIBLE_INDEX - Zero-based position in SGND_VISIBLE_ITEM_INDEXES.
        #
        # . Output
        #   Writes the corresponding SGND_ITEM_ROWS index to stdout.
        #
        # . Returns
        #   0 when resolved; 1 when the position is out of range.
        #
        # . Usage
        #   row="$(_sgnd_console_get_visible_row_index 0)"
    _sgnd_console_get_visible_row_index() {
        local visible_index="${1:?missing visible index}"

        if (( visible_index < 0 || visible_index >= ${#SGND_VISIBLE_ITEM_INDEXES[@]} )); then
            return 1
        fi

        printf '%s\n' "${SGND_VISIBLE_ITEM_INDEXES[$visible_index]}"
    }
    # fn: _sgnd_menu_module_chapter - Derive the page chapter from a module source
        # . Purpose
        #   Group ordered console modules by their tens prefix: 10/15, 20/25, 30/35, etc.
        #
        # . Arguments
        #   $1  SOURCE - Module source/id beginning with an optional numeric prefix.
        #
        # . Output
        #   Numeric chapter identifier. Sources without a numeric prefix use chapter 0.
        # . Usage
        #   _sgnd_menu_module_chapter "<source>"
    _sgnd_menu_module_chapter() {
        local source="${1:-}"
        local module_number=""

        if [[ "$source" =~ ^([0-9]+) ]]; then
            module_number="${BASH_REMATCH[1]}"
            printf '%s\n' "$(( 10#$module_number / 10 ))"
            return 0
        fi

        printf '0\n'
    }

    # fn: _sgnd_console_get_visible_display_number - Return an item's chapter-local display number
        # . Purpose
        #   Convert a model row index into the numeric key shown to the user, resetting numbering when the module chapter changes.
        #
        # . Arguments
        #   $1  ROW_INDEX - Index in SGND_ITEM_ROWS.
        #
        # . Output
        #   Writes the one-based display number to stdout.
        #
        # . Returns
        #   0 when the row is visible; 1 otherwise.
        #
        # . Usage
        #   number="$(_sgnd_console_get_visible_display_number "$row_index")"
    _sgnd_console_get_visible_display_number() {
        local row_index="${1:?missing row index}"
        local i
        local visible_row=0
        local chapter=""
        local current_chapter=""
        local display_number=0

        for (( i=0; i<${#SGND_VISIBLE_ITEM_INDEXES[@]}; i++ )); do
            visible_row="${SGND_VISIBLE_ITEM_INDEXES[$i]}"
            chapter="$(_sgnd_menu_module_chapter "${SGND_ITEM_CACHE_SOURCE[$visible_row]:-}")"

            if [[ "$chapter" != "$current_chapter" ]]; then
                current_chapter="$chapter"
                display_number=0
            fi

            display_number=$((display_number + 1))
            if [[ "$visible_row" == "$row_index" ]]; then
                printf '%s\n' "$display_number"
                return 0
            fi
        done

        return 1
    }
    # fn: _sgnd_console_find_visible_pos_for_row - Find a model row in the visible index
        # . Arguments
        #   $1  ROW_INDEX - Index in SGND_ITEM_ROWS.
        #
        # . Output
        #   Writes the zero-based visible position to stdout.
        #
        # . Returns
        #   0 when found; 1 when the row is not visible.
        #
        # . Usage
        #   pos="$(_sgnd_console_find_visible_pos_for_row "$row_index")"
    _sgnd_console_find_visible_pos_for_row() {
        local row_index="${1:?missing row index}"
        local i

        for (( i=0; i<${#SGND_VISIBLE_ITEM_INDEXES[@]}; i++ )); do
            if [[ "${SGND_VISIBLE_ITEM_INDEXES[$i]}" == "$row_index" ]]; then
                printf '%s\n' "$i"
                return 0
            fi
        done

        return 1
    }
    # fn: _sgnd_console_group_continues_after_visible_pos - Test whether a group continues later in the visible list
        # . Arguments
        #   $1  GROUP_KEY        - Group to test.
        #   $2  LAST_VISIBLE_POS - Visible position after which to search.
        #
        # . Returns
        #   0 when another visible row belongs to GROUP_KEY; 1 otherwise.
        #
        # . Usage
        #   _sgnd_console_group_continues_after_visible_pos "storage" 4
    _sgnd_console_group_continues_after_visible_pos() {
        local group_key="${1:?missing group key}"
        local last_visible_pos="${2:?missing visible position}"
        local i
        local row_index=0
        local item_group=""

        for (( i=last_visible_pos + 1; i<${#SGND_VISIBLE_ITEM_INDEXES[@]}; i++ )); do
            row_index="${SGND_VISIBLE_ITEM_INDEXES[$i]}"
            item_group="${SGND_ITEM_CACHE_GROUP[$row_index]}"

            if [[ "$item_group" == "$group_key" ]]; then
                return 0
            fi
        done

        return 1
    }
# - Menu layout measurement --------------------------------------------------------
    # fn: _sgnd_console_body_height - Return the usable menu-body height
        # . Purpose
        #   Determine how many rendered lines may be allocated to one menu page.
        #
        # . Output
        #   Writes the effective body height to stdout.
        #
        # . Returns
        #   0 after calculating the height.
        #
        # . Usage
        #   height="$(_sgnd_console_body_height)"
    _sgnd_console_body_height() {
        local body_height="${SGND_PAGE_MAX_ROWS:-25}"

        (( body_height < 5 )) && body_height=5
        printf '%s\n' "$body_height"
    }
    # fn: _sgnd_console_measure_item_lines - Measure one rendered menu item
        # . Arguments
        #   $1  ROW_INDEX - Item row to measure.
        #
        # . Output
        #   Writes the number of terminal lines required by the item and wrapped description.
        #
        # . Returns
        #   0 after measuring.
        #
        # . Usage
        #   lines="$(_sgnd_console_measure_item_lines "$row_index")"
    _sgnd_console_measure_item_lines() {
        local row_index="${1:?missing row index}"
        local desc=""
        local term_width=80
        local left_width_max="${SGND_RENDER_LABEL_WIDTH:-28}"
        local gap=3
        local tpad=3
        local desc_width=0
        local wrapped_count=0
        local line=""

        desc="${SGND_ITEM_CACHE_DESC[$row_index]}"

        if [[ -z "$desc" ]]; then
            printf '1\n'
            return 0
        fi

        term_width="$(sgnd_terminal_width)"
        desc_width=$(( term_width - tpad - left_width_max - gap ))
        (( desc_width < 20 )) && desc_width=20

        while IFS= read -r line; do
            wrapped_count=$(( wrapped_count + 1 ))
        done < <(sgnd_wrap_words --width "$desc_width" --text "$desc")

        (( wrapped_count < 1 )) && wrapped_count=1
        printf '%s\n' "$wrapped_count"
    }
    # fn: _sgnd_console_measure_group_header_lines - Return group-header height
        # . Output
        #   Writes the fixed two-line group-header height to stdout.
        #
        # . Returns
        #   0 after rendering the value.
        #
        # . Usage
        #   lines="$(_sgnd_console_measure_group_header_lines)"
    _sgnd_console_measure_group_header_lines() {
        # group label + underline
        printf '2\n'
    }
    # fn: _sgnd_console_display_key_width - Calculate the width of visible numeric menu keys
        # . Purpose
        #   Keep item labels aligned when a menu contains multi-digit selections.
        #
        # . Output
        #   Writes the number of character columns required by the widest visible numeric key.
        #
        # . Returns
        #   0 after calculating the width.
        # . Usage
        #   _sgnd_console_display_key_width
    _sgnd_console_display_key_width() {
        local row_index=0
        local display_key=""
        local width=1
        local key_width=0

        _sgnd_console_collect_visible_item_indexes

        for row_index in "${SGND_VISIBLE_ITEM_INDEXES[@]}"; do
            display_key="$(_sgnd_console_get_visible_display_number "$row_index" 2>/dev/null || true)"
            [[ -n "$display_key" ]] || continue
            key_width="${#display_key}"
            (( key_width > width )) && width="$key_width"
        done

        printf '%s\n' "$width"
    }

    # fn: _sgnd_console_calc_label_width - Calculate the shared menu label width
        # . Purpose
        #   Find the widest visible item prefix so labels and descriptions align consistently.
        #
        # . Behavior
        #   - Includes display numbers, indentation, and status icons.
        #   - Caps the calculated width at 45 columns.
        #   - Reuses the value until the menu model changes.
        #
        # . Output
        #   Writes the calculated label width to stdout.
        #
        # . Returns
        #   0 after calculating or returning the cached value.
        #
        # . Usage
        #   width="$(_sgnd_console_calc_label_width)"
    _sgnd_console_calc_label_width() {
        _sgnd_console_collect_visible_item_indexes

        local cache_signature="${SGND_CONSOLE_MODEL_CACHE_GENERATION}|${SGND_CONSOLE_VISIBLE_INDEX_CACHE_GENERATION}|${SGND_MENU_ACTIVE_SOURCE:-}"

        if [[ "${SGND_CONSOLE_LABEL_WIDTH_CACHE_SIGNATURE:-}" == "$cache_signature" ]]; then
            printf '%s\n' "$SGND_CONSOLE_LABEL_WIDTH_CACHE_VALUE"
            return 0
        fi

        local i
        local row_count=0
        local builtin="0"
        local display_key=""
        local label=""
        local left_text=""
        local indent=0
        local status=""
        local status_icon=""
        local width=0
        local max_width=0
        local key_width="${SGND_RENDER_KEY_WIDTH:-$(_sgnd_console_display_key_width)}"
        local rendered_key=""

        row_count="${#SGND_ITEM_ROWS[@]}"

        for (( i=0; i<row_count; i++ )); do
            builtin="${SGND_ITEM_CACHE_BUILTIN[$i]}"

            if (( builtin )); then
                display_key="${SGND_ITEM_CACHE_KEY[$i]}"
            else
                display_key="$(_sgnd_console_get_visible_display_number "$i" 2>/dev/null)" || continue
            fi

            label="${SGND_ITEM_CACHE_LABEL[$i]}"
            indent="${SGND_ITEM_CACHE_INDENT[$i]:-0}"
            status="${SGND_ITEM_CACHE_STATUS[$i]:-}"
            case "$status" in
                success) status_icon="✓ " ;;
                warning) status_icon="⚠ " ;;
                failed) status_icon="✗ " ;;
                never) status_icon="· " ;;
                *) status_icon="" ;;
            esac
            if (( builtin )); then
                rendered_key="$display_key"
            else
                printf -v rendered_key '%*s' "$key_width" "$display_key"
            fi
            left_text="${rendered_key}) $(printf '%*s' "$(( indent * 2 ))" '')${status_icon}${label}"
            width="$(sgnd_visible_length "$left_text")"

            (( width > max_width )) && max_width="$width"
        done

        (( max_width > 45 )) && max_width=45
        SGND_CONSOLE_LABEL_WIDTH_CACHE_VALUE="$max_width"
        SGND_CONSOLE_LABEL_WIDTH_CACHE_SIGNATURE="$cache_signature"
        printf '%s\n' "$max_width"
    }
# - Menu pagination ----------------------------------------------------------------
    # fn: _sgnd_console_build_pages - Build cached menu page boundaries
        # . Purpose
        #   Partition visible menu rows into pages that fit the current terminal and configured line limit.
        #
        # . Behavior
        #   - Preserves group headers with their first item where possible.
        #   - Starts a new page when the module chapter changes.
        #   - Rebuilds only when layout-affecting inputs change.
        #
        # Outputs (globals):
        #   SGND_PAGE_STARTS, SGND_PAGE_ROWS, row/group offsets and counts, and layout cache state.
        #
        # . Returns
        #   0 after building or reusing the page layout.
        #
        # . Usage
        #   _sgnd_console_build_pages
    _sgnd_console_build_pages() {
        local body_height=0
        local term_width=80
        local label_width=28
        local layout_cache_key=""
        local used_lines=0
        local visible_count=0
        local visible_i=0
        local row_index=0
        local group_key=""
        local current_group=""
        local current_chapter=""
        local item_chapter=""
        local item_lines=0
        local header_lines=0
        local needed_lines=0
        local page_index=0
        local page_row_offset=0
        local page_group_offset=0

        _sgnd_console_collect_group_render_indexes
        _sgnd_console_collect_visible_item_indexes

        visible_count="${#SGND_VISIBLE_ITEM_INDEXES[@]}"
        body_height="$(_sgnd_console_body_height)"
        term_width="$(sgnd_terminal_width)"
        label_width="${SGND_RENDER_LABEL_WIDTH:-28}"
        layout_cache_key="${SGND_CONSOLE_MODEL_CACHE_GENERATION}|${SGND_CONSOLE_VISIBLE_INDEX_CACHE_GENERATION}|${body_height}|${term_width}|${label_width}"

        if [[ "$SGND_CONSOLE_LAYOUT_CACHE_KEY" == "$layout_cache_key" ]]; then
            return 0
        fi

        SGND_PAGE_STARTS=()
        SGND_PAGE_ROW_OFFSETS=()
        SGND_PAGE_ROW_COUNTS=()
        SGND_PAGE_ROWS=()
        SGND_PAGE_GROUP_OFFSETS=()
        SGND_PAGE_GROUP_COUNTS=()
        SGND_PAGE_GROUPS=()

        if (( visible_count == 0 )); then
            SGND_CONSOLE_LAYOUT_CACHE_KEY="$layout_cache_key"
            return 0
        fi

        SGND_PAGE_STARTS+=(0)
        SGND_PAGE_ROW_OFFSETS+=(0)
        SGND_PAGE_GROUP_OFFSETS+=(0)

        for (( visible_i=0; visible_i<visible_count; visible_i++ )); do
            row_index="${SGND_VISIBLE_ITEM_INDEXES[$visible_i]}"
            group_key="${SGND_ITEM_CACHE_GROUP[$row_index]}"
            item_chapter="$(_sgnd_menu_module_chapter "${SGND_ITEM_CACHE_SOURCE[$row_index]:-}")"

            if [[ -n "$current_chapter" && "$item_chapter" != "$current_chapter" && $used_lines -gt 0 ]]; then
                SGND_PAGE_ROW_COUNTS+=("$(( ${#SGND_PAGE_ROWS[@]} - page_row_offset ))")
                SGND_PAGE_GROUP_COUNTS+=("$(( ${#SGND_PAGE_GROUPS[@]} - page_group_offset ))")

                page_index=$(( page_index + 1 ))
                page_row_offset="${#SGND_PAGE_ROWS[@]}"
                page_group_offset="${#SGND_PAGE_GROUPS[@]}"
                SGND_PAGE_STARTS+=("$visible_i")
                SGND_PAGE_ROW_OFFSETS+=("$page_row_offset")
                SGND_PAGE_GROUP_OFFSETS+=("$page_group_offset")
                used_lines=0
                current_group=""
            fi

            current_chapter="$item_chapter"
            item_lines="$(_sgnd_console_measure_item_lines "$row_index")"
            needed_lines="$item_lines"

            if [[ "$group_key" != "$current_group" ]]; then
                header_lines="$(_sgnd_console_measure_group_header_lines)"
                needed_lines=$(( needed_lines + header_lines ))
            fi

            if (( used_lines + needed_lines > body_height && used_lines > 0 )); then
                SGND_PAGE_ROW_COUNTS+=("$(( ${#SGND_PAGE_ROWS[@]} - page_row_offset ))")
                SGND_PAGE_GROUP_COUNTS+=("$(( ${#SGND_PAGE_GROUPS[@]} - page_group_offset ))")

                page_index=$(( page_index + 1 ))
                page_row_offset="${#SGND_PAGE_ROWS[@]}"
                page_group_offset="${#SGND_PAGE_GROUPS[@]}"
                SGND_PAGE_STARTS+=("$visible_i")
                SGND_PAGE_ROW_OFFSETS+=("$page_row_offset")
                SGND_PAGE_GROUP_OFFSETS+=("$page_group_offset")
                used_lines=0
                current_group=""
            fi

            if [[ "$group_key" != "$current_group" ]]; then
                header_lines="$(_sgnd_console_measure_group_header_lines)"
                SGND_PAGE_GROUPS+=("$group_key")
                used_lines=$(( used_lines + header_lines ))
                current_group="$group_key"
            fi

            SGND_PAGE_ROWS+=("$row_index")
            used_lines=$(( used_lines + item_lines ))
        done

        SGND_PAGE_ROW_COUNTS+=("$(( ${#SGND_PAGE_ROWS[@]} - page_row_offset ))")
        SGND_PAGE_GROUP_COUNTS+=("$(( ${#SGND_PAGE_GROUPS[@]} - page_group_offset ))")
        SGND_CONSOLE_LAYOUT_CACHE_KEY="$layout_cache_key"
    }
# - Menu rendering -----------------------------------------------------------------
    # fn: _sgnd_console_render_menu - Render the active menu page
        # . Purpose
        #   Render the title, page indicator, paged module rows, builtin groups, and toggle bar.
        #
        # Outputs (globals):
        #   SGND_RENDER_LABEL_WIDTH.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   _sgnd_console_render_menu
    _sgnd_console_render_menu() {
        _sgnd_console_refresh_model_cache
        local idx=""
        local group_key=""
        local builtin="0"

        #_sgnd_console_refresh_builtin_labels
        _sgnd_console_collect_group_render_indexes
        _sgnd_console_collect_visible_item_indexes
        SGND_RENDER_KEY_WIDTH="$(_sgnd_console_display_key_width)"
        SGND_RENDER_LABEL_WIDTH="$(_sgnd_console_calc_label_width)"

        _sgnd_console_render_menu_title
        _sgnd_console_render_page_header
        _sgnd_console_render_menu_body_paged

        for idx in "${SGND_GROUP_RENDER_INDEXES[@]}"; do
            builtin="${SGND_GROUP_CACHE_BUILTIN[$idx]}"
            (( builtin )) || continue

            group_key="${SGND_GROUP_CACHE_KEY[$idx]}"
            _sgnd_console_render_group "$group_key"
        done

        if _sgnd_flag_is_on "${SGND_MENU_SHOW_TOGGLEBAR:-1}"; then
            _sgnd_console_render_togglebar
        fi
    }
    # fn: _sgnd_console_render_menu_title - Render the console title block
        # . Purpose
        #   Render the console title/version, hostname, description, and surrounding borders.
        #
        # . Behavior
        #   - Places the hostname at the right when both values fit on one line.
        #   - Falls back to title-only rendering when the terminal is too narrow.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   _sgnd_console_render_menu_title
    _sgnd_console_render_menu_title() {
        sgnd_clear

        local width=80
        local pad=4
        local inner_width=0
        local hostname_text=""
        local display_title="$SGND_CONSOLE_TITLE"
        local title_len=0
        local hostname_len=0
        local gap=1
        local title_style=""
        local hostname_style=""
        
        width="$(sgnd_terminal_width)"

        inner_width=$(( width - (pad * 2) ))
        (( inner_width < 1 )) && inner_width=1

        if [[ -n "${SGND_SCRIPT_VERSION:-}" && -n "${SGND_SCRIPT_BUILD:-}" ]]; then
            display_title+=" (v. ${SGND_SCRIPT_VERSION}.${SGND_SCRIPT_BUILD})"
        elif [[ -n "${SGND_SCRIPT_VERSION:-}" ]]; then
            display_title+=" (v. ${SGND_SCRIPT_VERSION})"
        fi

        hostname_text="$(hostname 2>/dev/null || printf '%s' "${HOSTNAME:-unknown}")"
        title_len="$(sgnd_visible_length "$display_title")"
        hostname_len="$(sgnd_visible_length "$hostname_text")"
        title_style="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")"
        hostname_style="$(sgnd_sgr "$SGND_UI_VALUE" "" "$FX_ITALIC")"

        sgnd_print_sectionheader --border "$DL_H" --maxwidth "$width"

        if (( title_len + hostname_len + 1 <= inner_width )); then
            gap=$(( inner_width - title_len - hostname_len ))
            printf '%*s%s%s%s%*s%s%s%s\n' \
                "$pad" "" \
                "$title_style" "$display_title" "$RESET" \
                "$gap" "" \
                "$hostname_style" "$hostname_text" "$RESET"
        else
            sgnd_print --pad "$pad" "${title_style}${display_title}${RESET}" --maxwidth "$width"
        fi

        sgnd_print --pad "$pad" "$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_ITALIC")${SGND_CONSOLE_DESC}" --maxwidth "$width"
        sgnd_print_sectionheader --border "$LN_H" --maxwidth "$width"
        sgnd_print
    }
    # fn: _sgnd_console_render_page_header - Render the current page indicator above the menu body
        # . Purpose
        #   Show page navigation state as a centered section header when the menu spans
        #   more than one page.
        #
        # . Behavior
        #   - Suppresses the page indicator for single-page menus.
        #   - Centers the page text within the current terminal width.
        #   - Uses sgnd_print_sectionheader so page navigation follows framework UI styling.
        #
        # . Returns
        #   0 after rendering or when no page indicator is required.
        #
        # . Usage
        #   _sgnd_console_render_page_header
    _sgnd_console_render_page_header() {
        local page_count=0
        local page_text=""
        local page_text_len=0
        local render_width=80
        local padleft=0

        _sgnd_console_build_pages

        page_count="${#SGND_PAGE_STARTS[@]}"
        (( page_count > 1 )) || return 0

        render_width="$(sgnd_terminal_width)"
        page_text="Page $((SGND_PAGE_INDEX + 1))/$page_count"
        page_text_len="$(sgnd_visible_length "$page_text")"
        padleft=$(( (render_width - page_text_len - 2) / 2 ))
        (( padleft < 0 )) && padleft=0

        sgnd_print_sectionheader \
            --text "$page_text" \
            --textclr "$(sgnd_sgr "$SGND_UI_BOLD" "" "$FX_ITALIC")" \
            --border "$LN_H" \
            --padleft "$padleft" \
            --maxwidth "$render_width"
        sgnd_print

        return 0
    }

    # fn: _sgnd_console_render_menu_body_paged - Render the current page body
        # . Purpose
        #   Select the current page's cached rows/groups and pass them to the row renderer.
        #
        # Outputs (globals):
        #   SGND_PAGE_HAS_PREV and SGND_PAGE_HAS_NEXT.
        #
        # . Returns
        #   0 after rendering or when there are no visible items.
        #
        # . Usage
        #   _sgnd_console_render_menu_body_paged
    _sgnd_console_render_menu_body_paged() {
        local visible_count=0
        local page_row_offset=0
        local page_row_count=0
        local page_group_offset=0
        local page_group_count=0
        local i=0

        local -a page_rows=()
        local -a page_groups=()

        _sgnd_console_collect_group_render_indexes
        _sgnd_console_collect_visible_item_indexes
        _sgnd_console_build_pages

        visible_count="${#SGND_VISIBLE_ITEM_INDEXES[@]}"
        SGND_PAGE_HAS_PREV=0
        SGND_PAGE_HAS_NEXT=0

        if (( visible_count == 0 )); then
            return 0
        fi

        if (( SGND_PAGE_INDEX < 0 || SGND_PAGE_INDEX >= ${#SGND_PAGE_STARTS[@]} )); then
            SGND_PAGE_INDEX=0
        fi

        (( SGND_PAGE_INDEX > 0 )) && SGND_PAGE_HAS_PREV=1
        (( SGND_PAGE_INDEX < ${#SGND_PAGE_STARTS[@]} - 1 )) && SGND_PAGE_HAS_NEXT=1

        page_row_offset="${SGND_PAGE_ROW_OFFSETS[$SGND_PAGE_INDEX]:-0}"
        page_row_count="${SGND_PAGE_ROW_COUNTS[$SGND_PAGE_INDEX]:-0}"
        page_group_offset="${SGND_PAGE_GROUP_OFFSETS[$SGND_PAGE_INDEX]:-0}"
        page_group_count="${SGND_PAGE_GROUP_COUNTS[$SGND_PAGE_INDEX]:-0}"

        for (( i=0; i<page_row_count; i++ )); do
            page_rows+=("${SGND_PAGE_ROWS[$((page_row_offset + i))]}")
        done

        for (( i=0; i<page_group_count; i++ )); do
            page_groups+=("${SGND_PAGE_GROUPS[$((page_group_offset + i))]}")
        done

        _sgnd_console_render_page_rows page_groups page_rows
    }
    # fn: _sgnd_console_render_page_rows - Render selected groups and item rows
        # . Purpose
        #   Render one page using the supplied group keys and model row indexes.
        #
        # . Arguments
        #   $1  PAGE_GROUPS - Name of an array containing group keys.
        #   $2  PAGE_ROWS   - Name of an array containing SGND_ITEM_ROWS indexes.
        #
        # . Behavior
        #   - Renders group headings and separators.
        #   - Applies visible/disabled styling, indentation, status icons, and wrapped descriptions.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   _sgnd_console_render_page_rows page_groups page_rows
    _sgnd_console_render_page_rows() {
        local -n _page_groups="$1"
        local -n _page_rows="$2"

        local group_key=""
        local row_index=0
        local label=""
        local desc=""
        local display_key=""
        local rendered_key=""
        local key_width="${SGND_RENDER_KEY_WIDTH:-1}"
        local item_group=""
        local item_state="1"

        local left_text=""
        local left_width=0
        local left_width_max="${SGND_RENDER_LABEL_WIDTH:-28}"
        local desc_width=0
        local term_width=80
        local gap=3
        local tpad=3

        local label_style=""
        local value_style=""
        local normal_label_style="$(sgnd_sgr "$SGND_UI_LABEL")"
        local normal_value_style="$(sgnd_sgr "$SGND_UI_VALUE" "" "$FX_ITALIC")"
        local disabled_label_style="$(sgnd_sgr "$SGND_UI_DISABLED")"
        local disabled_value_style="$(sgnd_sgr "$SGND_UI_DISABLED" "" "$FX_FAINT" "$FX_ITALIC")"

        local wrapped_line=""
        local first_line=1
        local group_label=""
        local group_label_display=""
        local gi

        local group_last_row_index=-1
        local group_last_visible_pos=-1

        term_width="$(sgnd_terminal_width)"
        desc_width=$(( term_width - tpad - left_width_max - gap ))
        (( desc_width < 20 )) && desc_width=20

        for group_key in "${_page_groups[@]}"; do
            group_label=""
            group_last_row_index=-1
            group_last_visible_pos=-1

            gi="${SGND_GROUP_CACHE_INDEX_BY_KEY[$group_key]:--1}"
            if (( gi >= 0 )); then
                group_label="${SGND_GROUP_CACHE_LABEL[$gi]}"
            fi

            for row_index in "${_page_rows[@]}"; do
                item_group="${SGND_ITEM_CACHE_GROUP[$row_index]}"
                [[ "$item_group" == "$group_key" ]] || continue
                group_last_row_index="$row_index"
            done

            group_label_display="$group_label"

            if (( group_last_row_index >= 0 )); then
                group_last_visible_pos="$(_sgnd_console_find_visible_pos_for_row "$group_last_row_index" 2>/dev/null || printf '%s' '-1')"

                if (( group_last_visible_pos >= 0 )); then
                    if _sgnd_console_group_continues_after_visible_pos "$group_key" "$group_last_visible_pos"; then
                        group_label_display="${group_label} ....."
                    fi
                fi
            fi

            if [[ -n "${group_label_display//[[:space:]]/}" ]]; then
                sgnd_print --text "$group_label_display"
                left_width="$(sgnd_visible_length "$group_label_display")"
                sgnd_print_sectionheader --border "$LN_H" --maxwidth "$term_width"
            fi

            for row_index in "${_page_rows[@]}"; do
                item_group="${SGND_ITEM_CACHE_GROUP[$row_index]}"
                [[ "$item_group" == "$group_key" ]] || continue

                item_state="${SGND_ITEM_CACHE_VISIBLE[$row_index]}"
                case "$item_state" in
                    1|2) ;;
                    *) continue ;;
                esac

                display_key="$(_sgnd_console_get_visible_display_number "$row_index")" || continue

                if (( item_state == 2 )); then
                    label_style="$disabled_label_style"
                    value_style="$disabled_value_style"
                else
                    label_style="$normal_label_style"
                    value_style="$normal_value_style"
                fi

                label="${SGND_ITEM_CACHE_LABEL[$row_index]}"
                desc="${SGND_ITEM_CACHE_DESC[$row_index]}"
                local item_indent="${SGND_ITEM_CACHE_INDENT[$row_index]:-0}"
                local item_status="${SGND_ITEM_CACHE_STATUS[$row_index]:-}"
                local indent_text=""
                local status_text=""
                printf -v indent_text '%*s' "$(( item_indent * 2 ))" ''
                status_text="$(_sgnd_menu_status_text "$item_status" "$label_style")"
                printf -v rendered_key '%*s' "$key_width" "$display_key"
                left_text="${rendered_key}) ${indent_text}${status_text}${label}"

                if [[ -z "$desc" ]]; then
                    printf '%*s%s' "$tpad" "" "$label_style"
                    sgnd_padded_visible "$left_text" "$left_width_max"
                    printf '%s\n' "$RESET"
                    continue
                fi

                first_line=1
                while IFS= read -r wrapped_line; do
                    if (( first_line )); then
                        printf '%*s%s' "$tpad" "" "$label_style"
                        sgnd_padded_visible "$left_text" "$left_width_max"
                        printf '%s%*s%s%s%s\n' \
                            "$RESET" \
                            "$gap" "" \
                            "$value_style" "$wrapped_line" "$RESET"
                        first_line=0
                    else
                        printf '%*s%*s%*s%s%s%s\n' \
                            "$tpad" "" \
                            "$left_width_max" "" \
                            "$gap" "" \
                            "$value_style" "$wrapped_line" "$RESET"
                    fi
                done < <(sgnd_wrap_words --width "$desc_width" --text "$desc")
            done

            sgnd_print
        done
    }
    # fn: _sgnd_console_render_group - Render one complete menu group
        # . Purpose
        #   Render a group and all of its currently renderable items, primarily for builtin groups outside normal paging.
        #
        # . Arguments
        #   $1  GROUP_KEY - Registered group key.
        #
        # . Returns
        #   0 when rendered or when the group has nothing renderable.
        #
        # . Usage
        #   _sgnd_console_render_group "runtime"
    _sgnd_console_render_group() {
        local group_key="${1:?missing group key}"
        local _tpad=3

        local gi
        local ii
        local row_count=0
        local label=""
        local desc=""
        local group_label=""
        local found_group=0
        local group_state=1
        local display_key=""
        local rendered_key=""
        local key_width="${SGND_RENDER_KEY_WIDTH:-1}"
        local item_group=""
        local builtin="0"
        local item_state="1"
        local has_renderable_items=0

        local left_text=""
        local left_width=0
        local left_width_max="${SGND_RENDER_LABEL_WIDTH:-28}"
        local desc_width=0
        local term_width=80
        local gap=3

        local label_style=""
        local value_style=""
        local normal_label_style="$(sgnd_sgr "$SGND_UI_LABEL")"
        local normal_value_style="$(sgnd_sgr "$SGND_UI_VALUE" "" "$FX_ITALIC")"
        local disabled_label_style="$(sgnd_sgr "$SGND_UI_DISABLED")"
        local disabled_value_style="$(sgnd_sgr "$SGND_UI_DISABLED" "" "$FX_FAINT" "$FX_ITALIC")"

        row_count="${#SGND_GROUP_ROWS[@]}"

        for (( gi=0; gi<row_count; gi++ )); do
            if [[ "${SGND_GROUP_CACHE_KEY[$gi]}" == "$group_key" ]]; then
                group_label="${SGND_GROUP_CACHE_LABEL[$gi]}"
                group_state="${SGND_GROUP_CACHE_VISIBLE[$gi]}"
                found_group=1
                break
            fi
        done

        (( found_group )) || return 0
        (( group_state != 0 )) || return 0

        row_count="${#SGND_ITEM_ROWS[@]}"

        for (( ii=0; ii<row_count; ii++ )); do
            item_group="${SGND_ITEM_CACHE_GROUP[$ii]}"
            [[ "$item_group" == "$group_key" ]] || continue

            item_state="${SGND_ITEM_CACHE_VISIBLE[$ii]}"
            case "$item_state" in
                1|2)
                    has_renderable_items=1
                    break
                    ;;
            esac
        done

        (( has_renderable_items )) || return 0

        term_width="$(sgnd_terminal_width)"
        desc_width=$(( term_width - _tpad - left_width_max - gap ))
        (( desc_width < 20 )) && desc_width=20

        if [[ -n "${group_label//[[:space:]]/}" ]]; then
            sgnd_print --text "$group_label"
            left_width="$(sgnd_visible_length "$group_label")"
            sgnd_print_sectionheader --border "$LN_H" --maxwidth "$term_width"
        fi

        row_count="${#SGND_ITEM_ROWS[@]}"

        for (( ii=0; ii<row_count; ii++ )); do
            item_group="${SGND_ITEM_CACHE_GROUP[$ii]}"
            [[ "$item_group" == "$group_key" ]] || continue

            item_state="${SGND_ITEM_CACHE_VISIBLE[$ii]}"
            case "$item_state" in
                1|2) ;;
                *) continue ;;
            esac

            builtin="${SGND_ITEM_CACHE_BUILTIN[$ii]}"

            if (( builtin )); then
                display_key="${SGND_ITEM_CACHE_KEY[$ii]}"
            else
                display_key="$(_sgnd_console_get_visible_display_number "$ii")" || continue
            fi

            if (( item_state == 2 )); then
                label_style="$disabled_label_style"
                value_style="$disabled_value_style"
            else
                label_style="$normal_label_style"
                value_style="$normal_value_style"
            fi

            label="${SGND_ITEM_CACHE_LABEL[$ii]}"
            desc="${SGND_ITEM_CACHE_DESC[$ii]}"
            local item_indent="${SGND_ITEM_CACHE_INDENT[$ii]:-0}"
            local item_status="${SGND_ITEM_CACHE_STATUS[$ii]:-}"
            local indent_text=""
            local status_text=""
            printf -v indent_text '%*s' "$(( item_indent * 2 ))" ''
            status_text="$(_sgnd_menu_status_text "$item_status" "$label_style")"
            if (( builtin )); then
                rendered_key="$display_key"
            else
                printf -v rendered_key '%*s' "$key_width" "$display_key"
            fi
            left_text="${rendered_key}) ${indent_text}${status_text}${label}"

            if [[ -z "$desc" ]]; then
                printf '%*s%s' "$_tpad" "" "$label_style"
                sgnd_padded_visible "$left_text" "$left_width_max"
                printf '%s\n' "$RESET"
                continue
            fi

            local first_line=1
            local wrapped_line=""

            while IFS= read -r wrapped_line; do
                if (( first_line )); then
                    printf '%*s%s' "$_tpad" "" "$label_style"
                    sgnd_padded_visible "$left_text" "$left_width_max"
                    printf '%s%*s%s%s%s\n' \
                        "$RESET" \
                        "$gap" "" \
                        "$value_style" "$wrapped_line" "$RESET"
                    first_line=0
                else
                    printf '%*s%*s%*s%s%s%s\n' \
                        "$_tpad" "" \
                        "$left_width_max" "" \
                        "$gap" "" \
                        "$value_style" "$wrapped_line" "$RESET"
                fi
            done < <(sgnd_wrap_words --width "$desc_width" --text "$desc")
        done

        sgnd_print
    }
    # fn: _sgnd_console_render_togglebar - Render runtime status and keyboard legend
        # . Purpose
        #   Show the current mode, access level, log levels, theme, and direct-key legend beneath the menu.
        #
        # . Behavior
        #   - Centers the status and legend within the active render width.
        #   - Reflects dry-run/commit and standard/root state through the configured UI colors.
        #   - Omits the Q/q Exit legend when SGND_MENU_Q_EXIT is disabled.
        #   - Uses SGND_MENU_ESC_LABEL for the context-specific Esc action label.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   _sgnd_console_render_togglebar
    _sgnd_console_render_togglebar() {
        local render_width=80
        local pad=3
        local gap=3
        local access_value="STANDARD"
        local access_color="$GREEN"
        local mode_value="DRY-RUN"
        local mode_color="${SGND_UI_DRYRUN}"
        local console_value="${SGND_CONSOLE_LOG_LEVEL^^}"
        local file_value="${SGND_FILE_LOG_LEVEL^^}"
        local theme_value=""
        local status_text=""
        local legend_text=""
        local exit_legend=""
        local esc_label="${SGND_MENU_ESC_LABEL:-Previous menu}"
        local visible_len=0
        local left_pad=0
        local legend_len=0
        local legend_pad=0
        local -a status_segments=()
        local segment=""

        render_width="$(sgnd_terminal_width)"

        if ! _sgnd_flag_is_on "${FLAG_DRYRUN:-0}"; then
            mode_value="COMMIT"
            mode_color="${SGND_UI_COMMIT}"
        fi

        if (( EUID == 0 )); then
            access_value="ROOT"
            if _sgnd_flag_is_on "${FLAG_DRYRUN:-0}"; then
                access_color="${SGND_UI_COMMIT}"
            else
                access_color="$RED"
            fi
        elif ! _sgnd_flag_is_on "${FLAG_DRYRUN:-0}"; then
            access_color="${SGND_UI_COMMIT}"
        fi


        # Status text
        theme_value="$(_sgnd_console_theme_name | tr '[:lower:]' '[:upper:]')"
        status_segments+=(
            "$(_sgnd_console_statusword "MODE" "$mode_value" "$mode_color" "M")"
            "$(_sgnd_console_statusword "ACCESS" "$access_value" "$access_color" "A")"
            "$(_sgnd_console_statusword "CONSOLE" "$console_value" "$([[ "$console_value" != "SILENT" ]] && printf '%s' "$GREEN" || printf '%s' "$DARK_GRAY")" "C")"
            "$(_sgnd_console_statusword "FILE" "$file_value" "$([[ "$file_value" != "SILENT" ]] && printf '%s' "$GREEN" || printf '%s' "$DARK_GRAY")" "F")"
            "$(_sgnd_console_statusword "THEME" "$theme_value" "$SGND_UI_TEXT" "T")"
        )

        for segment in "${status_segments[@]}"; do
            [[ -z "$status_text" ]] || status_text+="$(sgnd_string_repeat ' ' "$gap")"
            status_text+="$segment"
        done

        visible_len="$(sgnd_visible_length "$status_text")"
        left_pad=$(( (render_width - visible_len) / 2 ))
        (( left_pad < pad )) && left_pad="$pad"

        sgnd_print_sectionheader --border "$DL_H" --maxwidth "$render_width"
        printf '%*s%s\n' "$left_pad" "" "$status_text"

        # Legend text
        if _sgnd_flag_is_on "${SGND_MENU_Q_EXIT:-1}"; then
            exit_legend="Q/q Exit    "
        fi
        legend_text="$(sgnd_sgr "$SGND_UI_FAINT" "" "$FX_ITALIC")Shift+S Shell    ${exit_legend}Esc ${esc_label}    L Lines/page   R Reset    Ctrl+R Redraw    $KY_LEFT Previous page    $KY_RIGHT Next page${RESET}"
        legend_len="$(sgnd_visible_length "$legend_text")"
        legend_pad=$(( (render_width - legend_len) / 2 ))
        (( legend_pad < pad )) && legend_pad="$pad"

        printf '%*s%s\n' "$legend_pad" "" "$legend_text"
    }

# - Public API ----------------------------------------------------------------------
    # fn: sgnd_menu_create - Initialize a reusable menu model
        # . Purpose
        #   Initialize or reset the menu model used by the caller.
        #
        # . Arguments
        #   $1  TITLE - Menu title.
        #   $2  DESC  - Optional menu description.
        #
        # . Returns
        #   0 after resetting the menu model.
        #
        # . Usage
        #   sgnd_menu_create "Storage Management" "Manage disks and pools"
    sgnd_menu_create() {
        SGND_CONSOLE_TITLE="${1:-${SGND_SCRIPT_TITLE:-SolidGroundUX}}"
        SGND_CONSOLE_DESC="${2:-${SGND_SCRIPT_DESC:-}}"

        SGND_GROUP_SCHEMA="key|label|desc|source|builtin|visible|ord"
        SGND_ITEM_SCHEMA="key|group|label|handler|desc|source|builtin|waitsecs|visible|indent|status"
        declare -g -a SGND_GROUP_ROWS=()
        declare -g -a SGND_ITEM_ROWS=()
        declare -g -a SGND_VISIBLE_ITEM_INDEXES=()
        declare -g -a SGND_GROUP_RENDER_INDEXES=()
        declare -g -a SGND_GROUP_CACHE_KEY=()
        declare -g -a SGND_GROUP_CACHE_LABEL=()
        declare -g -a SGND_GROUP_CACHE_SOURCE=()
        declare -g -a SGND_GROUP_CACHE_BUILTIN=()
        declare -g -a SGND_GROUP_CACHE_VISIBLE=()
        declare -g -a SGND_GROUP_CACHE_ORD=()
        declare -g -A SGND_GROUP_CACHE_INDEX_BY_KEY=()
        declare -g -a SGND_ITEM_CACHE_KEY=()
        declare -g -a SGND_ITEM_CACHE_GROUP=()
        declare -g -a SGND_ITEM_CACHE_LABEL=()
        declare -g -a SGND_ITEM_CACHE_HANDLER=()
        declare -g -a SGND_ITEM_CACHE_DESC=()
        declare -g -a SGND_ITEM_CACHE_SOURCE=()
        declare -g -a SGND_ITEM_CACHE_BUILTIN=()
        declare -g -a SGND_ITEM_CACHE_WAITSECS=()
        declare -g -a SGND_ITEM_CACHE_VISIBLE=()
        declare -g -a SGND_ITEM_CACHE_INDENT=()
        declare -g -a SGND_ITEM_CACHE_STATUS=()

        SGND_PAGE_INDEX=0
        SGND_PAGE_STARTS=()
        SGND_PAGE_ROW_OFFSETS=()
        SGND_PAGE_ROW_COUNTS=()
        SGND_PAGE_ROWS=()
        SGND_PAGE_GROUP_OFFSETS=()
        SGND_PAGE_GROUP_COUNTS=()
        SGND_PAGE_GROUPS=()
        SGND_CONSOLE_LAYOUT_CACHE_KEY=""
        SGND_CONSOLE_MODEL_CACHE_GROUP_COUNT=-1
        SGND_CONSOLE_MODEL_CACHE_ITEM_COUNT=-1
        SGND_CONSOLE_MODEL_CACHE_GENERATION=0
        SGND_CONSOLE_GROUP_INDEX_CACHE_GENERATION=-1
        SGND_CONSOLE_GROUP_INDEX_CACHE_SOURCE=""
        SGND_CONSOLE_VISIBLE_INDEX_CACHE_GENERATION=0
        SGND_CONSOLE_VISIBLE_INDEX_CACHE_SIGNATURE=""
        SGND_CONSOLE_LABEL_WIDTH_CACHE_GENERATION=-1
        SGND_CONSOLE_LABEL_WIDTH_CACHE_SIGNATURE=""
        SGND_CONSOLE_LABEL_WIDTH_CACHE_VALUE=0
        SGND_RENDER_KEY_WIDTH=1
        : "${SGND_PAGE_MAX_ROWS:=25}"
        : "${SGND_MENU_SHOW_TOGGLEBAR:=1}"
        return 0
    }

    # fn: sgnd_menu_register_group - Register a menu group
        # . Purpose
        #   Add a group definition to the reusable menu model.
        #
        # . Arguments
        #   $1  KEY      - Unique group key.
        #   $2  LABEL    - Visible group label.
        #   $3  DESC     - Optional group description.
        #   $4  BUILTIN  - 1 for host-owned groups, otherwise 0.
        #   $5  VISIBLE  - Group visibility state.
        #   $6  ORDER    - Relative group order within the active page.
        #
        # . Returns
        #   0 when registered or already present; non-zero on datatable failure.
        #
        # . Usage
        #   sgnd_menu_register_group "storage" "Storage" "Manage local storage" 0 1 10
    sgnd_menu_register_group() {
        local key="${1:?missing group key}"
        local label="${2-}"
        local desc="${3:-}"
        local builtin="${4:-0}"
        local visible="${5:-1}"
        local ord="${6:-1000}"
        local source="${SGND_CURRENT_MODULE_SOURCE:-${SGND_CURRENT_MODULE:-}}"

        if sgnd_dt_has_row "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS key "$key"; then
            return 0
        fi

        sgnd_dt_append "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS \
            "$key" "$label" "$desc" "$source" "$builtin" "$visible" "$ord"
    }

    # fn: sgnd_menu_register_item - Register one menu item
        # . Purpose
        #   Add an executable item to the reusable menu model.
        #
        # . Arguments
        #   $1  KEY       - Unique menu key.
        #   $2  GROUP     - Owning group key.
        #   $3  LABEL     - Visible item label.
        #   $4  HANDLER   - Function invoked when selected.
        #   $5  DESC      - Optional description.
        #   $6  BUILTIN   - 1 for host-owned controls, otherwise 0.
        #   $7  WAITSECS  - Post-action countdown; normal actions are clamped to a
        #                    minimum of 15 seconds when a non-zero wait is requested.
        #   $8  VISIBLE   - Visibility state.
        #   $9  INDENT    - Item indentation level.
        #   $10 STATUS    - Optional transient status decoration.
        #
        # . Returns
        #   0 when registered; non-zero on validation, duplicate-key, or handler errors.
        #
        # . Usage
        #   sgnd_menu_register_item "status" "system" "Show status" "show_status" "Display current status" 0 15 1 0
    sgnd_menu_register_item() {
        local key="${1:?missing key}"
        local group="${2:-main}"
        local label="${3:?missing label}"
        local handler="${4:?missing handler}"
        local desc="${5:-}"
        local builtin="${6:-0}"
        local waitsecs="${7:-15}"
        local visible="${8:-1}"
        local indent="${9:-0}"
        local status="${10:-}"
        local source="${SGND_CURRENT_MODULE_SOURCE:-${SGND_CURRENT_MODULE:-}}"

        [[ "$waitsecs" =~ ^[0-9]+$ ]] || {
            sayfail "Invalid menu wait time for '$key': $waitsecs"
            return 1
        }
        if (( ! builtin && waitsecs > 0 && waitsecs < 15 )); then
            waitsecs=15
        fi

        [[ "$indent" =~ ^[0-9]+$ ]] || {
            sayfail "Invalid menu indent for '$key': $indent"
            return 1
        }

        if sgnd_dt_has_row "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS key "$key"; then
            sayfail "Duplicate menu key: $key"
            return 1
        fi

        declare -F "$handler" >/dev/null || {
            sayfail "Handler not defined for menu key '$key': $handler"
            return 1
        }

        if ! sgnd_dt_has_row "$SGND_GROUP_SCHEMA" SGND_GROUP_ROWS key "$group"; then
            sgnd_menu_register_group "$group" "$group" "" 0 1 1000 || return $?
        fi

        sgnd_dt_append "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS \
            "$key" "$group" "$label" "$handler" "$desc" "$source" "$builtin" "$waitsecs" "$visible" "$indent" "$status"
    }

    # fn: sgnd_menu_set_item_status - Set menu item status decoration
        # . Purpose
        #   Update the transient status associated with a registered menu item.
        #
        # . Arguments
        #   $1  ITEM_KEY - Registered menu item key.
        #   $2  STATUS   - never, success, warning, failed, or empty.
        #
        # . Returns
        #   0 when updated; 1 when the item does not exist or status is invalid.
        #
        # . Usage
        #   sgnd_menu_set_item_status "storage-status" "success"
    sgnd_menu_set_item_status() {
        local item_key="${1:?missing item key}"
        local status="${2:-}"
        local i
        local row_count="${#SGND_ITEM_ROWS[@]}"

        case "$status" in
            ""|never|success|warning|failed) ;;
            *) return 1 ;;
        esac

        for (( i=0; i<row_count; i++ )); do
            if [[ "$(sgnd_dt_get "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$i" key)" == "$item_key" ]]; then
                sgnd_dt_set "$SGND_ITEM_SCHEMA" SGND_ITEM_ROWS "$i" status "$status" || return 1
                SGND_CONSOLE_MODEL_CACHE_ITEM_COUNT=-1
                return 0
            fi
        done

        return 1
    }

    # fn: _sgnd_menu_status_text - Build a colored status icon
        # . Arguments
        #   $1  STATUS      - never, success, warning, failed, or empty.
        #   $2  LABEL_STYLE - Style restored after the icon.
        #
        # . Output
        #   Writes the styled icon plus trailing space, or nothing for an empty/unknown status.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   _sgnd_menu_status_text "success" "$label_style"
    _sgnd_menu_status_text() {
        local status="${1:-}"
        local label_style="${2:-}"
        local icon=""
        local color=""

        case "$status" in
            success) icon="✓"; color="${SGND_UI_SUCCESS:-${BRIGHT_GREEN:-}}" ;;
            warning) icon="⚠"; color="${BRIGHT_YELLOW:-${YELLOW:-}}" ;;
            failed)  icon="✗"; color="${SGND_UI_ERROR:-${BRIGHT_RED:-}}" ;;
            never)   icon="·"; color="${SGND_UI_DISABLED:-${DARK_WHITE:-}}" ;;
            *) return 0 ;;
        esac

        printf '%s%s%s%s ' "$color" "$icon" "$RESET" "$label_style"
    }

    # fn: sgnd_menu_show_menu - Render the current menu
        # . Purpose
        #   Render the menu model using the shared SolidGroundUX menu renderer.
        #
        # Inputs (globals):
        #   SGND_MENU_SHOW_TOGGLEBAR
        #       1 (default) renders the management-console status/legend bar.
        #       0 renders only the title, groups, items, and page header.
        #
        # . Returns
        #   0 after rendering.
        #
        # . Usage
        #   SGND_MENU_SHOW_TOGGLEBAR=0
        #   sgnd_menu_show_menu
    sgnd_menu_show_menu() {
        _sgnd_console_render_menu
    }

    # Compatibility aliases retained as part of the public API. New modules should use
    # sgnd_menu_register_group/item directly.

    # fn: sgnd_console_register_group - Compatibility alias for sgnd_menu_register_group
        # . Returns
        #   Status returned by sgnd_menu_register_group.
        #
        # . Usage
        #   sgnd_console_register_group "storage" "Storage" "Manage local storage" 0 1 10
    sgnd_console_register_group() { sgnd_menu_register_group "$@"; }

    # fn: sgnd_console_register_item - Compatibility alias for sgnd_menu_register_item
        # . Returns
        #   Status returned by sgnd_menu_register_item.
        #
        # . Usage
        #   sgnd_console_register_item "status" "system" "Show status" "show_status" "Display current status" 0 15 1 0
    sgnd_console_register_item() { sgnd_menu_register_item "$@"; }

# - Menu input and dispatch --------------------------------------------------------

    # fn: sgnd_menu_read_choice - Read one menu choice or navigation key
        # . Purpose
        #   Read menu input directly from /dev/tty and normalize navigation/control keys.
        #
        # . Behavior
        #   - Q/q return EXIT only when SGND_MENU_Q_EXIT is enabled (default).
        #   - When SGND_MENU_Q_EXIT is disabled, Q/q are returned as literal choices and
        #     Ctrl+Q is ignored.
        #   - R/r return RESET.
        #   - Ctrl+R returns REDRAW.
        #   - Esc returns ESC unless followed by a recognized arrow sequence.
        #   - Left/right arrows return < and >.
        #   - Single-character controls are returned immediately.
        #   - Multi-digit numeric selections are completed with Enter.
        #
        # . Arguments
        #   $1  OUTPUT_VAR - Variable receiving the normalized choice.
        #
        # . Returns
        #   0 on input; non-zero when /dev/tty cannot be read.
        #
        # . Usage
        #   sgnd_menu_read_choice choice
    sgnd_menu_read_choice() {
        local output_var="${1:?missing output variable}"
        local key=""
        local seq=""
        local buffer=""

        while true; do
            IFS= read -r -s -n 1 key </dev/tty || return 1

            case "$key" in
                $'\x12') printf -v "$output_var" '%s' 'REDRAW'; printf '\n' >/dev/tty; return 0 ;;
                r|R) printf '%s%s%s\n' "$(sgnd_sgr "$SGND_UI_VALUE")" "$key" "$RESET" >/dev/tty; printf -v "$output_var" '%s' 'RESET'; return 0 ;;
                $'\x11')
                    if _sgnd_flag_is_on "${SGND_MENU_Q_EXIT:-1}"; then
                        printf -v "$output_var" '%s' 'EXIT'
                        printf '\n' >/dev/tty
                        return 0
                    fi
                    ;;
                q|Q)
                    printf '%s%s%s\n' "$(sgnd_sgr "$SGND_UI_VALUE")" "$key" "$RESET" >/dev/tty
                    if _sgnd_flag_is_on "${SGND_MENU_Q_EXIT:-1}"; then
                        printf -v "$output_var" '%s' 'EXIT'
                    else
                        printf -v "$output_var" '%s' "$key"
                    fi
                    return 0
                    ;;
                $'\e')
                    seq=""
                    IFS= read -r -s -n 2 -t 0.05 seq </dev/tty || true
                    case "$seq" in
                        '[D') printf -v "$output_var" '%s' '<' ;;
                        '[C') printf -v "$output_var" '%s' '>' ;;
                        *)   printf -v "$output_var" '%s' 'ESC' ;;
                    esac
                    printf '\n' >/dev/tty
                    return 0
                    ;;
                '')
                    if [[ -n "$buffer" ]]; then
                        printf -v "$output_var" '%s' "$buffer"
                        printf '\n' >/dev/tty
                        return 0
                    fi
                    ;;
                $'\177'|$'\b')
                    if [[ -n "$buffer" ]]; then
                        buffer="${buffer%?}"
                        printf '\b \b' >/dev/tty
                    fi
                    ;;
                [0-9])
                    buffer+="$key"
                    printf '%s%s%s' "$(sgnd_sgr "$SGND_UI_VALUE")" "$key" "$RESET" >/dev/tty
                    ;;
                *)
                    printf '%s%s%s\n' "$(sgnd_sgr "$SGND_UI_VALUE")" "$key" "$RESET" >/dev/tty
                    printf -v "$output_var" '%s' "$key"
                    return 0
                    ;;
            esac
        done
    }

    # fn: sgnd_menu_dispatch - Dispatch a normalized menu choice
        # . Purpose
        #   Execute or navigate the current menu through the public menu API.
        #
        # . Arguments
        #   $1  CHOICE - Normalized choice returned by sgnd_menu_read_choice.
        #
        # Outputs (globals):
        #   SGND_LAST_WAITSECS - Post-action wait configured by the selected item.
        #
        # . Returns
        #   Status returned by the selected menu action or navigation operation.
        #
        # . Usage
        #   sgnd_menu_dispatch "$choice"
    sgnd_menu_dispatch() {
        _sgnd_console_dispatch "$@"
    }

    # fn: _sgnd_console_valid_choices_csv - Build the current valid-choice list
        # . Purpose
        #   Emit a comma-separated list containing visible numeric selections and active
        #   built-in keys for the current menu state.
        #
        # . Output
        #   Writes the comma-separated choice list to stdout.
        #
        # . Returns
        #   0 after building the list.
        #
        # . Usage
        #   choices="$(_sgnd_console_valid_choices_csv)"
    _sgnd_console_valid_choices_csv() {
        local i
        local out=""
        local row_count=0
        local builtin="0"
        local key=""

        _sgnd_console_collect_visible_item_indexes

        for (( i=1; i<=${#SGND_VISIBLE_ITEM_INDEXES[@]}; i++ )); do
            [[ -n "$out" ]] && out+=","
            out+="$i"
        done

        row_count="${#SGND_ITEM_ROWS[@]}"

        for (( i=0; i<row_count; i++ )); do
            builtin="${SGND_ITEM_CACHE_BUILTIN[$i]}"
            (( builtin )) || continue

            key="${SGND_ITEM_CACHE_KEY[$i]}"
            [[ -n "$out" ]] && out+=","
            out+="$key"
        done

        printf '%s' "$out"
    }
    # fn: _sgnd_menu_execute_item - Execute a registered menu item through an optional host executor
        # . Purpose
        #   Execute a registered menu item while allowing a host application to wrap
        #   handler execution with application-specific behavior such as result tracking.
        #
        # . Arguments
        #   $1  ITEM_KEY - Registered menu item key.
        #   $2  HANDLER  - Registered handler function.
        #   $3  BUILTIN  - 1 for host/builtin items, otherwise 0.
        #
        # . Behavior
        #   - Calls the function named by SGND_MENU_ITEM_EXECUTOR when configured.
        #   - Falls back to calling the registered handler directly.
        #   - Keeps sgnd-menu independent from management-console and other host applications.
        #
        # . Returns
        #   Exit status from the host executor or registered handler.
        # . Usage
        #   _sgnd_menu_execute_item "<item_key>" "<handler>" "<builtin>"
    _sgnd_menu_execute_item() {
        local item_key="${1:?missing item key}"
        local handler="${2:?missing handler}"
        local builtin="${3:-0}"
        local executor="${SGND_MENU_ITEM_EXECUTOR:-}"

        if [[ -n "$executor" ]] && declare -F "$executor" >/dev/null 2>&1; then
            "$executor" "$item_key" "$handler" "$builtin"
            return $?
        fi

        "$handler"
    }

    # fn: _sgnd_console_dispatch - Dispatch a normalized menu choice
        # . Purpose
        #   Resolve navigation, lines-per-page, numeric, or direct-key choices against the
        #   current cached menu model and execute the selected handler.
        #
        # . Arguments
        #   $1  CHOICE - Normalized choice returned by sgnd_menu_read_choice.
        #
        # Outputs (globals):
        #   SGND_LAST_WAITSECS - Post-action wait configured by the selected item.
        #
        # . Returns
        #   Exit status from the navigation operation or selected item; 1 for invalid choices.
        #
        # . Usage
        #   _sgnd_console_dispatch "3"
    _sgnd_console_dispatch() {
        _sgnd_console_refresh_model_cache

        SGND_LAST_WAITSECS=0
        local choice="${1:-}"
        if [[ -z "$choice" ]]; then
            saywarning "Invalid selection"
            return 1
        fi
        local handler=""
        local label=""
        local state="1"
        local row_index=0
        local i
        local row_count=0
        local key=""

        case "$choice" in
            '<')
                _sgnd_console_prevpage
                return $?
                ;;
            '>')
                _sgnd_console_nextpage
                return $?
                ;;
            L|l)
                _sgnd_console_set_lines_per_page
                return $?
                ;;
        esac

        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            local page_row_offset=0
            local page_row_count=0
            local page_i=0
            local display_number=""

            _sgnd_console_build_pages
            page_row_offset="${SGND_PAGE_ROW_OFFSETS[$SGND_PAGE_INDEX]:-0}"
            page_row_count="${SGND_PAGE_ROW_COUNTS[$SGND_PAGE_INDEX]:-0}"
            row_index=-1

            for (( page_i=0; page_i<page_row_count; page_i++ )); do
                i="${SGND_PAGE_ROWS[$((page_row_offset + page_i))]}"
                display_number="$(_sgnd_console_get_visible_display_number "$i" 2>/dev/null || true)"
                if [[ "$display_number" == "$choice" ]]; then
                    row_index="$i"
                    break
                fi
            done

            if (( row_index < 0 )); then
                saywarning "Invalid selection on this page: $choice"
                return 1
            fi

            label="${SGND_ITEM_CACHE_LABEL[$row_index]}"
            state="${SGND_ITEM_CACHE_VISIBLE[$row_index]}"

            if (( state == 2 )); then
                saywarning "Option disabled: $label"
                return 1
            fi

            handler="${SGND_ITEM_CACHE_HANDLER[$row_index]}"
            SGND_LAST_WAITSECS="${SGND_ITEM_CACHE_WAITSECS[$row_index]}"
            _sgnd_menu_execute_item \
                "${SGND_ITEM_CACHE_KEY[$row_index]}" \
                "$handler" \
                "${SGND_ITEM_CACHE_BUILTIN[$row_index]:-0}"
            return $?
        fi

        row_count="${#SGND_ITEM_ROWS[@]}"

        for (( i=0; i<row_count; i++ )); do
            key="${SGND_ITEM_CACHE_KEY[$i]}"

            if [[ "${choice^^}" == "${key^^}" ]]; then
                state="${SGND_ITEM_CACHE_VISIBLE[$i]}"
                label="${SGND_ITEM_CACHE_LABEL[$i]}"

                if (( state == 2 )); then
                    saywarning "Option disabled: $label"
                    return 1
                fi

                handler="${SGND_ITEM_CACHE_HANDLER[$i]}"
                SGND_LAST_WAITSECS="${SGND_ITEM_CACHE_WAITSECS[$i]}"
                _sgnd_menu_execute_item \
                    "$key" \
                    "$handler" \
                    "${SGND_ITEM_CACHE_BUILTIN[$i]:-0}"
                return $?
            fi
        done

        saywarning "Invalid selection: $choice"
        return 1
    }


