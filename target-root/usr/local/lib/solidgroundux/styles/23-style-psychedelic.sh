# =====================================================================================
# SolidGroundUX - Psychedelic UI Style
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
#   Checksum    : a0956cbc169d47ba7bf5190c7b6c648e08f555ae60c1525094d75a539b1868bb
#   Source      : 23-style-psychedelic.sh
#   Type        : library
#   Group       : UI
#   Subgroup    : Styles
#   Purpose     : Define the Psychedelic semantic UI theme
#
# Description:
#   Provides a vivid multi-colour semantic UI theme emphasizing contrast and experimentation.
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
MSG_CLR_INFO=$GOLD
MSG_CLR_STRT=$BRIGHT_GOLD
MSG_CLR_OK=$BRIGHT_GOLD
MSG_CLR_WARN=$BRIGHT_ORANGE
MSG_CLR_FAIL=$BRIGHT_RED
MSG_CLR_CNCL=$DARK_GOLD
MSG_CLR_END=$BRIGHT_GOLD
MSG_CLR_EMPTY=$DARK_BROWN
MSG_CLR_DEBUG=$DARK_ORANGE

  # def: Colors — Console UI
SGND_UI_BORDER=$BRIGHT_MAGENTA

SGND_UI_LABEL=$BRIGHT_CYAN
SGND_UI_VALUE=$BRIGHT_YELLOW

SGND_UI_COMMIT=$BRIGHT_GREEN
SGND_UI_DRYRUN=$BRIGHT_BLUE

SGND_UI_ENABLED=$BRIGHT_GREEN
SGND_UI_DISABLED=$MAGENTA
SGND_UI_ON=$BRIGHT_GREEN
SGND_UI_OFF=$MAGENTA

SGND_UI_INPUT=$BRIGHT_WHITE
SGND_UI_PROMPT=$BRIGHT_CYAN

SGND_UI_INVALID=$BRIGHT_RED
SGND_UI_VALID=$BRIGHT_GREEN

SGND_UI_ERROR="$(sgnd_sgr "$BRIGHT_YELLOW" "$RED" "$FX_BOLD")"
SGND_UI_SUCCESS="$(sgnd_sgr "$BLACK" "$BRIGHT_GREEN" "$FX_BOLD")"
SGND_UI_PROMPT="$(sgnd_sgr "$BRIGHT_CYAN" "$MAGENTA" "$FX_BOLD")"

SGND_UI_TEXT=$BRIGHT_MAGENTA
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
SGND_UI_DEFAULT=$BRIGHT_BLUE

  # def: Colors — Progress indicators
PROG_TEXT_CLR=$BRIGHT_WHITE
PROG_IND_CLR=$BRIGHT_CYAN
PROG_BAR_CLR=$BRIGHT_MAGENTA
  # def$
