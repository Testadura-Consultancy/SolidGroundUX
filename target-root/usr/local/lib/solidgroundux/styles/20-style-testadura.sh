# =====================================================================================
# SolidGroundUX - Testadura UI Style
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
#   Checksum    : 4aeb328c47f9c6800c12d7b1701fcc022241234b5c2f5b36cd04259d23122622
#   Source      : 20-style-testadura.sh
#   Type        : library
#   Group       : UI
#   Subgroup    : Styles
#   Purpose     : Define the Testadura semantic UI theme
#
# Description:
#   Provides the official Testadura Consultancy and SolidGroundUX brand-driven semantic UI theme.
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

# - Message colors ----------------------------------------------------------------

MSG_CLR_INFO=$TD_SILVER
MSG_CLR_STRT=$SGND_BLUE
MSG_CLR_OK=$SGND_GREEN
MSG_CLR_WARN=$SGND_GOLD
MSG_CLR_FAIL=$SGND_RED
MSG_CLR_CNCL=$TD_GOLD
MSG_CLR_END=$TD_MAROON
MSG_CLR_EMPTY=$TD_DARK_SILVER
MSG_CLR_DEBUG=$SGND_DARK_BLUE

# - Progress display ---------------------------------------------------------------

PROG_BAR_CLR=$TD_GOLD
PROG_IND_CLR=$TD_MAROON
PROG_TEXT_CLR=$TD_SILVER

# - Semantic UI colors -------------------------------------------------------------

SGND_UI_BORDER=$TD_MAROON

SGND_UI_LABEL=$TD_SILVER
SGND_UI_VALUE=$TD_GOLD

SGND_UI_COMMIT=$SGND_GREEN
SGND_UI_DRYRUN=$SGND_BLUE

SGND_UI_ENABLED=$SGND_GREEN
SGND_UI_DISABLED=$TD_DARK_SILVER
SGND_UI_ON=$SGND_GREEN
SGND_UI_OFF=$TD_DARK_SILVER

SGND_UI_INPUT=$YELLOW
SGND_UI_PROMPT=$GREEN

SGND_UI_INVALID=$SGND_RED
SGND_UI_VALID=$SGND_GREEN

SGND_UI_SUCCESS=$BRIGHT_GREEN
SGND_UI_ERROR=$BRIGHT_RED

SGND_UI_TEXT=$TD_SILVER
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

SGND_UI_DEFAULT=$TD_DARK_MAROON

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
        #   MSG_CLR_INFO = $TD_SILVER
        #   MSG_CLR_STRT = $SGND_BLUE
        #   MSG_CLR_OK = $SGND_GREEN
        #   MSG_CLR_WARN = $SGND_GOLD
        #   MSG_CLR_FAIL = $SGND_RED
        #   MSG_CLR_CNCL = $TD_GOLD
        #   MSG_CLR_END = $TD_MAROON
        #   MSG_CLR_EMPTY = $TD_DARK_SILVER
        #   MSG_CLR_DEBUG = $SGND_DARK_BLUE
        #   PROG_BAR_CLR = $TD_GOLD
        #   PROG_IND_CLR = $TD_MAROON
        #   PROG_TEXT_CLR = $TD_SILVER
        #   SGND_UI_BORDER = $TD_MAROON
        #   SGND_UI_LABEL = $TD_SILVER
        #   SGND_UI_VALUE = $TD_GOLD
        #   SGND_UI_COMMIT = $SGND_GREEN
        #   SGND_UI_DRYRUN = $SGND_BLUE
        #   SGND_UI_ENABLED = $SGND_GREEN
        #   SGND_UI_DISABLED = $TD_DARK_SILVER
        #   SGND_UI_ON = $SGND_GREEN
        #   SGND_UI_OFF = $TD_DARK_SILVER
        #   SGND_UI_INPUT = $YELLOW
        #   SGND_UI_PROMPT = $GREEN
        #   SGND_UI_INVALID = $SGND_RED
        #   SGND_UI_VALID = $SGND_GREEN
        #   SGND_UI_SUCCESS = $BRIGHT_GREEN
        #   SGND_UI_ERROR = $BRIGHT_RED
        #   SGND_UI_TEXT = $TD_SILVER
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
        #   SGND_UI_DEFAULT = $TD_DARK_MAROON
        #
        # Notes:
        #   Values are shown as effectively assigned by this file. Referenced palette
        #   variables are resolved by the active palette when the style is sourced.
