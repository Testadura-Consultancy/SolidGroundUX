# =====================================================================================
# SolidGroundUX - Monochrome Green UI Style
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
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
MSG_CLR_INFO=$GREEN
MSG_CLR_STRT=$BRIGHT_GREEN
MSG_CLR_OK=$BRIGHT_GREEN
MSG_CLR_WARN=$YELLOW
MSG_CLR_FAIL=$BRIGHT_RED
MSG_CLR_CNCL=$DARK_GREEN
MSG_CLR_END=$BRIGHT_GREEN
MSG_CLR_EMPTY=$DARK_GREEN
MSG_CLR_DEBUG=$TEAL

  # def: Colors — Progress indicators
PROG_BAR_CLR=$BRIGHT_GREEN
PROG_IND_CLR=$GREEN
PROG_TEXT_CLR=$GREEN

  # def: Colors — Console UI
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
SGND_UI_DEFAULT=$DARK_GREEN
  # def$
