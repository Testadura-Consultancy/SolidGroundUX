# =====================================================================================
# SolidGroundUX - Monochrome Blue UI Style
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627412
#   Checksum    : a212b901f6d2a1992def323e4a64ba0bff9d1a293ebee2af78e741a5ca789839
#   Source      : 32-style-mono-blue.sh
#   Type        : library
#   Group       : UI
#   Subgroup    : Styles
#   Purpose     : Define the Monochrome Blue semantic UI theme
#
# Description:
#   Provides a monochrome blue terminal theme with a cool, focused presentation.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================

# - say() global defaults -----------------------------------------------------------
SAY_DATE_DEFAULT=0
SAY_SHOW_DEFAULT="label"
SAY_COLORIZE_DEFAULT="label"
SAY_DATE_FORMAT="%Y-%m-%d %H:%M:%S"

# - Say prefixes --------------------------------------------------------------------
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

# - Semantic colors -----------------------------------------------------------------
MSG_CLR_INFO=$GOLD
MSG_CLR_STRT=$BRIGHT_GOLD
MSG_CLR_OK=$BRIGHT_GOLD
MSG_CLR_WARN=$BRIGHT_ORANGE
MSG_CLR_FAIL=$BRIGHT_RED
MSG_CLR_CNCL=$DARK_GOLD
MSG_CLR_END=$BRIGHT_GOLD
MSG_CLR_EMPTY=$DARK_BROWN
MSG_CLR_DEBUG=$DARK_ORANGE

PROG_BAR_CLR=$BRIGHT_GOLD
PROG_IND_CLR=$BRIGHT_ORANGE
PROG_TEXT_CLR=$GOLD

SGND_UI_BORDER=$BLUE

SGND_UI_LABEL=$BRIGHT_BLUE
SGND_UI_VALUE=$BRIGHT_BLUE

SGND_UI_COMMIT=$BRIGHT_BLUE
SGND_UI_DRYRUN=$BLUE

SGND_UI_ENABLED=$BRIGHT_BLUE
SGND_UI_DISABLED=$DARK_BLUE
SGND_UI_ON=$BRIGHT_BLUE
SGND_UI_OFF=$DARK_BLUE

SGND_UI_INPUT=$BRIGHT_BLUE
SGND_UI_PROMPT=$BRIGHT_BLUE

SGND_UI_INVALID=$BRIGHT_BLUE
SGND_UI_VALID=$BRIGHT_BLUE

SGND_UI_SUCCESS=$BRIGHT_BLUE
SGND_UI_ERROR=$BRIGHT_BLUE

SGND_UI_TEXT=$BLUE
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

SGND_UI_DEFAULT=$DARK_BLUE

PROG_TEXT_CLR=$BLUE
PROG_IND_CLR=$BRIGHT_BLUE
PROG_BAR_CLR=$BRIGHT_BLUE

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
        #   MSG_CLR_INFO = $GOLD
        #   MSG_CLR_STRT = $BRIGHT_GOLD
        #   MSG_CLR_OK = $BRIGHT_GOLD
        #   MSG_CLR_WARN = $BRIGHT_ORANGE
        #   MSG_CLR_FAIL = $BRIGHT_RED
        #   MSG_CLR_CNCL = $DARK_GOLD
        #   MSG_CLR_END = $BRIGHT_GOLD
        #   MSG_CLR_EMPTY = $DARK_BROWN
        #   MSG_CLR_DEBUG = $DARK_ORANGE
        #   PROG_BAR_CLR = $BRIGHT_BLUE
        #   PROG_IND_CLR = $BRIGHT_BLUE
        #   PROG_TEXT_CLR = $BLUE
        #   SGND_UI_BORDER = $BLUE
        #   SGND_UI_LABEL = $BRIGHT_BLUE
        #   SGND_UI_VALUE = $BRIGHT_BLUE
        #   SGND_UI_COMMIT = $BRIGHT_BLUE
        #   SGND_UI_DRYRUN = $BLUE
        #   SGND_UI_ENABLED = $BRIGHT_BLUE
        #   SGND_UI_DISABLED = $DARK_BLUE
        #   SGND_UI_ON = $BRIGHT_BLUE
        #   SGND_UI_OFF = $DARK_BLUE
        #   SGND_UI_INPUT = $BRIGHT_BLUE
        #   SGND_UI_PROMPT = $BRIGHT_BLUE
        #   SGND_UI_INVALID = $BRIGHT_BLUE
        #   SGND_UI_VALID = $BRIGHT_BLUE
        #   SGND_UI_SUCCESS = $BRIGHT_BLUE
        #   SGND_UI_ERROR = $BRIGHT_BLUE
        #   SGND_UI_TEXT = $BLUE
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
        #   SGND_UI_DEFAULT = $DARK_BLUE
        #
        # Notes:
        #   Values are shown as effectively assigned by this file. Referenced palette
        #   variables are resolved by the active palette when the style is sourced.
