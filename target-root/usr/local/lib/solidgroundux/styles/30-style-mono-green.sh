# =====================================================================================
# SolidGroundUX - Monochrome Green UI Style
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627412
#   Checksum    : 2b81f4f9a5dad82a12eb8379ea9027aad133b8c14a59391cc2bbe76a9b8bfab5
#   Source      : 30-style-mono-green.sh
#   Type        : library
#   Group       : UI
#   Subgroup    : Styles
#   Purpose     : Define the Monochrome Green semantic UI theme
#
# Description:
#   Provides a classic monochrome green terminal theme inspired by traditional phosphor displays.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================

SAY_DATE_DEFAULT=0
SAY_SHOW_DEFAULT="label"
SAY_COLORIZE_DEFAULT="label"
SAY_DATE_FORMAT="%Y-%m-%d %H:%M:%S"

LBL_CNCL="CANCEL"
LBL_EMPTY="     "
LBL_END="END"
LBL_FAIL="ERROR"
LBL_INFO="INFO"
LBL_OK="SUCCESS"
LBL_STRT="START"
LBL_WARN="WARNING"
LBL_DEBUG="DEBUG"

ICO_CNCL=$'[STOP]'
ICO_EMPTY=$''
ICO_END=$'[END]'
ICO_FAIL=$'[ERR]'
ICO_INFO=$'[INF]'
ICO_OK=$'[OK]'
ICO_STRT=$'[RUN]'
ICO_WARN=$'[WRN]'
ICO_DEBUG=$'[DBG]'

SYM_CNCL="(-)"
SYM_EMPTY=""
SYM_END="<<<"
SYM_FAIL="(X)"
SYM_INFO="(+)"
SYM_OK="(+)"
SYM_STRT=">>>"
SYM_WARN="(!)"
SYM_DEBUG="(~)"

MSG_CLR_INFO=$GREEN
MSG_CLR_STRT=$BRIGHT_GREEN
MSG_CLR_OK=$BRIGHT_GREEN
MSG_CLR_WARN=$YELLOW
MSG_CLR_FAIL=$BRIGHT_RED
MSG_CLR_CNCL=$DARK_GREEN
MSG_CLR_END=$BRIGHT_GREEN
MSG_CLR_EMPTY=$DARK_GREEN
MSG_CLR_DEBUG=$TEAL

PROG_BAR_CLR=$BRIGHT_GREEN
PROG_IND_CLR=$GREEN
PROG_TEXT_CLR=$GREEN

SGND_UI_BORDER=$GREEN
SGND_UI_LABEL=$GREEN
SGND_UI_VALUE=$BRIGHT_GREEN
SGND_UI_COMMIT=$BRIGHT_GREEN
SGND_UI_DRYRUN=$DARK_GREEN
SGND_UI_ENABLED=$BRIGHT_GREEN
SGND_UI_DISABLED=$DARK_GREEN
SGND_UI_ON=$BRIGHT_GREEN
SGND_UI_OFF=$DARK_GREEN
SGND_UI_INPUT=$BRIGHT_GREEN
SGND_UI_PROMPT=$GREEN
SGND_UI_INVALID=$YELLOW
SGND_UI_VALID=$BRIGHT_GREEN
SGND_UI_SUCCESS=$BRIGHT_GREEN
SGND_UI_ERROR=$BRIGHT_RED
SGND_UI_TEXT=$GREEN
SGND_UI_BOLD="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")"
SGND_UI_FAINT="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_FAINT")"
SGND_UI_ITALIC="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_ITALIC")"

# Title bar
SGND_TITLE_TEXTCLR="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")"
SGND_TITLE_BORDER=$DL_H
SGND_TITLE_SUBTEXTCLR="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_ITALIC")"
SGND_TITLE_RIGHTCLR=$SGND_TITLE_TEXTCLR
SGND_TITLE_BORDERCLR=$SGND_UI_BORDER

# Section headers
SGND_SECTION_TEXTCLR="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")"
SGND_SECTION_BORDER=$LN_H
SGND_SECTION_BORDERCLR=$SGND_UI_BORDER

SGND_UI_DEFAULT=$DARK_GREEN

# - Documentation summaries ---------------------------------------------------------
    # var: style_say_global_defaults - say() global defaults
        # . Purpose
        #   Document the variables assigned in this style file.
        #
        # Variables:
        #   SAY_DATE_DEFAULT = 0
        #   SAY_SHOW_DEFAULT = "label"
        #   SAY_COLORIZE_DEFAULT = "label"
        #   SAY_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"
        #
        # Notes:
        #   Values are shown as effectively assigned by this file. Referenced palette
        #   variables are resolved by the active palette when the style is sourced.

    # var: style_say_prefixes - Say prefixes
        # . Purpose
        #   Document the variables assigned in this style file.
        #
        # Variables:
        #   LBL_CNCL = "CANCEL"
        #   LBL_EMPTY = "     "
        #   LBL_END = "END"
        #   LBL_FAIL = "ERROR"
        #   LBL_INFO = "INFO"
        #   LBL_OK = "SUCCESS"
        #   LBL_STRT = "START"
        #   LBL_WARN = "WARNING"
        #   LBL_DEBUG = "DEBUG"
        #   ICO_CNCL = $'[STOP]'
        #   ICO_EMPTY = $''
        #   ICO_END = $'[END]'
        #   ICO_FAIL = $'[ERR]'
        #   ICO_INFO = $'[INF]'
        #   ICO_OK = $'[OK]'
        #   ICO_STRT = $'[RUN]'
        #   ICO_WARN = $'[WRN]'
        #   ICO_DEBUG = $'[DBG]'
        #   SYM_CNCL = "(-)"
        #   SYM_EMPTY = ""
        #   SYM_END = "<<<"
        #   SYM_FAIL = "(X)"
        #   SYM_INFO = "(+)"
        #   SYM_OK = "(+)"
        #   SYM_STRT = ">>>"
        #   SYM_WARN = "(!)"
        #   SYM_DEBUG = "(~)"
        #
        # Notes:
        #   Values are shown as effectively assigned by this file. Referenced palette
        #   variables are resolved by the active palette when the style is sourced.

    # var: style_colors - Colors
        # . Purpose
        #   Document the variables assigned in this style file.
        #
        # Variables:
        #   MSG_CLR_INFO = $GREEN
        #   MSG_CLR_STRT = $BRIGHT_GREEN
        #   MSG_CLR_OK = $BRIGHT_GREEN
        #   MSG_CLR_WARN = $YELLOW
        #   MSG_CLR_FAIL = $BRIGHT_RED
        #   MSG_CLR_CNCL = $DARK_GREEN
        #   MSG_CLR_END = $BRIGHT_GREEN
        #   MSG_CLR_EMPTY = $DARK_GREEN
        #   MSG_CLR_DEBUG = $TEAL
        #   PROG_BAR_CLR = $BRIGHT_GREEN
        #   PROG_IND_CLR = $GREEN
        #   PROG_TEXT_CLR = $GREEN
        #   SGND_UI_BORDER = $GREEN
        #   SGND_UI_LABEL = $GREEN
        #   SGND_UI_VALUE = $BRIGHT_GREEN
        #   SGND_UI_COMMIT = $BRIGHT_GREEN
        #   SGND_UI_DRYRUN = $DARK_GREEN
        #   SGND_UI_ENABLED = $BRIGHT_GREEN
        #   SGND_UI_DISABLED = $DARK_GREEN
        #   SGND_UI_ON = $BRIGHT_GREEN
        #   SGND_UI_OFF = $DARK_GREEN
        #   SGND_UI_INPUT = $BRIGHT_GREEN
        #   SGND_UI_PROMPT = $GREEN
        #   SGND_UI_INVALID = $YELLOW
        #   SGND_UI_VALID = $BRIGHT_GREEN
        #   SGND_UI_SUCCESS = $BRIGHT_GREEN
        #   SGND_UI_ERROR = $BRIGHT_RED
        #   SGND_UI_TEXT = $GREEN
        #   SGND_UI_BOLD = bold SGND_UI_TEXT
        #   SGND_UI_FAINT = faint SGND_UI_TEXT
        #   SGND_UI_ITALIC = italic SGND_UI_TEXT
        #   SGND_TITLE_TEXTCLR = bold SGND_UI_TEXT
        #   SGND_TITLE_BORDER = $DL_H
        #   SGND_TITLE_SUBTEXTCLR = italic SGND_UI_TEXT
        #   SGND_TITLE_RIGHTCLR = SGND_TITLE_TEXTCLR
        #   SGND_TITLE_BORDERCLR = SGND_UI_BORDER
        #   SGND_SECTION_TEXTCLR = bold SGND_UI_TEXT
        #   SGND_SECTION_BORDER = $LN_H
        #   SGND_SECTION_BORDERCLR = SGND_UI_BORDER
        #   SGND_UI_DEFAULT = $DARK_GREEN
        #
        # Notes:
        #   Values are shown as effectively assigned by this file. Referenced palette
        #   variables are resolved by the active palette when the style is sourced.
