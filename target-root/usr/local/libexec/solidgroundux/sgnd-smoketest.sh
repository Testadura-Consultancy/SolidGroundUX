#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX Framework - Smoke Test and Validation
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Source      : sgnd-smoketest.sh
#   Wrapper     : sgnd-smoketest
#   Type        : script
#   Group       : Console Actions
#   Purpose     : Validate the framework and exercise its interactive UI helpers
#
#   Build : 2627412
#   Checksum : da8eefaf6795212bd62c046b359c577d8ad3dc2da48fe1aefc4c948a6621efd3
# Description:
#   Framework-owned smoke-test and validation implementation for SolidGroundUX. Supports individual validation suites, a complete Run All
#   pass, and the original interactive UI smoke-test menu.
#
# Design principles:
#   - Validation suites are non-destructive.
#   - Console registration is tested after explicitly loading all discovered modules,
#     avoiding false failures caused by the Management Console's lazy-loading model.
#   - Existing module validators remain owned by their respective modules and are
#     invoked rather than duplicated here.
#   - Test sections use one consistent finish and summary pattern.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail

# - Bootstrap -----------------------------------------------------------------------
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

# - Script identity -----------------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    SGND_SCRIPT_DESC="SolidGroundUX framework smoke test and validation suite"
    SGND_SCRIPT_VERSION="2.1"

# - Framework integration ----------------------------------------------------------
    SGND_USING=(
        sgnd-datatable.sh
        sgnd-menu.sh
    )

    SGND_ARGS_SPEC=(
        "suite|s|enum|ENUM_SUITE|Test suite to run||smoke,installation,all"
        "view-log||flag|FLAG_VIEW_LOG|Display the active SolidGroundUX logfile and exit|"
    )

    SGND_SCRIPT_EXAMPLES=(
        "Interactive smoke tests:"
        "  $SGND_SCRIPT_NAME --suite smoke"
        ""
        "Run all framework-owned tests:"
        "  $SGND_SCRIPT_NAME --suite all"
    )

    SGND_SCRIPT_GLOBALS=()
    SGND_ON_EXIT_HANDLERS=()
    SGND_STATE_SAVE=0
    : "${ENUM_SUITE:=smoke}"

# - Smoke-test input declarations --------------------------------------------------
    : "${INP_NAME:=}"
    : "${INP_STREET:=}"
    : "${INP_ZIPCODE:=}"
    : "${INP_CITY:=}"
    : "${INP_COUNTRY:=}"
    : "${INP_AGE:=}"

    SGND_STATE_VARIABLES=(
        "INP_NAME|Name|Petrus Puk|"
        "INP_STREET|Address|Nowhere straat|"
        "INP_ZIPCODE|Postcode|5544 QU|"
        "INP_CITY|Stad||"
        "INP_COUNTRY|||"
        "INP_AGE|Leeftijd|102|sgnd_is_number"
    )

    # fn: input_test - Run simple shell input tests
        # . Purpose
        #   Run simple shell input tests.
        #
        # . Behavior
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   input_test
    input_test() {
        sgnd_print
        ask_prompt_form --autoalign "${SGND_STATE_VARIABLES[@]}" 
    }


    # fn: ask_selection_test - Run interactive ask_selection tests
        # . Purpose
        #   Exercise single-select and multi-select ask_selection behavior.
        #
        # . Behavior
        #   - Presents one single-select list and reports the selected value.
        #   - Presents one multi-select list and reports all selected values.
        #   - Allows Q to return from either selection prompt.
        #
        # . Returns
        #   0 after both selection tests complete or are cancelled.
        #
        # . Usage
        #   ask_selection_test
    ask_selection_test() {
        local selected_theme=""
        local -a selected_groups=()
        local -a themes=(
            "Default"
            "Dark"
            "Testadura"
            "Steel Blue"
        )
        local -a groups=(
            "Domain Admins"
            "File Server Users"
            "Accounting"
            "Operations"
            "Developers"
        )

        sgnd_print
        sgnd_print_sectionheader --text "Testing ask_selection()"

        sgnd_print "Single-select test"
        ask_selection \
            --label "Theme" \
            --var selected_theme \
            --items "${themes[@]}"

        if [[ -n "$selected_theme" ]]; then
            sgnd_print "Result: selected_theme='$selected_theme'"
        else
            sgnd_print "Result: single-select cancelled"
        fi

        sgnd_print
        sgnd_print "Multi-select test (try 1,3,5 or 2-4)"
        ask_selection \
            --label "Groups" \
            --var selected_groups \
            --multi \
            --items "${groups[@]}"

        if (( ${#selected_groups[@]} > 0 )); then
            sgnd_print_labeledmultivalue \
                --label "Selected groups" \
                --items "${selected_groups[@]}"
        else
            sgnd_print "Result: multi-select cancelled"
        fi

        return 0
    }

    # fn: ask_test - Run interactive ask helper tests
        # . Purpose
        #   Run interactive ask helper tests.
        #
        # . Behavior
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   ask_test
    ask_test(){
        sgnd_print
        # -----------------------------------------------------------------------------
        # 1. ask
        # -----------------------------------------------------------------------------
        sgnd_print " 1. Testing ask()"

        TEST_NAME=""
        ask \
            --label "Your name" \
            --default "Mark" \
            --validate sgnd_validate_text \
            --var TEST_NAME \
            --labelwidth 28 \
            --pad 2 \
            --colorize both

        sgnd_print "Result: TEST_NAME=$TEST_NAME"

        # -----------------------------------------------------------------------------
        # 2. ask_datetime
        # -----------------------------------------------------------------------------
        sgnd_print " 2. Testing ask_datetime()"
        sgnd_print "Enter an absolute datetime or a shorthand such as N, D, -2h, or +30m.\n"

        TEST_DATETIME=""
        TEST_RC=0

        while true; do
            ask_datetime \
                --label "Changed after" \
                --default "-2h" \
                --var TEST_DATETIME \
                --labelwidth 28 \
                --pad 2 \
                --colorize both

            sgnd_print "Result: TEST_DATETIME='$TEST_DATETIME'"

            ask_dlg_autocontinue \
                --seconds 8 \
                --message "Press Enter to continue, or R to repeat ask_datetime." \
                --redo \
                --pause

            TEST_RC=$?
            case "$TEST_RC" in
                0)
                    break
                    ;;
                1|3)
                    sgnd_print "Repeating ask_datetime test.\n"
                    ;;
                *)
                    sgnd_print "Unexpected response rc=$TEST_RC; repeating ask_datetime test.\n"
                    ;;
            esac
        done

        # -----------------------------------------------------------------------------
        # 3. ask_decision
        # -----------------------------------------------------------------------------
        sgnd_print " 3. Testing ask_decision()"

        TEST_DECISION=""
        ask_decision \
            --label "Proceed with operation?" \
            --choices "YES|Y,NO|N" \
            --default "YES" \
            --var TEST_DECISION \
            --labelwidth 28 \
            --pad 2 

        sgnd_print "Result: TEST_DECISION='$TEST_DECISION'"

        # -----------------------------------------------------------------------------
        # 4. ask_dlg_autocontinue
        # -----------------------------------------------------------------------------
        sgnd_print " 4. Testing ask_dlg_autocontinue()"
        sgnd_print "Try Enter, R, C, P/Space, or do nothing and let it time out.\n"

        ask_dlg_autocontinue \
            --seconds 8 \
            --message "Auto-continue test" \
            --redo \
            --cancel \
            --pause

        TEST_RC=$?

        case "$TEST_RC" in
            0) sgnd_print "Result: continue\n\n" ;;
            1) sgnd_print "Result: timeout / auto-continue\n\n" ;;
            2) sgnd_print "Result: cancel\n\n" ;;
            3) sgnd_print "Result: redo\n\n" ;;
            *) sgnd_print "Result: unexpected rc=%s\n\n" "$TEST_RC" ;;
        esac

        # -----------------------------------------------------------------------------
        # 5. ask_choose
        # -----------------------------------------------------------------------------
        sgnd_print " 5. Testing ask_choose()"

        TEST_ENV=""
        ask_choose \
            --label "Environment" \
            --choices "dev,acc,prod" \
            --var TEST_ENV \
            --labelwidth 28 \
            --pad 2 

        sgnd_print "Result: TEST_ENV='$TEST_ENV'"

        # -----------------------------------------------------------------------------
        # 6. ask_choose_immediate
        # -----------------------------------------------------------------------------
        sgnd_print " 6. Testing ask_choose_immediate()"
        sgnd_print "Instant choices: B,D,Q. Other values require Enter.\n"

        TEST_ACTION=""
        ask_choose_immediate \
            --label "Action" \
            --choices "1-5,B,D,Q" \
            --instantchoices "B,D,Q" \
            --var TEST_ACTION

        sgnd_print "Result: TEST_ACTION='$TEST_ACTION'"

        # -----------------------------------------------------------------------------
        # Optional: ask_prompt_form
        # -----------------------------------------------------------------------------
        # Uncomment this block if you want to test ask_prompt_form too.
        #
        # _ask_parse_fieldspec() {
        #     local spec="${1-}"
        #     IFS='|' read -r \
        #         _ask_field_key \
        #         _ask_field_label \
        #         _ask_field_default \
        #         _ask_field_validate \
        #         <<< "$spec"
        # }
        #
        # _ask_is_ident() {
        #     [[ "${1-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
        # }
        #
        # sgnd_print " 7. Testing ask_prompt_form()"
        #
        HOSTNAME=""
        PORT=""
        
        ask_prompt_form --autoalign --pad 2 -- \
             "HOSTNAME|Host name|localhost|sgnd_validate_text" \
             "PORT|Port|8080|sgnd_validate_text"
        #
        sgnd_print "Result: HOSTNAME='$HOSTNAME', PORT='$PORT'\n"

        sgnd_print "Done.\n"
    }
        # -- Sample/demo renderers
    # fn: say_test - Run console message helper tests
        # . Purpose
        #   Run console message helper tests.
        #
        # . Behavior
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   say_test
    say_test(){
        sgnd_print
        sgnd_print_sectionheader --text "Testing say*() helpers"

        local original_loglevel="${SGND_CONSOLE_LOG_LEVEL:-silent}"
        SGND_CONSOLE_LOG_LEVEL="trace"
        sayinfo "Info message"
        saystart "Start message"
        saywarning "Warning message"
        sayfail "Failure message"
        saycancel "Cancellation message"
        sayok "All is well"
        sayend "Ended gracefully"
        saydebug "Debug message"
        justsay "Just saying"
        SGND_CONSOLE_LOG_LEVEL="$original_loglevel"
    }

    # fn: loglevel_test - Run console message visibility tests for every log level
        # . Purpose
        #   Cycle through all supported SGND_CONSOLE_LOG_LEVEL values and emit one test message
        #   for each message type.
        #
        # . Behavior
        #   - Public smoke-test entry point.
        #   - Temporarily sets SGND_CONSOLE_LOG_LEVEL to off, quiet, normal, and debug.
        #   - Emits INFO, STRT, WARN, FAIL, CNCL, OK, END, DEBUG, and EMPTY messages
        #     for each level so console filtering can be inspected visually.
        #   - Restores the original SGND_CONSOLE_LOG_LEVEL before returning.
        #
        # . Returns
        #   0 when the test sequence completes.
        #
        # . Usage
        #   loglevel_test
    loglevel_test() {
        sgnd_print
        sgnd_print_sectionheader --text "Testing loglevel visibility"
        local original_loglevel="${SGND_CONSOLE_LOG_LEVEL:-silent}"
        local level=""

        for level in silent quiet normal verbose debug trace; do
            SGND_CONSOLE_LOG_LEVEL="$level"

            printf '\n'
            printf '%s\n' '-----------------------------------------'
            printf 'SGND_CONSOLE_LOG_LEVEL=%s\n' "$SGND_CONSOLE_LOG_LEVEL"
            printf '%s\n' 'Expected visible message types depend on _say_should_print_console.'
            printf '%s\n' '-----------------------------------------'

            sayinfo "INFO message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            saystart "STRT message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            saywarning "WARN message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            sayfail "FAIL message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            saycancel "CNCL message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            sayok "OK message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            sayend "END message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            saydebug "DEBUG message at loglevel=$SGND_CONSOLE_LOG_LEVEL"
            say EMPTY "EMPTY message at loglevel=$SGND_CONSOLE_LOG_LEVEL"

            justsay "Just saying at loglevel=$SGND_CONSOLE_LOG_LEVEL"
        done

        SGND_CONSOLE_LOG_LEVEL="$original_loglevel"

        printf '\n'
        printf 'Restored SGND_CONSOLE_LOG_LEVEL=%s\n' "$SGND_CONSOLE_LOG_LEVEL"
    }

    # fn: file_loglevel_test - Run file logging tests for every log level
        # . Purpose
        #   Verify file logging and file-level filtering independently from console output.
        #
        # . DRYRUN
        #   File logging is intentionally skipped because exercising it would append test
        #   records to the active logfile. The test reports exactly what would be tested.
    file_loglevel_test() {
        local logfile=""
        local level=""
        local original_file_loglevel="${SGND_FILE_LOG_LEVEL:-silent}"

        logfile="$(_sgnd_logfile)" || {
            saywarning "Unable to resolve the active logfile"
            return 1
        }

        [[ -n "$logfile" ]] || {
            saywarning "No active logfile is available"
            return 1
        }

        sgnd_print
        sgnd_print_sectionheader --text "Testing file log levels"
        sgnd_print_labeledvalue --label "Logfile" --value "$logfile"

        if (( ${FLAG_DRYRUN:-0} == 1 )); then
            sayinfo "DRYRUN: Would test file log filtering for: silent, quiet, normal, verbose, debug, trace."
            sayinfo "DRYRUN: Test records would be written to '$logfile'; no records will be written."
            return 0
        fi

        for level in silent quiet normal verbose debug trace; do
            SGND_FILE_LOG_LEVEL="$level"
            printf 'Testing SGND_FILE_LOG_LEVEL=%s\n' "$level"

            case "$level" in
                silent)
                    sayfail "FILELOG silent: this line must not be written"
                    ;;
                quiet)
                    saywarning "FILELOG quiet: warning should be written"
                    sayinfo "FILELOG quiet: info must not be written"
                    ;;
                normal)
                    saystart "FILELOG normal: start should be written"
                    sayinfo "FILELOG normal: info must not be written"
                    ;;
                verbose)
                    sayinfo "FILELOG verbose: info should be written"
                    saydebug "FILELOG verbose: debug must not be written"
                    ;;
                debug)
                    saydebug "FILELOG debug: debug should be written"
                    say --type TRACE "FILELOG debug: trace must not be written"
                    ;;
                trace)
                    say --type TRACE "FILELOG trace: trace should be written"
                    ;;
            esac
        done

        SGND_FILE_LOG_LEVEL="$original_file_loglevel"
        printf 'Restored SGND_FILE_LOG_LEVEL=%s\n' "$SGND_FILE_LOG_LEVEL"
        return 0
    }

    # fn: view_log - Display the active SolidGroundUX logfile
        # . Purpose
        #   Display the logfile selected by the current SolidGroundUX logging configuration.
        #
        # . Behavior
        #   - Uses the same logfile resolver as say().
        #   - Displays the resolved path before showing the file contents.
        #   - Reports an empty or unavailable logfile without failing unexpectedly.
        #
        # . Returns
        #   0 when the logfile is displayed.
        #   1 when no readable logfile can be resolved.
        #
        # . Usage
        #   view_log
    view_log() {
        local logfile=""

        logfile="$(_sgnd_logfile)" || {
            saywarning "Unable to resolve the active logfile"
            return 1
        }

        [[ -n "$logfile" && -r "$logfile" ]] || {
            saywarning "Logfile is not readable: ${logfile:-<unresolved>}"
            return 1
        }

        sgnd_print
        sgnd_print_sectionheader --text "SolidGroundUX logfile"
        sgnd_print_labeledvalue --label "Logfile" --value "$logfile"
        sgnd_print
        sgnd_print_file "$logfile"
    }

    # fn: motd_test - Motd test
        # . Purpose
        #   Motd test.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   motd_test
    motd_test() {
        local motd_dir=""
        local motd_file=""
        local rc=0
        local found=0
        local executed=0
        local -a motd_files=()

        if [[ "$SGND_FRAMEWORK_ROOT" == "/" ]]; then
            motd_dir="/etc/update-motd.d"
        else
            motd_dir="${SGND_FRAMEWORK_ROOT%/}/etc/update-motd.d"
        fi

        sgnd_print
        sgnd_print_sectionheader --text "Testing MOTD generation"

        if [[ ! -d "$motd_dir" ]]; then
            sayfail "MOTD directory not found: $motd_dir"
            return 1
        fi

        mapfile -t motd_files < <(
            find "$motd_dir" -maxdepth 1 -type f -name '95-solidgroundux*' -printf '%f\n' 2>/dev/null | sort
        )

        for motd_file in "${motd_files[@]}"; do
            found=$((found + 1))
            if [[ ! -x "$motd_dir/$motd_file" ]]; then
                saywarning "Skipping non-executable MOTD file: $motd_file"
                continue
            fi

            executed=$((executed + 1))
            "$motd_dir/$motd_file" || {
                sayfail "MOTD file failed: $motd_file"
                rc=1
            }
        done

        if (( found == 0 )); then
            saywarning "No SolidGroundUX MOTD files matching 95-solidgroundux* found in: $motd_dir"
        elif (( executed == 0 )); then
            sayfail "No executable SolidGroundUX MOTD files matching 95-solidgroundux* found in: $motd_dir"
            rc=1
        fi

        return "$rc"
    }

    # fn: sayprogress_test - Run transient progress line tests
        # . Purpose
        #   Exercise sayprogress with one, two, and three reserved progress slots.
        #
        # . Behavior
        #   - Runs three visual progress scenarios after each other.
        #   - Stage 1 uses one progress level: 1..15.
        #   - Stage 2 uses true nested progress: outer 1..15, inner 1..70.
        #   - Stage 3 uses true nested progress: outer 1..15, middle 1..70,
        #     inner 1..125.
        #   - Lower levels complete and restart before their parent advances.
        #   - Uses explicit slots so stacked progress rendering can be inspected.
        #
        # . Returns
        #   0 when the visual test sequence completes.
        #
        # . Usage
        #   sayprogress_test
    sayprogress_test() {
        local outer=0
        local middle=0
        local inner=0
        local outer_total=15
        local middle_total=70
        local inner_total=125

        sgnd_print
        sgnd_print_sectionheader --text "Testing sayprogress() helpers"
        sgnd_print
        saystart "Progress test 1/3: single level"

        outer_total=150
        sayprogress_begin --slots 1
        for (( outer = 1; outer <= outer_total; outer++ )); do
            sayprogress \
                --slot 0 \
                --current "$outer" \
                --total "$outer_total" \
                --label "Stage 1: single level $outer/$outer_total" \
                --type 7 \
                --padleft 0

            (( outer % 5 == 0 )) && sleep 0.05
        done
        
        sayok "Progress test 1/3 complete"
        
        sgnd_print
        saystart "Progress test 2/3: double level"

        outer_total=5
        middle_total=125
        sayprogress_begin --slots 2
        for (( outer = 1; outer <= outer_total; outer++ )); do
            sayprogress \
                --slot 0 \
                --current "$outer" \
                --total "$outer_total" \
                --label "Stage 2 outer: $outer/$outer_total" \
                --type 7 \
                --padleft 0

            for (( middle = 1; middle <= middle_total; middle++ )); do
                sayprogress \
                    --slot 1 \
                    --current "$middle" \
                    --total "$middle_total" \
                    --label "Stage 2 inner: $middle/$middle_total" \
                    --type 7 \
                    --padleft 2

                (( middle % 5 == 0 )) && sleep 0.05
            done
        done
        sayok "Progress test 2/3 complete"

        
        sgnd_print
        saystart "Progress test 3/3: triple level"

        sayprogress_begin --slots 3
        outer_total=5
        middle_total=10
        inner_total=80
        for (( outer = 1; outer <= outer_total; outer++ )); do
            sayprogress \
                --slot 0 \
                --current "$outer" \
                --total "$outer_total" \
                --label "Stage 3 outer: $outer/$outer_total" \
                --type 7 \
                --padleft 0

            for (( middle = 1; middle <= middle_total; middle++ )); do
                sayprogress \
                    --slot 1 \
                    --current "$middle" \
                    --total "$middle_total" \
                    --label "Stage 3 middle: $middle/$middle_total" \
                    --type 7 \
                    --padleft 2

                for (( inner = 1; inner <= inner_total; inner++ )); do
                    sayprogress \
                        --slot 2 \
                        --current "$inner" \
                        --total "$inner_total" \
                        --label "Stage 3 inner: $inner/$inner_total" \
                        --type 7 \
                        --padleft 4

                    (( inner % 10 == 0 )) && sleep 0.01
                done
            done
        done
        sayok "Progress test 3/3 complete"
        sgnd_print
    }

    # fn: show_colorchart - Show colorchart
        # . Purpose
        #   Show colorchart.
        #
        # . Returns
        #   Returns the underlying command or workflow status.
        #
        # . Usage
        #   show_colorchart
    show_colorchart(){
        sgnd_color_samples
    }

    # fn: show_theme - Browse and preview installed UI themes
        # . Purpose
        #   Cycle through installed SolidGroundUX themes and preview each one.
        #
        # . Behavior
        #   - Discovers numbered NN-style-*.sh files in SGND_STYLE_DIR.
        #   - Starts at the currently active theme when possible.
        #   - Uses Left/Right arrows to switch the runtime theme without saving it.
        #   - Displays sgnd_style_samples after every successful switch.
        #   - Q returns to the smoke-test menu and leaves the selected theme active.
        #
        # . Returns
        #   0 after leaving the theme browser.
        #   1 when no readable themes are found.
        #
        # . Usage
        #   show_theme
    show_theme() {
        local -a theme_files=()
        local -a theme_names=()
        local -a theme_color_groups=(
            "Message colors|MSG_CLR_INFO MSG_CLR_STRT MSG_CLR_OK MSG_CLR_WARN MSG_CLR_FAIL MSG_CLR_CNCL MSG_CLR_END MSG_CLR_EMPTY MSG_CLR_DEBUG"
            "Progress colors|PROG_BAR_CLR PROG_IND_CLR PROG_TEXT_CLR"
            "UI colors|SGND_UI_BORDER SGND_UI_LABEL SGND_UI_VALUE SGND_UI_COMMIT SGND_UI_DRYRUN SGND_UI_ENABLED SGND_UI_DISABLED SGND_UI_ON SGND_UI_OFF SGND_UI_INPUT SGND_UI_PROMPT SGND_UI_INVALID SGND_UI_VALID SGND_UI_SUCCESS SGND_UI_ERROR SGND_UI_TEXT SGND_UI_DEFAULT"
        )
        local theme_file=""
        local theme_name=""
        local current_file="${SGND_UI_STYLE##*/}"
        local key=""
        local key_tail=""
        local index=0
        local i=0
        local group_spec=""
        local group_name=""
        local group_vars=""
        local color_var=""
        local color_value=""

        while IFS= read -r -d '' theme_file; do
            theme_files+=("$(basename -- "$theme_file")")
        done < <(
            find "$SGND_STYLE_DIR" -maxdepth 1 -type f \
                -name '[0-9][0-9]-style-*.sh' \
                -print0 | LC_ALL=C sort -z
        )

        if (( ${#theme_files[@]} == 0 )); then
            saywarning "No themes found in $SGND_STYLE_DIR"
            return 1
        fi

        for theme_file in "${theme_files[@]}"; do
            theme_name="${theme_file%.sh}"
            theme_name="${theme_name#??-style-}"
            theme_names+=("$theme_name")
        done

        for i in "${!theme_files[@]}"; do
            if [[ "${theme_files[$i]}" == "$current_file" ]]; then
                index=$i
                break
            fi
        done

        while true; do
            theme_name="${theme_names[$index]}"

            sgnd_theme "$theme_name" || return $?

            printf '\033[2J\033[H'
            printf 'Theme %d/%d: %s\n' \
                "$((index + 1))" \
                "${#theme_names[@]}" \
                "$theme_name"
            printf 'Use Left/Right arrows to browse; Q returns to the menu.\n\n'

            sgnd_style_samples
            sgnd_print

            sgnd_print_sectionheader --border $DL_H

            sgnd_print "Press  $KY_LEFT or $KY_RIGHT to switch themes, or Q to return to the menu.\n"
            
            IFS= read -r -s -n1 key

            case "$key" in
                $'\e')
                    key_tail=""
                    IFS= read -r -s -n2 -t 0.1 key_tail || true

                    case "$key_tail" in
                        '[D')
                            index=$(( (index - 1 + ${#theme_names[@]}) % ${#theme_names[@]} ))
                            ;;
                        '[C')
                            index=$(( (index + 1) % ${#theme_names[@]} ))
                            ;;
                        '')
                            return 130
                            ;;
                    esac
                    ;;
                q|Q)
                    break
                    ;;
                '')
                    continue
                    ;;
            esac
        done

        return 0
    }

# - Validation engine --------------------------------------------------------------
    SGND_TEST_PASS=0
    SGND_TEST_FAIL=0
    SGND_TEST_SKIP=0

    _framework_test_root_path() {
        local relative="${1:?missing path}"
        local root="${SGND_FRAMEWORK_ROOT:-/}"
        relative="${relative#/}"
        if [[ "$root" == "/" ]]; then
            printf '/%s\n' "$relative"
        else
            printf '%s/%s\n' "${root%/}" "$relative"
        fi
    }

    _framework_test_result() {
        local label="${1:?missing label}"
        local status="${2:?missing status}"
        local detail="${3:-}"
        local value="$status"

        [[ -z "$detail" ]] || value="$status - $detail"
        sgnd_print_labeledvalue --label "$label" --value "$value" --labelwidth 32

        case "$status" in
            PASS) SGND_TEST_PASS=$((SGND_TEST_PASS + 1)); return 0 ;;
            SKIP) SGND_TEST_SKIP=$((SGND_TEST_SKIP + 1)); return 0 ;;
            FAIL) SGND_TEST_FAIL=$((SGND_TEST_FAIL + 1)); return 1 ;;
        esac
        return 1
    }

    _framework_test_suite_summary() {
        local title="${1:?missing title}"
        local pass_before="${2:-0}"
        local fail_before="${3:-0}"
        local skip_before="${4:-0}"
        local passed=$((SGND_TEST_PASS - pass_before))
        local failed=$((SGND_TEST_FAIL - fail_before))
        local skipped=$((SGND_TEST_SKIP - skip_before))

        sgnd_print
        sgnd_print_sectionheader --text "$title summary"
        sgnd_print_labeledvalue --label "Passed" --value "$passed" --labelwidth 18
        sgnd_print_labeledvalue --label "Failed" --value "$failed" --labelwidth 18
        sgnd_print_labeledvalue --label "Skipped" --value "$skipped" --labelwidth 18
        sgnd_print

        if (( failed == 0 )); then
            sayok "$title passed."
            return 0
        fi

        sayfail "$title reported $failed failure(s)."
        return 1
    }

    _framework_test_validate_installation() {
        local pass_before=$SGND_TEST_PASS
        local fail_before=$SGND_TEST_FAIL
        local skip_before=$SGND_TEST_SKIP
        local path=""
        local relative=""
        local command_name=""
        local -a required_files=(
            "/usr/local/lib/solidgroundux/common/sgnd-bootstrap.sh"
            "/usr/local/lib/solidgroundux/common/sgnd-core.sh"
            "/usr/local/lib/solidgroundux/common/sgnd-menu.sh"
            "/usr/local/lib/solidgroundux/common/ui.sh"
            "/usr/local/libexec/solidgroundux/sgnd-smoketest.sh"
        )
        local -a required_commands=(
            "sgnd-smoketest"
        )

        sgnd_print
        sgnd_print_sectionheader --text "Framework installation"

        for relative in "${required_files[@]}"; do
            path="$(_framework_test_root_path "$relative")"
            if [[ -r "$path" ]]; then
                _framework_test_result "$(basename "$relative")" "PASS" || true
            else
                _framework_test_result "$(basename "$relative")" "FAIL" "$path" || true
            fi
        done

        for command_name in "${required_commands[@]}"; do
            path="$(_framework_test_root_path "/usr/local/bin/$command_name")"
            if [[ -x "$path" ]]; then
                _framework_test_result "$command_name" "PASS" "$path" || true
            else
                _framework_test_result "$command_name" "FAIL" "public command not executable: $path" || true
            fi
        done

        _framework_test_suite_summary "Framework installation" "$pass_before" "$fail_before" "$skip_before"
    }


# - Smoke test menu -----------------------------------------------------------------
    declare -A SGND_SMOKETEST_STATUS=()

    _smoketest_show_license() {
        saydebug "$SGND_DOCS_DIR/$SGND_LICENSE_FILE"
        sgnd_print_license
    }

    _smoketest_finish_test() {
        sgnd_print
        sgnd_print_sectionheader --border "$DL_H" --maxwidth "${SGND_MENU_RENDER_WIDTH:-$(sgnd_terminal_width)}"
    }

    _smoketest_wait_for_return() {
        local key=""

        printf '%bPress any key to return...%b' "${SGND_UI_PROMPT:-}" "${RESET:-}" >/dev/tty
        IFS= read -r -s -n 1 key </dev/tty || return 1
        printf '\n' >/dev/tty
        return 0
    }

    _smoketest_status_icon() {
        local status="${SGND_SMOKETEST_STATUS[$1]:-}"
        local color=""
        local icon=""

        case "$status" in
            pass)
                icon="✓"
                color="${SGND_UI_SUCCESS:-${BRIGHT_GREEN:-}}"
                ;;
            fail)
                icon="✗"
                color="${SGND_UI_ERROR:-${BRIGHT_RED:-}}"
                ;;
            *)
                printf ' '
                return 0
                ;;
        esac

        printf '%s%s%s' "$color" "$icon" "${RESET:-}"
    }

    _smoketest_run_one() {
        local id="$1" fn="$2" rc=0

        # Selecting a smoke test means run it immediately. Interactive helpers
        # retain ownership of their input; when they propagate an Escape/cancel
        # as 130, return directly to the smoke-test menu without recording a
        # pass/fail result. This deliberately avoids a global key listener that
        # could steal input from the UI helper being tested.
        "$fn" || rc=$?

        if (( rc == 130 )); then
            SGND_SMOKETEST_STATUS[$id]=""
            return 130
        elif (( rc == 0 )); then
            SGND_SMOKETEST_STATUS[$id]="pass"
        else
            SGND_SMOKETEST_STATUS[$id]="fail"
        fi

        _smoketest_finish_test
        if (( ${SGND_SMOKETEST_RUN_ALL:-0} == 0 )); then
            _smoketest_wait_for_return || true
        fi
        return "$rc"
    }

    _smoketest_render_menu() {
        local i icon
        local -a names=(
            "Ask tests"
            "Selection test"
            "Input test"
            "Say test"
            "Log level visibility test"
            "Call MOTD"
            "Progress dialogue test"
            "Show license"
            "Show color chart"
            "Show theme"
            "File log level test"
            "View logfile"
        )
        local -a desc=(
            "Exercise ask and dialog helpers"
            "Exercise single and multiple ask_selection behavior"
            "Exercise input helpers"
            "Exercise message output helpers"
            "Verify console log-level filtering"
            "Render the SolidGroundUX MOTD"
            "Exercise stacked progress lines"
            "Display the active SolidGroundUX license"
            "Display the current terminal color chart"
            "Browse installed SolidGroundUX themes"
            "Verify file log-level filtering"
            "Display the active SolidGroundUX logfile"
        )

        sgnd_clear
        sgnd_print_titlebar --left "Framework Smoke Tests" --sub "Exercise SolidGroundUX UI and runtime helpers"
        sgnd_print
        sgnd_print_sectionheader --text "Smoke tests"
        for i in {1..12}; do
            icon="$(_smoketest_status_icon "$i")"
            sgnd_print --text "${icon} ${i}) ${names[$((i-1))]}" --text2 "${desc[$((i-1))]}" --pad 2
        done
        sgnd_print
        sgnd_print_sectionheader --text "Actions"
        sgnd_print --text "${SGND_UI_SUCCESS:-${BRIGHT_GREEN:-}}▶${RESET:-} 13) Run all smoke tests" --text2 "Run the complete interactive smoke-test sequence" --pad 2
        sgnd_print --text "  X) Exit" --text2 "Return to console menu" --pad 2
        sgnd_print
        sgnd_print_sectionheader --border "$DL_H" --maxwidth "${SGND_MENU_RENDER_WIDTH:-$(sgnd_terminal_width)}"
        sgnd_print
    }

    _smoketest_read_choice() {
        local output_var="${1:?missing output variable}"
        local value=""
        while :; do
            printf '%bSelect option: %b' "${SGND_UI_PROMPT:-}" "${RESET:-}" >/dev/tty
            IFS= read -r value </dev/tty || return 1
            case "${value^^}" in
                X) printf -v "$output_var" '%s' 'X'; return 0 ;;
                1|2|3|4|5|6|7|8|9|10|11|12|13)
                    printf -v "$output_var" '%s' "$value"; return 0 ;;
                *) saywarning "Choose 1-13 or X." ;;
            esac
        done
    }

    _smoketest_dispatch_one() {
        local choice="$1" rc=0
        case "$choice" in
            1)  _smoketest_run_one 1 ask_test || rc=$? ;;
            2)  _smoketest_run_one 2 ask_selection_test || rc=$? ;;
            3)  _smoketest_run_one 3 input_test || rc=$? ;;
            4)  _smoketest_run_one 4 say_test || rc=$? ;;
            5)  _smoketest_run_one 5 loglevel_test || rc=$? ;;
            6)  _smoketest_run_one 6 motd_test || rc=$? ;;
            7)  _smoketest_run_one 7 sayprogress_test || rc=$? ;;
            8)  _smoketest_run_one 8 _smoketest_show_license || rc=$? ;;
            9)  _smoketest_run_one 9 show_colorchart || rc=$? ;;
            10) _smoketest_run_one 10 show_theme || rc=$? ;;
            11) _smoketest_run_one 11 file_loglevel_test || rc=$? ;;
            12) _smoketest_run_one 12 view_log || rc=$? ;;
        esac
        return "$rc"
    }

    _smoketest_run_all_tests() {
        local i rc=0 failures=0
        SGND_SMOKETEST_RUN_ALL=1
        for i in {1..12}; do
            rc=0
            _smoketest_dispatch_one "$i" || rc=$?
            if (( rc == 130 )); then
                SGND_SMOKETEST_RUN_ALL=0
                return 130
            fi
            (( rc == 0 )) || failures=$((failures + 1))
        done
        SGND_SMOKETEST_RUN_ALL=0

        sgnd_print
        sgnd_print_sectionheader --text "Interactive smoke test summary"
        sgnd_print_labeledvalue --label "Failed" --value "$failures" --labelwidth 18
        (( failures == 0 )) && sayok "Interactive smoke tests completed." || sayfail "$failures interactive smoke test(s) reported failure."
        _smoketest_finish_test
        _smoketest_wait_for_return || true
        (( failures == 0 ))
    }

    _framework_test_run_smoke_menu() {
        local choice="" rc=0
        SGND_SMOKETEST_RUN_ALL=0
        while :; do
            _smoketest_render_menu
            choice=""
            _smoketest_read_choice choice || break
            [[ "$choice" == "X" ]] && break
            if [[ "$choice" == "13" ]]; then
                _smoketest_run_all_tests || true
            else
                _smoketest_dispatch_one "$choice" || true
            fi
        done
        return 0
    }

# - Aggregate runner ---------------------------------------------------------------
    _framework_test_run_all() {
        local area_failures=0
        local smoke_rc=0

        _framework_test_validate_installation || area_failures=$((area_failures + 1))

        _smoketest_run_all_tests || {
            smoke_rc=$?
            area_failures=$((area_failures + 1))
        }

        sgnd_print
        sgnd_print_sectionheader --text "Framework test summary"
        sgnd_print_labeledvalue --label "Validation passed" --value "$SGND_TEST_PASS" --labelwidth 22
        sgnd_print_labeledvalue --label "Validation failed" --value "$SGND_TEST_FAIL" --labelwidth 22
        sgnd_print_labeledvalue --label "Validation skipped" --value "$SGND_TEST_SKIP" --labelwidth 22
        sgnd_print_labeledvalue --label "Smoke tests" --value "$([[ $smoke_rc -eq 0 ]] && printf PASS || printf FAIL)" --labelwidth 22
        sgnd_print

        if (( area_failures == 0 )); then
            sayok "All SolidGroundUX framework-owned tests passed."
            return 0
        fi

        sayfail "$area_failures framework test area(s) reported failures."
        return 1
    }

# - Main ---------------------------------------------------------------------------
    main() {
        _framework_locator || exit $?
        sgnd_exe_start "$@"

        if (( ${FLAG_VIEW_LOG:-0} )); then
            view_log
            return $?
        fi

        local suite_rc=0
        case "${ENUM_SUITE:-smoke}" in
            smoke)
                _framework_test_run_smoke_menu || suite_rc=$?
                ;;
            installation)
                _framework_test_validate_installation || suite_rc=$?
                ;;
            all)
                _framework_test_run_all || suite_rc=$?
                ;;
            *)
                sayfail "Unknown framework test suite: ${ENUM_SUITE:-}"
                suite_rc=2
                ;;
        esac

        _smoketest_finish_test
        return "$suite_rc"
    }

    main "$@"
