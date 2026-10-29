# ==================================================================================
# SolidGroundUX - Framework Services Overview
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627700
#   Checksum    : 1b82f55c30db031f96de7f475ab360c7cee9d4836423fb0a85db574c8eab797a
#   Source      : sux-common-core-preface.sh
#   Type        : documentation
#   Group       : Common Core
#   Purpose     : Group preface
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
#  
# - Available Services -----------------------------------------------------------------
#
# > This chapter introduces the major framework services available to application
# > developers. While each subsystem is documented individually, this overview
# > explains how the various components work together.
#  
# -- Configuration Management --------------------------------------------------------
#  
# > The configuration subsystem provides a consistent mechanism for loading,
# > validating, modifying, and persisting application settings.
#  
# > Configuration values typically represent user preferences or application
# > settings that remain relatively static between executions.
#  
# -- State Management ----------------------------------------------------------------
#  
# > The state subsystem stores runtime information that applications may wish to
# > remember between executions.
#  
# > Unlike configuration values, state represents remembered runtime choices and
# > workflow context such as previous selections, recently used values, UI choices,
# > or cached information. Scripts opt individual values into persistence explicitly.
# >
# . Images
#   sux-config-state-precedence.png :: Configuration and state precedence in SolidGroundUX.
#
# -- Command-Line Arguments ----------------------------------------------------------
#  
# >
# > The argument subsystem provides standardized command-line processing. After the
# > bootstrap separates framework options from script arguments, applications can
# > define their own declarative argument specification while retaining framework
# > built-ins such as help, version reporting, tracing, debugging, and configuration
# > overrides.
# >
# > DRYRUN is a framework-wide execution contract rather than merely a display flag.
# > When DRYRUN is active, cooperating framework tools and delegated actions must avoid
# > persistent changes, including configuration/state writes and system modifications.
#
# -- User Interface Services ---------------------------------------------------------
#
# > The UI subsystem provides a collection of functions intended to simplify
# > communication with the user.
#   
# > Common operations such as informational messages, warnings, errors,
# > confirmations, prompts, selections, and formatted output are provided through
# > a consistent interface.
#
# -- Console Applications ------------------------------------------------------------
#
# > `sgnd-menu.sh` provides a reusable public menu service independent of the SolidGround
# > Management Console host. Applications can create menu models, register groups and
# > items, render pages, read selections, and dispatch registered actions through the
# > public `sgnd_menu_*` API.
# >
# > The Management Console is one consumer of that API. Its page modules are discovered
# > from lightweight metadata and sourced lazily when first opened.
#
# -- Documentation Generation --------------------------------------------------------
#
# > The SDK documentation generator can extract documentation directly from these source files.
#   
# > Product information, architecture descriptions, API documentation, appendices,
# > glossaries, and implementation notes are all maintained close to the source
# > code and transformed into a navigable HTML documentation set.
#  
# > This approach helps ensure that documentation remains synchronized with the
# > implementation and reduces the risk of documentation becoming outdated.
