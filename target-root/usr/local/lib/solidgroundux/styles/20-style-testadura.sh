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

  # def: say() global defaults
SAY_DATE_DEFAULT=0
SAY_SHOW_DEFAULT="label"
SAY_COLORIZE_DEFAULT="label"
SAY_DATE_FORMAT="%Y-%m-%d %H:%M:%S"
  # def$

  # Labels
    # def: Status indicators | pivot=LBL:Label,ICO:Icon,SYM:Symbol
    LBL_CNCL="CANCEL"
    LBL_EMPTY="     "
    LBL_END="END"
    LBL_FAIL="ERROR"
    LBL_INFO="INFO"
    LBL_OK="SUCCESS"
    LBL_STRT="START"
    LBL_WARN="WARNING"
    LBL_DEBUG="DEBUG"

  # Icons
    ICO_CNCL=$'⏹️'
    ICO_EMPTY=$''
    ICO_END=$'🏁'
    ICO_FAIL=$'❌'
    ICO_INFO=$'ℹ️'
    ICO_OK=$'✅'
    ICO_STRT=$'▶️'
    ICO_WARN=$'⚠️'
    ICO_DEBUG=$'🐞'

  # Symbols
    SYM_CNCL="(-)"
    SYM_EMPTY=""
    SYM_END="<<<"
    SYM_FAIL="(X)"
    SYM_INFO="(+)"
    SYM_OK="(✓)"
    SYM_STRT=">>>"
    SYM_WARN="(!)"
    SYM_DEBUG="(~)"
    # def$


  # def: Colors — Messages
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

  # def: Colors — Progress indicators
PROG_BAR_CLR=$TD_GOLD
PROG_IND_CLR=$TD_MAROON
PROG_TEXT_CLR=$TD_SILVER

# - Semantic UI colors -------------------------------------------------------------

  # def: Colors — Console UI
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
  # def: Colors — Title bar
SGND_TITLE_TEXTCLR="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")"
SGND_TITLE_BORDER=$DL_H
SGND_TITLE_SUBTEXTCLR="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_ITALIC")"
SGND_TITLE_RIGHTCLR=$SGND_TITLE_TEXTCLR
SGND_TITLE_BORDERCLR=$SGND_UI_BORDER

# Section headers
  # def: Colors — Section headers
SGND_SECTION_TEXTCLR="$(sgnd_sgr "$SGND_UI_TEXT" "" "$FX_BOLD")"
SGND_SECTION_BORDER=$LN_H
SGND_SECTION_BORDERCLR=$SGND_UI_BORDER

# DataTable colors (theme defaults; function arguments may override them)
  # def: Colors — DataTable
SGND_DT_HEADERLINE_CLR=$SGND_UI_BORDER
SGND_DT_COLUMNNAME_CLR="$(sgnd_sgr "$SGND_UI_LABEL" "" "$FX_BOLD")"
SGND_DT_DATACOLOR_CLR=$SGND_UI_TEXT

  # def: Colors — Default
SGND_UI_DEFAULT=$TD_DARK_MAROON
  # def$
