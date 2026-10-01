# =====================================================================================
# SolidGroundUX - Default UI Palette
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627412
#   Checksum    : d97fd529b9b7ed1588810c9347b69286dedf69a9b93a7e9752be3a00bf33191f
#   Source      : default-ui-palette.sh
#   Type        : library
#   Group       : UI
#   Subgroup    : Styles
#   Purpose     : Define default color palette and styling for console UI
#
# Description:
#   Provides the default color and style definitions used by the
#   SolidGroundUX UI layer.
#
#   The library:
#     - Defines deterministic 24-bit RGB color variables for labels, input, and message types
#     - Establishes consistent visual identity across console tools
#     - Supplies defaults for UI modules such as ui.sh, ui-ask, and ui-say
#     - Allows overriding by alternative palettes or user configuration
#
# Design principles:
#   - Centralize all color definitions in one place
#   - Keep naming semantic (INFO, WARN, LABEL, INPUT, etc.)
#   - Allow easy customization without touching rendering logic
#   - Ensure deterministic color rendering across truecolor-capable terminals
#
# Role in framework:
#   - Default styling layer for all console rendering
#   - Used by UI modules to apply consistent colors and emphasis
#   - Can be replaced or extended for theming purposes
#
# Non-goals:
#   - Rendering logic or layout behavior
#   - Terminal capability detection
#   - Dynamic theme switching at runtime
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================

# - Text attributes (SGR) -----------------------------------------------------------
  # Note: Support depends on terminal emulator; bold and underline are
  # universally supported, others may be ignored gracefully.

  FX_RESET=0          # Reset all attributes
  FX_BOLD=1           # Bold / increased intensity
  FX_FAINT=2          # Faint / decreased intensity
  FX_ITALIC=3         # Italic (not supported by all terminals)
  FX_UNDERLINE=4      # Underline
  FX_BLINK=5          # Slow blink (often ignored)
  FX_REVERSE=7        # Reverse foreground/background
  FX_CONCEAL=8        # Conceal / hidden text (rarely useful)
  FX_STRIKE=9         # Strikethrough (not universally supported)

  # var: style_text_attributes_sgr - Text attributes (SGR)
      # . Purpose
      #   Document the variables assigned in this style section.
      #
      # Variables:
      #   FX_RESET = 0
      #   FX_BOLD = 1
      #   FX_FAINT = 2
      #   FX_ITALIC = 3
      #   FX_UNDERLINE = 4
      #   FX_BLINK = 5
      #   FX_REVERSE = 7
      #   FX_CONCEAL = 8
      #   FX_STRIKE = 9
      #
      # Notes:
      #   Values are shown as assigned by this file. Referenced palette variables
      #   are resolved by the active palette when the style is sourced.
# - Color codes ---------------------------------------------------------------------
  # Reset
    RESET=$'\e[0m'
    # var: style_color_codes - Color codes
        # . Purpose
        #   Document the variables assigned in this style section.
        #
        # Variables:
        #   RESET = $'\e[0m'
        #
        # Notes:
        #   Values are shown as assigned by this file. Referenced palette variables
        #   are resolved by the active palette when the style is sourced.
# - Foreground colors ---------------------------------------------------------------
  # Naming conventions:
  #   DARK_*    : darker / muted RGB variants
  #   *         : normal RGB colors
  #   BRIGHT_*  : brighter RGB variants
  #
  # Notes:
  #   - Foreground colors use 24-bit SGR truecolor sequences: 38;2;R;G;B
  #   - Color values are terminal-palette independent on truecolor-capable terminals
  #   - These MUST NOT be reused as background colors
  #   - Always terminate styled output with $RESET

# var: style_foreground_dark_muted - Foreground: Dark / muted
      # Variables:
      #   DARK_RED = $'\e[38;2;135;0;0m'
      #   DARK_GREEN = $'\e[38;2;0;95;0m'
      #   DARK_YELLOW = $'\e[38;2;135;95;0m'
      #   DARK_BLUE = $'\e[38;2;0;0;135m'
      #   DARK_MAGENTA = $'\e[38;2;135;0;135m'
      #   DARK_CYAN = $'\e[38;2;0;95;95m'
      #   DARK_WHITE = $'\e[38;2;155;155;155m'   # or drop DARK_WHITE entirely
      #   DARK_GRAY = $'\e[38;2;88;88;88m'
      #   DARK_ORANGE = $'\e[38;2;175;95;0m'
      #   DARK_SILVER = $'\e[38;2;138;138;138m'
      #   DARK_PURPLE = $'\e[38;2;95;0;175m'
      #   DARK_TEAL = $'\e[38;2;0;135;95m'
      #   DARK_PINK = $'\e[38;2;215;95;135m'
      #   DARK_GOLD = $'\e[38;2;215;175;0m'
      #   DARK_BROWN = $'\e[38;2;135;95;0m'
      #
      # Notes:
      #   Values are shown as assigned by this file. Referenced palette variables
      #   are resolved by the active palette when the style is sourced.
  DARK_RED=$'\e[38;2;135;0;0m'
  DARK_GREEN=$'\e[38;2;0;95;0m'
  DARK_YELLOW=$'\e[38;2;135;95;0m'
  DARK_BLUE=$'\e[38;2;0;0;135m' 
  DARK_MAGENTA=$'\e[38;2;135;0;135m'
  DARK_CYAN=$'\e[38;2;0;95;95m'
  DARK_WHITE=$'\e[38;2;155;155;155m'   # or drop DARK_WHITE entirely
  DARK_GRAY=$'\e[38;2;88;88;88m'
  DARK_ORANGE=$'\e[38;2;175;95;0m'
  DARK_SILVER=$'\e[38;2;138;138;138m'
  DARK_PURPLE=$'\e[38;2;95;0;175m' 
  DARK_TEAL=$'\e[38;2;0;135;95m' 
  DARK_PINK=$'\e[38;2;215;95;135m'
  DARK_GOLD=$'\e[38;2;215;175;0m'
  DARK_BROWN=$'\e[38;2;135;95;0m'

  # var: style_foreground_normal - Foreground: Normal
      # Variables:
      #   BLACK = $'\e[38;2;0;0;0m'
      #   RED = $'\e[38;2;190;45;45m'
      #   GREEN = $'\e[38;2;0;190;70m'
      #   YELLOW = $'\e[38;2;215;190;0m'
      #   BLUE = $'\e[38;2;40;135;235m'
      #   MAGENTA = $'\e[38;2;128;0;128m'
      #   CYAN = $'\e[38;2;0;190;210m'
      #   WHITE = $'\e[38;2;192;192;192m'
      #   GRAY = $'\e[38;2;138;138;138m'
      #   ORANGE = $'\e[38;2;255;145;0m'
      #   SILVER = $'\e[0;38;5;250m'
      #   PURPLE = $'\e[38;2;135;0;255m'
      #   TEAL = $'\e[38;2;0;195;165m'
      #   PINK = $'\e[38;2;255;135;255m'
      #   GOLD = $'\e[38;2;255;215;0m'
      #   BROWN = $'\e[38;2;175;95;0m'
      #
      # Notes:
      #   Values are shown as assigned by this file. Referenced palette variables
      #   are resolved by the active palette when the style is sourced.
  BLACK=$'\e[38;2;0;0;0m'
  RED=$'\e[38;2;190;45;45m'
  GREEN=$'\e[38;2;0;190;70m'
  YELLOW=$'\e[38;2;215;190;0m'
  BLUE=$'\e[38;2;40;135;235m'
  MAGENTA=$'\e[38;2;128;0;128m'
  CYAN=$'\e[38;2;0;190;210m'
  WHITE=$'\e[38;2;192;192;192m'
  GRAY=$'\e[38;2;138;138;138m'
  ORANGE=$'\e[38;2;255;145;0m'
  SILVER=$'\e[0;38;5;250m'
  PURPLE=$'\e[38;2;135;0;255m'         
  TEAL=$'\e[38;2;0;195;165m'  
  PINK=$'\e[38;2;255;135;255m' 
  GOLD=$'\e[38;2;255;215;0m' 
  BROWN=$'\e[38;2;175;95;0m'

  # var: style_foreground_bright - Foreground: Bright
      # . Purpose
      #   Document the variables assigned in this style section.
      #
      # Variables:
      #   BRIGHT_RED = $'\e[38;2;255;70;70m'
      #   BRIGHT_GREEN = $'\e[38;2;70;255;110m'
      #   BRIGHT_YELLOW = $'\e[38;2;255;245;55m'
      #   BRIGHT_BLUE = $'\e[38;2;80;190;255m'
      #   BRIGHT_MAGENTA = $'\e[38;2;255;0;255m'
      #   BRIGHT_CYAN = $'\e[38;2;70;255;255m'
      #   BRIGHT_WHITE = $'\e[38;2;255;255;255m'
      #   BRIGHT_ORANGE = $'\e[38;2;255;190;45m'
      #   BRIGHT_PURPLE = $'\e[38;2;175;95;255m'
      #   BRIGHT_TEAL = $'\e[38;2;55;255;205m'
      #   BRIGHT_PINK = $'\e[38;2;255;175;255m'
      #   BRIGHT_GOLD = $'\e[38;2;255;255;0m'
      #   BRIGHT_BROWN = $'\e[38;2;215;135;0m'
      #
      # Notes:
      #   Values are shown as assigned by this file. Referenced palette variables
      #   are resolved by the active palette when the style is sourced.
  BRIGHT_RED=$'\e[38;2;255;70;70m'
  BRIGHT_GREEN=$'\e[38;2;70;255;110m'
  BRIGHT_YELLOW=$'\e[38;2;255;245;55m'
  BRIGHT_BLUE=$'\e[38;2;80;190;255m'
  BRIGHT_MAGENTA=$'\e[38;2;255;0;255m'
  BRIGHT_CYAN=$'\e[38;2;70;255;255m'
  BRIGHT_WHITE=$'\e[38;2;255;255;255m'
  BRIGHT_ORANGE=$'\e[38;2;255;190;45m' 
  BRIGHT_PURPLE=$'\e[38;2;175;95;255m'
  BRIGHT_TEAL=$'\e[38;2;55;255;205m'
  BRIGHT_PINK=$'\e[38;2;255;175;255m' 
  BRIGHT_GOLD=$'\e[38;2;255;255;0m'  
  BRIGHT_BROWN=$'\e[38;2;215;135;0m'


# - Background colors ---------------------------------------------------------------
  # Naming conventions:
  #   BG_DARK_*    : darker / muted RGB background shades
  #   BG_*         : normal RGB background colors
  #   BG_BRIGHT_*  : brighter RGB background variants
  #
  # Notes:
  #   - Background colors use 24-bit SGR truecolor sequences: 48;2;R;G;B
  #   - Background colors are independent of foreground colors
  #   - Combine with foreground colors by concatenation:
  #       printf "%s%sText%s\n" "$BG_DARK_BLUE" "$BRIGHT_WHITE" "$RESET"


  # var: style_background_dark_muted - Background: Dark / muted
      # . Purpose
      #   Document the variables assigned in this style section.
      #
      # Variables:
      #   BG_DARK_RED = $'\e[48;2;135;0;0m'
      #   BG_DARK_GREEN = $'\e[48;2;0;95;0m'
      #   BG_DARK_YELLOW = $'\e[48;2;135;95;0m'
      #   BG_DARK_BLUE = $'\e[48;2;0;0;135m'
      #   BG_DARK_MAGENTA = $'\e[48;2;135;0;135m'
      #   BG_DARK_CYAN = $'\e[48;2;0;95;95m'
      #   BG_DARK_WHITE = $'\e[48;2;188;188;188m'
      #   BG_DARK_GRAY = $'\e[48;2;28;28;28m'
      #   BG_DARK_ORANGE = $'\e[48;2;175;95;0m'
      #   BG_DARK_SILVER = $'\e[48;2;138;138;138m'
      #   BG_DARK_PURPLE = $'\e[48;2;95;0;175m'
      #   BG_DARK_TEAL = $'\e[48;2;0;135;95m'
      #   BG_DARK_PINK = $'\e[48;2;215;95;135m'
      #   BG_DARK_GOLD = $'\e[48;2;215;175;0m'
      #   BG_DARK_BROWN = $'\e[48;2;135;95;0m'
      #
      # Notes:
      #   Values are shown as assigned by this file. Referenced palette variables
      #   are resolved by the active palette when the style is sourced.
  BG_DARK_RED=$'\e[48;2;135;0;0m'
  BG_DARK_GREEN=$'\e[48;2;0;95;0m'
  BG_DARK_YELLOW=$'\e[48;2;135;95;0m'
  BG_DARK_BLUE=$'\e[48;2;0;0;135m'
  BG_DARK_MAGENTA=$'\e[48;2;135;0;135m'
  BG_DARK_CYAN=$'\e[48;2;0;95;95m'
  BG_DARK_WHITE=$'\e[48;2;188;188;188m'
  BG_DARK_GRAY=$'\e[48;2;28;28;28m'
  BG_DARK_ORANGE=$'\e[48;2;175;95;0m'
  BG_DARK_SILVER=$'\e[48;2;138;138;138m'
  BG_DARK_PURPLE=$'\e[48;2;95;0;175m'
  BG_DARK_TEAL=$'\e[48;2;0;135;95m'
  BG_DARK_PINK=$'\e[48;2;215;95;135m'
  BG_DARK_GOLD=$'\e[48;2;215;175;0m'
  BG_DARK_BROWN=$'\e[48;2;135;95;0m'

  # var: style_background_normal - Background: Normal
      # . Purpose
      #   Document the variables assigned in this style section.
      #
      # Variables:
      #   BG_BLACK = $'\e[48;2;0;0;0m'
      #   BG_RED = $'\e[48;2;128;0;0m'
      #   BG_GREEN = $'\e[48;2;0;128;0m'
      #   BG_YELLOW = $'\e[48;2;128;128;0m'
      #   BG_BLUE = $'\e[48;2;0;0;128m'
      #   BG_MAGENTA = $'\e[48;2;128;0;128m'
      #   BG_CYAN = $'\e[48;2;0;128;128m'
      #   BG_WHITE = $'\e[48;2;192;192;192m'
      #   BG_GRAY = $'\e[48;2;138;138;138m'
      #   BG_ORANGE = $'\e[48;2;255;135;0m'
      #   BG_SILVER = $'\e[48;2;188;188;188m'
      #   BG_PURPLE = $'\e[48;2;135;0;255m'
      #   BG_TEAL = $'\e[48;2;0;175;175m'
      #   BG_PINK = $'\e[48;2;255;135;255m'
      #   BG_GOLD = $'\e[48;2;255;215;0m'
      #   BG_BROWN = $'\e[48;2;175;95;0m'
      #
      # Notes:
      #   Values are shown as assigned by this file. Referenced palette variables
      #   are resolved by the active palette when the style is sourced.
  BG_BLACK=$'\e[48;2;0;0;0m'
  BG_RED=$'\e[48;2;128;0;0m'
  BG_GREEN=$'\e[48;2;0;128;0m'
  BG_YELLOW=$'\e[48;2;128;128;0m'
  BG_BLUE=$'\e[48;2;0;0;128m'
  BG_MAGENTA=$'\e[48;2;128;0;128m'
  BG_CYAN=$'\e[48;2;0;128;128m'
  BG_WHITE=$'\e[48;2;192;192;192m'
  BG_GRAY=$'\e[48;2;138;138;138m'
  BG_ORANGE=$'\e[48;2;255;135;0m'
  BG_SILVER=$'\e[48;2;188;188;188m'
  BG_PURPLE=$'\e[48;2;135;0;255m'
  BG_TEAL=$'\e[48;2;0;175;175m'
  BG_PINK=$'\e[48;2;255;135;255m'
  BG_GOLD=$'\e[48;2;255;215;0m'
  BG_BROWN=$'\e[48;2;175;95;0m'

  # var: style_background_bright - Background: Bright
      # . Purpose
      #   Document the variables assigned in this style section.
      #
      # Variables:
      #   BG_BRIGHT_RED = $'\e[48;2;255;0;0m'
      #   BG_BRIGHT_GREEN = $'\e[48;2;0;255;0m'
      #   BG_BRIGHT_YELLOW = $'\e[48;2;255;255;0m'
      #   BG_BRIGHT_BLUE = $'\e[48;2;0;0;255m'
      #   BG_BRIGHT_MAGENTA = $'\e[48;2;255;0;255m'
      #   BG_BRIGHT_CYAN = $'\e[48;2;0;255;255m'
      #   BG_BRIGHT_WHITE = $'\e[48;2;255;255;255m'
      #   BG_BRIGHT_ORANGE = $'\e[48;2;255;175;0m'
      #   BG_BRIGHT_PURPLE = $'\e[48;2;175;95;255m'
      #   BG_BRIGHT_TEAL = $'\e[48;2;0;255;175m'
      #   BG_BRIGHT_PINK = $'\e[48;2;255;175;255m'
      #   BG_BRIGHT_GOLD = $'\e[48;2;255;255;0m'
      #   BG_BRIGHT_BROWN = $'\e[48;2;215;135;0m'
      #
      # Notes:
      #   Values are shown as assigned by this file. Referenced palette variables
      #   are resolved by the active palette when the style is sourced.
  BG_BRIGHT_RED=$'\e[48;2;255;0;0m'
  BG_BRIGHT_GREEN=$'\e[48;2;0;255;0m'
  BG_BRIGHT_YELLOW=$'\e[48;2;255;255;0m'
  BG_BRIGHT_BLUE=$'\e[48;2;0;0;255m'
  BG_BRIGHT_MAGENTA=$'\e[48;2;255;0;255m'
  BG_BRIGHT_CYAN=$'\e[48;2;0;255;255m'
  BG_BRIGHT_WHITE=$'\e[48;2;255;255;255m'
  BG_BRIGHT_ORANGE=$'\e[48;2;255;175;0m'
  BG_BRIGHT_PURPLE=$'\e[48;2;175;95;255m'
  BG_BRIGHT_TEAL=$'\e[48;2;0;255;175m'
  BG_BRIGHT_PINK=$'\e[48;2;255;175;255m'
  BG_BRIGHT_GOLD=$'\e[48;2;255;255;0m'
  BG_BRIGHT_BROWN=$'\e[48;2;215;135;0m'

    # var: palette_testadura_brand - Testadura brand colors
        # . Purpose
        #   Define the official Testadura corporate brand colors.
        #
        # Variables:
        #   TD_MAROON = $'\e[38;2;135;0;0m'
        #   TD_GOLD   = $'\e[38;2;215;175;0m'
        #   TD_SILVER = $'\e[38;2;188;188;188m'
        #   TD_WHITE  = $'\e[38;2;255;255;255m'
        #
        # Notes:
        #   These colors represent the Testadura visual identity and are intended
        #   for use by Testadura themes and branding.

    TD_MAROON=$'\e[38;2;135;0;0m'
    TD_DARK_MAROON=$'\e[38;2;95;0;0m'

    TD_GOLD=$'\e[38;2;215;175;0m'
    TD_DARK_GOLD=$'\e[38;2;175;135;0m'

    TD_SILVER=$'\e[38;2;188;188;188m'
    TD_DARK_SILVER=$'\e[38;2;128;128;128m'

    TD_WHITE=$'\e[38;2;255;255;255m'

    # var: palette_solidground_brand - SolidGround brand colors
        # . Purpose
        #   Define the SolidGround product brand colors.
        #
        # Variables:
        #   SGND_BLUE   = $'\e[38;2;0;0;175m'
        #   SGND_GREEN  = $'\e[38;2;0;175;0m'
        #   SGND_RED    = $'\e[38;2;175;0;0m'
        #   SGND_GOLD   = $'\e[38;2;215;175;0m'
        #
        # Notes:
        #   These colors are sampled from the official SolidGround logo and may
        #   be used by themes, documentation and marketing materials.

    SGND_BLUE=$'\e[38;2;0;0;175m'
    SGND_DARK_BLUE=$'\e[38;2;0;0;135m'

    SGND_GREEN=$'\e[38;2;0;175;0m'
    SGND_DARK_GREEN=$'\e[38;2;0;95;0m'

    SGND_RED=$'\e[38;2;175;0;0m'
    SGND_DARK_RED=$'\e[38;2;135;0;0m'

    SGND_GOLD=$'\e[38;2;215;175;0m'
    SGND_DARK_GOLD=$'\e[38;2;175;135;0m'

