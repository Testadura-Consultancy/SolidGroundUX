#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Tar It
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
#   Checksum    : bb3dc8626060f30c151a2dddaf65efd2b9d9f8ebcbfdfab88ae7afcc5e88c8bb
#   Source      : tar-it.sh
#   Type        : script
#   Group       : Common Core
#   Purpose     : Create a timestamped archive of a SolidGroundUX framework tree
#
# Description:
#   Creates a compressed tar archive containing the complete tree beneath a selected
#   framework root. Archive entries are stored relative to that root so they can later
#   be restored beneath any compatible target root by un-tar-it.sh.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail

# - Bootstrap ----------------------------------------------------------------------
    # fn: _framework_locator - Locate and load the SolidGroundUX executable bootstrap context
        # . Returns
        #   0 when the executable common library was loaded.
        #   126 or 127 when bootstrap configuration cannot be resolved.
        #
        # . Usage
        #   _framework_locator || return $?
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
# - Script metadata ----------------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"
    SGND_SCRIPT_TITLE="Tar it"
    : "${SGND_SCRIPT_DESC:=Create a timestamped archive of the SolidGroundUX framework tree.}"
    : "${SGND_SCRIPT_VERSION:=1.8}"
    : "${SGND_SCRIPT_BUILD:=2621603}"
    : "${SGND_SCRIPT_DEVELOPERS:=Mark Fieten}"
    : "${SGND_SCRIPT_COMPANY:=Testadura Consultancy}"
    : "${SGND_SCRIPT_COPYRIGHT:=© 2025 - 2026 Testadura Consultancy}"
    : "${SGND_SCRIPT_LICENSE:=Testadura Non-Commercial License (TD-NC) v1.1.}"

# - Framework integration -----------------------------------------------------------
    SGND_USING=()

    SGND_ARGS_SPEC=(
        "auto|a|flag|FLAG_AUTO|Create the archive without prompting|0|"
        "source|s|value|ARCHIVE_SOURCE_ROOT|Root of the tree to archive|"
        "archive-dir|d|value|ARCHIVE_DIRECTORY|Directory in which archives are stored|"
        "name|n|value|ARCHIVE_NAME|Archive filename, with or without .tar.gz|"
    )

    SGND_SCRIPT_EXAMPLES=(
        "Archive the configured framework root:"
        "  $SGND_SCRIPT_NAME"
        ""
        "Archive a development target root without prompting:"
        "  $SGND_SCRIPT_NAME --auto --source /home/sysadmin/dev/SolidGroundUX/target-root"
    )

    SGND_SCRIPT_GLOBALS=(
        SGND_ARCHIVE_DIR
    )

    SGND_STATE_VARIABLES=(
        ARCHIVE_SOURCE_ROOT
        ARCHIVE_DIRECTORY
    )

    SGND_ON_EXIT_HANDLERS=()
    SGND_STATE_SAVE=0

# - Local declarations --------------------------------------------------------------
    ARCHIVE_SOURCE_ROOT="${ARCHIVE_SOURCE_ROOT:-}"
    ARCHIVE_DIRECTORY="${ARCHIVE_DIRECTORY:-}"
    ARCHIVE_NAME="${ARCHIVE_NAME:-}"

    CLI_ARCHIVE_SOURCE_ROOT=0
    CLI_ARCHIVE_DIRECTORY=0
    CLI_ARCHIVE_NAME=0

# - Helpers -------------------------------------------------------------------------
    # fn: _scan_cli_args - Record which archive settings were supplied explicitly
        # . Arguments
        #   $@  Original command-line arguments.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   _scan_cli_args "$@"
    _scan_cli_args() {
        local arg=""
        local expect=""

        for arg in "$@"; do
            if [[ -n "$expect" ]]; then
                printf -v "$expect" '%s' 1
                expect=""
                continue
            fi

            case "$arg" in
                --source=*) CLI_ARCHIVE_SOURCE_ROOT=1 ;;
                --source|-s) expect="CLI_ARCHIVE_SOURCE_ROOT" ;;
                --archive-dir=*) CLI_ARCHIVE_DIRECTORY=1 ;;
                --archive-dir|-d) expect="CLI_ARCHIVE_DIRECTORY" ;;
                --name=*) CLI_ARCHIVE_NAME=1 ;;
                --name|-n) expect="CLI_ARCHIVE_NAME" ;;
            esac
        done
    }

    # fn: _normalize_archive_name - Normalize the requested archive filename
        # . Output
        #   Writes a basename ending in .tar.gz.
        #
        # . Returns
        #   0 for a safe basename; 1 otherwise.
        #
        # . Usage
        #   name="$(_normalize_archive_name "$ARCHIVE_NAME")"
    _normalize_archive_name() {
        local name="$1"

        [[ -n "$name" ]] || name="solidgroundux-$(date +%Y%m%dT%H%M%S).tar.gz"
        [[ "$name" != */* && "$name" != "." && "$name" != ".." ]] || return 1
        [[ "$name" == *.tar.gz ]] || name+=".tar.gz"
        printf '%s\n' "$name"
    }

    # fn: _validate_parameters - Validate archive source and destination settings
        # . Returns
        #   0 when all settings are usable; 1 otherwise.
        #
        # . Usage
        #   _validate_parameters || return $?
    _validate_parameters() {
        [[ -d "$ARCHIVE_SOURCE_ROOT" ]] || {
            sayfail "Archive source root not found: $ARCHIVE_SOURCE_ROOT"
            return 1
        }

        case "$ARCHIVE_SOURCE_ROOT" in /*) ;; *) sayfail "Archive source root must be absolute."; return 1 ;; esac
        case "$ARCHIVE_DIRECTORY" in /*) ;; *) sayfail "Archive directory must be absolute."; return 1 ;; esac

        ARCHIVE_NAME="$(_normalize_archive_name "$ARCHIVE_NAME")" || {
            sayfail "Archive name must be a filename, not a path."
            return 1
        }

        return 0
    }

    # fn: _getparameters - Resolve and confirm archive settings
        # . Returns
        #   0 when settings are valid and confirmed; 1 on cancellation.
        #
        # . Usage
        #   _getparameters || return $?
    _getparameters() {
        local reply=0

        : "${ARCHIVE_SOURCE_ROOT:=$SGND_FRAMEWORK_ROOT}"
        : "${ARCHIVE_DIRECTORY:=$SGND_ARCHIVE_DIR}"

        if [[ "${FLAG_AUTO:-0}" -eq 1 ]]; then
            _validate_parameters
            return $?
        fi

        while true; do
            if [[ "$CLI_ARCHIVE_SOURCE_ROOT" -eq 0 ]]; then
                sgnd_print "Enter the root of the tree to archive."
                sgnd_print "Archive entries are stored relative to this directory."
                ask --label "Source root" --var ARCHIVE_SOURCE_ROOT --default "$ARCHIVE_SOURCE_ROOT" --colorize both
            fi

            if [[ "$CLI_ARCHIVE_DIRECTORY" -eq 0 ]]; then
                sgnd_print "Enter the directory in which the archive will be created."
                sgnd_print "The archive directory is excluded when it resides inside the source tree."
                ask --label "Archive directory" --var ARCHIVE_DIRECTORY --default "$ARCHIVE_DIRECTORY" --colorize both
            fi

            if [[ "$CLI_ARCHIVE_NAME" -eq 0 ]]; then
                sgnd_print "Leave the archive name empty to use a timestamped filename."
                ask --label "Archive name" --var ARCHIVE_NAME --default "$ARCHIVE_NAME" --colorize both
            fi

            _validate_parameters || {
                saywarning "Please correct the archive settings."
                continue
            }

            ask_dlg_autocontinue --seconds 15 --message "Create this archive?" --redo --cancel
            reply=$?
            case "$reply" in
                0|1) return 0 ;;
                2) saycancel "Archive creation cancelled."; return 1 ;;
                3) continue ;;
                *) sayfail "Unexpected confirmation response: $reply"; return 1 ;;
            esac
        done
    }

    # fn: _create_archive - Create the compressed framework archive
        # . Returns
        #   0 after successful archive creation; non-zero on failure.
        #
        # . Usage
        #   _create_archive
    _create_archive() {
        local archive_path="${ARCHIVE_DIRECTORY%/}/$ARCHIVE_NAME"
        local source_real=""
        local archive_dir_real=""
        local exclude_rel=""
        local -a tar_args=(-C "$ARCHIVE_SOURCE_ROOT" -czf "$archive_path")

        source_real="$(realpath -m -- "$ARCHIVE_SOURCE_ROOT")"
        archive_dir_real="$(realpath -m -- "$ARCHIVE_DIRECTORY")"

        if [[ "$archive_dir_real" == "$source_real" || "$archive_dir_real" == "$source_real/"* ]]; then
            exclude_rel="${archive_dir_real#"$source_real"/}"
            [[ "$archive_dir_real" == "$source_real" ]] && exclude_rel="."
            tar_args+=(--exclude="./$exclude_rel")
        fi

        saystart "Creating archive $archive_path"

        if [[ "${FLAG_DRYRUN:-0}" -eq 1 ]]; then
            sayinfo "Would create archive directory: $ARCHIVE_DIRECTORY"
            sayinfo "Would archive: $ARCHIVE_SOURCE_ROOT"
            [[ -n "$exclude_rel" ]] && sayinfo "Would exclude archive directory: $exclude_rel"
            sayend "Dry run complete."
            return 0
        fi

        install -d -m 750 -- "$ARCHIVE_DIRECTORY" || {
            sayfail "Cannot create archive directory: $ARCHIVE_DIRECTORY"
            sayinfo "Run with sufficient permissions or configure SGND_ARCHIVE_DIR to a writable location."
            return 1
        }

        [[ -w "$ARCHIVE_DIRECTORY" ]] || {
            sayfail "Archive directory is not writable: $ARCHIVE_DIRECTORY"
            sayinfo "Run with sufficient permissions or configure SGND_ARCHIVE_DIR to a writable location."
            return 1
        }

        tar "${tar_args[@]}" . || {
            rm -f -- "$archive_path"
            sayfail "Archive creation failed."
            return 1
        }

        SGND_STATE_SAVE=1
        sayinfo "Archive created: $archive_path"
        sayend "Archive complete."
        return 0
    }

# - Main ----------------------------------------------------------------------------
    # fn: main - Run the archive workflow
        # . Arguments
        #   $@  Framework and script-specific arguments.
        #
        # . Returns
        #   Workflow exit status.
        #
        # . Usage
        #   main "$@"
    main() {
        _scan_cli_args "$@"
        _framework_locator || exit $?
        sgnd_exe_start --state --no-clear -- "$@"

        _getparameters || return $?
        _create_archive
    }

    main "$@"
