# =====================================================================================
# SolidGroundUX - Framework Definitions
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627700
#   Checksum    : 192f460214b82bb5921cf1557c8190e01af882f3a016a1345aa6347281f5d77c
#   Source      : sgnd-definitions.sh
#   Type        : library
#   Group       : Bootstrap
#   Purpose     : Define canonical SolidGroundUX framework globals and defaults
#
# Description:
#   Provides the single canonical definition point for stable framework identity,
#   bootstrap defaults, global registries, and ordered core-library declarations.
#
#   This library contains definitions only. Derived runtime paths remain the
#   responsibility of sgnd-bootstrap-env.sh so they can be rebased safely.
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
# - Framework identity --------------------------------------------------------------
    SGND_PRODUCT="SolidGroundUX"
    SGND_VERSION="2.1"
    SGND_BUILD="2627700"
    SGND_COMPANY="Testadura Consultancy"
    SGND_COPYRIGHT="© 2025 - 2026 Testadura Consultancy"
    SGND_LICENSE="Testadura Non-Commercial License (TD-NC) v1.1."
    SGND_LICENSE_ACCEPTED=0
    SGND_RELEASE_URL="https://github.com/Testadura-Mark/SolidGroundUX/releases"    
    SGND_ONLINE_DOC="https://testadura-consultancy.github.io/SolidGroundUX/"
    SGND_DOCUMENTATION="$SGND_ONLINE_DOC"
    SGND_APPENDICES="attribution,glossary,integrity,globals,enums,license,changelog,install,canonical"

# - Framework defaults --------------------------------------------------------------
    SGND_DEFAULT_FRAMEWORK_ROOT="/"

    SGND_DEFAULT_LOG_MAX_BYTES=$((25 * 1024 * 1024))
    SGND_DEFAULT_LOG_KEEP=20
    SGND_DEFAULT_LOG_COMPRESS=1

    SGND_DEFAULT_CONSOLE_LOG_LEVEL="silent"
    SGND_DEFAULT_FILE_LOG_LEVEL="verbose"

    SGND_DEFAULT_UI_STYLE="00-style-default.sh"
    SGND_DEFAULT_UI_PALETTE="default-ui-palette.sh"
    SGND_DEFAULT_UI_WARNING_DELAY=0.5
    SGND_DEFAULT_UI_ERROR_DELAY=0.5

    SGND_DEFAULT_SAY_DATE=0
    SGND_DEFAULT_SAY_SHOW="label"
    SGND_DEFAULT_SAY_COLORIZE="label"
    SGND_DEFAULT_SAY_DATE_FORMAT="%Y-%m-%d %H:%M:%S"

    SGND_DEFAULT_FRAMEWORK_CFG_BASENAME="sgnd_framework_globals.cfg"

    SGND_DEFAULT_CONSOLE_WIDTH=80
    SGND_DEFAULT_MAX_RENDER_WIDTH=140

# - Framework metadata --------------------------------------------------------------
    SGND_FRAMEWORK_GLOBALS=(
        "system|SGND_SYSCFG_DIR|Framework-wide system configuration directory|"
        "system|SGND_DOCS_DIR|Framework-wide documentation directory|"
        "both|SGND_CONSOLE_LOG_LEVEL|Controls console message visibility. Supported values are silent, quiet, normal, verbose, debug, and trace.|"
        "both|SGND_FILE_LOG_LEVEL|Controls file message visibility. Supported values are silent, quiet, normal, verbose, debug, and trace.|"
        "system|SGND_LOG_PATH|Primary log file or directory path|"
        "both|SGND_ALTLOG_PATH|Alternate log path override|"                    # <- both
        "system|SGND_LOG_MAX_BYTES|Maximum log file size before rotation|"
        "system|SGND_LOG_KEEP|Number of rotated log files to retain|"
        "system|SGND_LOG_COMPRESS|Compress rotated log files|"

        "user|SGND_STATE_DIR|User-specific persistent state directory|"
        "user|SGND_USRCFG_DIR|User-specific configuration directory|"

        "both|SGND_UI_STYLE|Default UI style file (basename or path)|"          # <- both
        "both|SGND_UI_PALETTE|Default UI palette file (basename or path)|"      # <- both
        "both|SGND_UI_WARNING_DELAY|Default delay in seconds after warning messages; -1 waits for a keypress.|"
        "both|SGND_UI_ERROR_DELAY|Default delay in seconds after error messages; -1 waits for a keypress.|"

        "user|SAY_COLORIZE_DEFAULT|Default colorized console output setting|"
        "user|SAY_DATE_DEFAULT|Default timestamp visibility|"
        "user|SAY_SHOW_DEFAULT|Default console message visibility|"
        "user|SAY_DATE_FORMAT|Default date/time format for console output|"

        "both|SGND_CONSOLE_WIDTH|Prefered standard console width|"
        "both|SGND_MAX_RENDER_WIDTH|Render width upper limit|"
    )

    # var: SGND_CORE_LIBS - Ordered core library list
        # . Purpose
        #   Define the core libraries that sgnd-bootstrap loads in fixed order.
        #
        # Notes:
        #   - Ordering is part of the bootstrap contract.
        #   - Earlier libraries may be required by later ones.
    SGND_CORE_LIBS=(
        sgnd-args.sh
        sgnd-info.sh
        sgnd-cfg.sh
        sgnd-system.sh
        sgnd-core.sh
        ui.sh
        ui-say.sh
        ui-ask.sh
        ui-glyphs.sh
    )


    SGND_RUNTIME_GLOBALS=(
        "both|SGND_FRAMEWORK_ROOT|Root path used as the base for framework filesystem locations.|"
        "both|SGND_COMMON_LIB|Directory containing common SolidGroundUX library files.|"
        "both|SGND_GLOBALS_FOLDER|Directory containing framework and project definition libraries.|"
        "both|SGND_COMMON_EXE|Directory containing common SolidGroundUX executable files.|"
        "system|SGND_SYSCFG_DIR|Directory containing system-level SolidGroundUX configuration files.|"
        "user|SGND_USRCFG_DIR|Directory containing user-level SolidGroundUX configuration files.|"
        "user|SGND_STATE_DIR|Directory containing user-level SolidGroundUX state files.|"
        "system|SGND_STYLE_DIR|Directory containing SolidGroundUX style and palette files.|"
        "system|SGND_DOCS_DIR|Directory containing SolidGroundUX documentation files.|"
        "system|SGND_LOG_PATH|Primary logfile path for framework or application logging.|"
        "user|SGND_ALTLOG_PATH|Fallback user-level logfile path for framework or application logging.|"

        "both|SGND_LOG_MAX_BYTES|Maximum logfile size before log rotation is attempted.|"
        "both|SGND_LOG_KEEP|Number of rotated logfile copies to retain.|"
        "both|SGND_LOG_COMPRESS|Controls whether rotated logfiles are compressed.|"
        "both|SGND_CONSOLE_LOG_LEVEL|Controls console message visibility. Supported values are silent, quiet, normal, verbose, debug, and trace.|"
        "both|SGND_FILE_LOG_LEVEL|Controls file message visibility. Supported values are silent, quiet, normal, verbose, debug, and trace.|"

        "user|SGND_USER_HOME|Effective user home directory, honoring SUDO_USER when present.|"

        "both|SGND_UI_STYLE|Selected SolidGroundUX UI style file.|"
        "both|SGND_UI_PALETTE|Selected SolidGroundUX UI palette file.|"
        "both|SGND_UI_WARNING_DELAY|Delay in seconds after warning messages; -1 waits for a keypress.|"
        "both|SGND_UI_ERROR_DELAY|Delay in seconds after error messages; -1 waits for a keypress.|"
        "both|SGND_CONSOLE_WIDTH|Preferred standard width for console rendering primitives.|"
        "both|SGND_MAX_RENDER_WIDTH|Upper limit applied to console rendering width.|"

        "both|SAY_DATE_DEFAULT|Default setting controlling whether say output includes a timestamp.|"
        "both|SAY_SHOW_DEFAULT|Default say output prefix mode, such as label, icon, symbol, or combinations.|"
        "both|SAY_COLORIZE_DEFAULT|Default say colorization mode, such as none, label, msg, both, all, or date.|"
        "both|SAY_DATE_FORMAT|Date format used when say output includes timestamps.|"

        "both|SGND_FRAMEWORK_CFG_BASENAME|Basename of the framework globals configuration file.|"
        "user|SGND_FRAMEWORK_STATEFILE|User-specific framework runtime state file.|"
    )

    SGND_FRAMEWORK_STATE=(
        SGND_CONSOLE_LOG_LEVEL
        SGND_FILE_LOG_LEVEL
        SGND_UI_STYLE
        SGND_UI_PALETTE
        SAY_DATE_FORMAT
    )
