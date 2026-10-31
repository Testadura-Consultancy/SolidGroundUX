# =====================================================================================
# SolidGroundUX - Dark UI Style
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
#   Checksum    : 7296787544d128753f71a87c1c1789b944069d8f1d7bebced036b6a0a61ee821
#   Source      : 10-style-dark.sh
#   Type        : library
#   Group       : UI
#   Subgroup    : Styles
#   Purpose     : Define the Dark semantic UI theme
#
# Description:
#   Provides a balanced dark semantic UI theme designed for clear, everyday console use.
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

# Message output
  # def: Colors — Messages
MSG_CLR_INFO=$SILVER
MSG_CLR_STRT=$BRIGHT_WHITE
MSG_CLR_OK=$BRIGHT_WHITE
MSG_CLR_WARN=$SILVER
MSG_CLR_FAIL=$BRIGHT_WHITE
MSG_CLR_CNCL=$GRAY
MSG_CLR_END=$SILVER
MSG_CLR_EMPTY=$DARK_SILVER
MSG_CLR_DEBUG=$DARK_SILVER

# Progress display
  # def: Colors — Progress indicators
PROG_BAR_CLR=$GRAY
PROG_IND_CLR=$SILVER
PROG_TEXT_CLR=$SILVER

# General UI elements
  # def: Colors — Console UI
SGND_UI_BORDER=$GRAY
SGND_UI_LABEL=$SILVER
SGND_UI_VALUE=$BRIGHT_WHITE
SGND_UI_TEXT=$SILVER
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
SGND_UI_DEFAULT=$DARK_SILVER

# Run modes
  # def: Colors — Run modes
SGND_UI_COMMIT=$BRIGHT_WHITE
SGND_UI_DRYRUN=$SILVER

# States and validation
  # def: Colors — States and validation
SGND_UI_ENABLED=$BRIGHT_WHITE
SGND_UI_DISABLED=$DARK_GRAY
SGND_UI_ON=$BRIGHT_WHITE
SGND_UI_OFF=$DARK_SILVER
SGND_UI_VALID=$BRIGHT_WHITE
SGND_UI_INVALID=$SILVER
SGND_UI_SUCCESS=$BRIGHT_WHITE
SGND_UI_ERROR=$BRIGHT_WHITE

# Prompt and input
  # def: Colors — Prompt and input
SGND_UI_PROMPT=$SILVER
SGND_UI_INPUT=$BRIGHT_WHITE
  # def$
