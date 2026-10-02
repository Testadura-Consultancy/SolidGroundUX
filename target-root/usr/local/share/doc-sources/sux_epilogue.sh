# ==================================================================================
# SolidGroundUX - How to?
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
#   Checksum    : f067b412f914ad6def3baceb18adb7303fadc460b5fe61d1dd8cfca8e2132eba
#   Source      : sux-epilogue.sh
#   Type        : documentation
#   Group       : SolidGroundUX
#   Purpose     : Product epilogue
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# ==================================================================================
# - How do I...? --------------------------------------------------------------------
#
# -- Add a command-line argument ----------------------------------------------------
#
# > Add an entry to SGND_ARGS_SPEC. The bootstrapper calls sgnd_parse_args and stores
# > the parsed value in the variable named by the argument specification.
#
# > Default framework arguments are handled by the framework itself. Script-specific
# > arguments are declared by the script and are included in generated help output.
#
# > Example:
# >     SGND_ARGS_SPEC=(
# >         "auto|a|flag|FLAG_AUTO|Repeat with last settings|0|"
# >         "target|t|value|DEST_ROOT|Set target directory|"
# >         "mode|m|enum|ENUM_MODE|Select mode|copy,move,link"
# >     )
#
# -- Use configuration files --------------------------------------------------------
#
# > Add configuration-driven variables to SGND_SCRIPT_GLOBALS. When this array is
# > non-empty, sgnd_bootstrap applies script configuration through
# > sgnd_cfg_domain_apply. Readable system/user cfg files are loaded automatically at
# > startup. Missing domain files can be created by the cfg layer.
#
# > Example:
# >     SGND_SCRIPT_GLOBALS=(
# >         "system|SGND_SYS_STRING|System CFG string|"
# >         "user|SGND_USR_STRING|User CFG string|"
# >         "both|SGND_COMMON_STRING|Common CFG string|"
# >     )
#
# -- Use persistent state variables -------------------------------------------------
#
# > Add state variables to SGND_STATE_VARIABLES. State support is enabled by invoking
# > the bootstrapper with state support. With autostate, registered state variables
# > are loaded at startup and saved again on clean exit.
#
# > Example:
# >     SGND_STATE_VARIABLES=(
# >         "INP_NAME|Name|Petrus Puk|"
# >         "INP_AGE|Leeftijd|102|sgnd_is_number"
# >     )
#
# -- Source an additional framework library -----------------------------------------
#
# > Declare the library filename in `SGND_USING`. After core libraries are loaded,
# > sgnd_bootstrap sources the declared libraries from the common library directory.
#
# > Example:
# >     SGND_USING=(
# >         sgnd-comment-header-parser.sh
# >     )
#
# -- Use themed colors, styles, and glyphs ------------------------------------------
#
# > Use the framework UI variables instead of hard-coded terminal escape sequences.
# > Color and style variables keep output consistent across scripts, while glyph
# > variables provide reusable symbols for status, navigation, prompts, and visual
# > markers.
#
# > Typical use:
# >     printf "%s%s%s\n" "$SGND_CLR_OK" "Operation completed" "$SGND_CLR_RESET"
# >     printf "%s %s\n" "$SGND_GLYPH_OK" "Validated"
#
# > Prefer the say and ask helpers for normal user interaction. Use color, style, and
# > glyph variables directly only when a script needs custom formatted output.
#
# -- Ask the user for input ----------------------------------------------------------
#
# > Use ask for a single typed value, ask_choose or ask_choose_immediate for choices,
# > ask_decision for symbolic decisions, and ask_prompt_form for multiple named fields.
#
# > Example:
# >     ask_prompt_form --autoalign "${SGND_STATE_VARIABLES[@]}"
#
# -- Show an auto-continue prompt ----------------------------------------------------
#
# > Use ask_dlg_autocontinue for an interruptible countdown. It supports redo, cancel,
# > pause/resume, any-key continuation, and returns distinct status codes.
#
# > Example:
# >     ask_dlg_autocontinue --seconds 10 --message "Continuing deployment" --redo --cancel --pause
#
# -- Write screen output -------------------------------------------------------------
#
# > Use the say helpers from ui-say.sh for consistent terminal output.
#
# > Example:
# >     sayinfo "Preparing release"
# >     sayok "Release package created"
# >     saywarning "Existing manifest found"
# >     sayfail "Checksum validation failed"
# >     saydebug "Resolved target root: $DEST_ROOT"
#
# -- Work with pipe-separated datatables --------------------------------------------
#
# > Use sgnd-datatable.sh when data is represented as schema and pipe-separated rows.
# > It provides helpers for splitting schemas/rows, validating values, inserting,
# > deleting, getting, setting, finding, sorting, printing, and exporting PSV data.
#
# > Example functions:
# >     sgnd_dt_make_row
# >     sgnd_dt_insert
# >     sgnd_dt_get
# >     sgnd_dt_set
# >     sgnd_dt_find_first
# >     sgnd_dt_print_table
# >     sgnd_dt_export_psv
#
# -- Create a VS Code workspace ------------------------------------------------------
#
# > Use sgnd-create-workspace. The underlying create-workspace tool creates the
# > repository-shaped target-root structure, project definitions, workspace file,
# > .gitignore, optional project MOTD, and local component templates. It can instantiate
# > starter executable/library/module files, optionally initialize and publish Git/GitHub,
# > and can undo created artifacts from its creation manifest.
#
# -- Deploy a workspace --------------------------------------------------------------
#
# > Use sgnd-deploy-workspace. The underlying deploy-workspace tool can deploy files
# > from a workspace into a target root, record deployment manifests, undeploy from a
# > manifest, and repeat with last settings through auto mode.
#
# -- Generate documentation ----------------------------------------------------------
#
# > Use the documentation generator. The processor extracts module headers, fn:, var:,
# > doc:, and template blocks; the renderer builds the HTML documentation set.
#
# -- Add a console command -----------------------------------------------------------
#
# > Add a console module under the console modules location. The console menu library
# > handles menu rendering, paging, toggle labels, dispatch, and registered actions.
#
# -- Add generated help examples -----------------------------------------------------
#
# > Add lines to SGND_SCRIPT_EXAMPLES. sgnd_show_help includes these examples when
# > rendering script help.
#
# > Example:
# >     SGND_SCRIPT_EXAMPLES=(
# >         "Deploy using defaults:"
# >         "  $SGND_SCRIPT_NAME"
# >         ""
# >         "Undeploy everything:"
# >         "  $SGND_SCRIPT_NAME --undeploy"
# >     )
# - Subsystem Reference Guide --------------------------------------------------------
#
# > This section provides a compact developer reference for the main SolidGroundUX
# > subsystems. It is intended as a quick map of what exists, which files are involved,
# > which globals matter, and how a script normally opts into the feature.
#
# -- 1. Executable Startup Contract --------------------------------------------------
#
# > Purpose
# >     Provide a standard startup pattern for executable SolidGroundUX scripts.
#
# > Main files
# >     exe-template.sh
# >     sgnd-exe-common.sh
#
# > Main functions
# >     _framework_locator
# >     sgnd_exe_start
#
# > Important globals
# >     SGND_FRAMEWORK_ROOT
# >     SGND_SCRIPT_FILE
# >     SGND_SCRIPT_DIR
# >     SGND_SCRIPT_BASE
# >     SGND_SCRIPT_NAME
#
# > Typical usage
# >     main() {
# >         _framework_locator || exit $?
# >         sgnd_exe_start "$@"
# >
# >         # script logic
# >     }
#
# -- 2. Bootstrap and Runtime Initialization -----------------------------------------
#
# > Purpose
# >     Initialize the framework runtime, apply defaults, resolve directories,
# >     load core libraries, and prepare the script for framework services.
#
# > Main files
# >     sgnd-bootstrap.sh
# >     sgnd-bootstrap-env.sh
#
# > Main functions
# >     sgnd_bootstrap
# >     sgnd_apply_defaults
# >     sgnd_rebase_directories
# >     sgnd_ensure_dirs
#
# > Important globals
# >     SGND_CORE_LIBS
# >     SGND_FRAMEWORK_DIRS
# >     SGND_FRAMEWORK_GLOBALS
# >     SGND_RUNTIME_GLOBALS
#
# > Bootstrap options
# >     --state
# >     --autostate
# >     --needroot
# >     --cannotroot
# >     --log
# >     --quiet
# >     --silent
# >     --loglevel
#
# -- 3. Framework Directory and Global Model -----------------------------------------
#
# > Purpose
# >     Standardize framework-managed paths, user paths,
# >     configuration locations, state locations, documentation locations,
# >     style locations, and log locations.
#
# > Main file
# >     sgnd-bootstrap-env.sh
#
# > Important globals
# >     SGND_FRAMEWORK_ROOT
# >     SGND_COMMON_LIB
# >     SGND_SYSCFG_DIR
# >     SGND_USRCFG_DIR
# >     SGND_STATE_DIR
# >     SGND_STYLE_DIR
# >     SGND_DOCS_DIR
# >     SGND_LOG_PATH
# >     SGND_ALTLOG_PATH
# >     SGND_USER_HOME
#
# -- 4. Command-Line Argument Parsing ------------------------------------------------
#
# > Purpose
# >     Provide consistent built-in and script-specific command-line argument handling.
#
# > Main file
# >     sgnd-args.sh
#
# > Main functions
# >     sgnd_parse_args
# >     sgnd_builtinarg_handler
# >     sgnd_show_help
#
# > Important globals
# >     SGND_ARGS_SPEC
# >     SGND_BUILTIN_ARGS
# >     SGND_SCRIPT_EXAMPLES
# >     SGND_POSITIONAL
#
# -- 5. Configuration Support --------------------------------------------------------
#
# > Purpose
# >     Load framework and script configuration from system and user
# >     configuration files.
#
# > Main files
# >     sgnd-cfg.sh
# >     sgnd-bootstrap-env.sh
#
# > Main functions
# >     sgnd_cfg_domain_apply
# >     sgnd_print_cfg
#
# > Important globals
# >     SGND_FRAMEWORK_GLOBALS
# >     SGND_SCRIPT_GLOBALS
# >     SGND_FRAMEWORK_SYSCFG_FILE
# >     SGND_FRAMEWORK_USRCFG_FILE
# >     SGND_SYSCFG_FILE
# >     SGND_USRCFG_FILE
#
# -- 6. State Support ----------------------------------------------------------------
#
# > Purpose
# >     Persist selected script variables between runs.
#
# > Main files
# >     sgnd-cfg.sh
# >     sgnd-bootstrap.sh
#
# > Main functions
# >     sgnd_state_load
# >     sgnd_state_save_keys
# >     sgnd_state_reset
# >     sgnd_save_state
#
# > Important globals
# >     SGND_STATE_VARIABLES
# >     SGND_STATE_SAVE
# >     SGND_STATE_FILE
#
# > Bootstrap options
# >     --state
# >     --autostate
# >     --statereset
#
# -- 7. Dependency Loading -----------------------------------------------------------
#
# > Purpose
# >     Load framework libraries in a predictable order and allow scripts
# >     to declare optional framework dependencies.
#
# > Main files
# >     sgnd-bootstrap.sh
# >     sgnd-bootstrap-env.sh
#
# > Important globals
# >     SGND_CORE_LIBS
# >     SGND_USING
# >     SGND_COMMON_LIB
#
# -- 8. Console Messaging and Log Levels ---------------------------------------------
#
# > Purpose
# >     Provide consistent terminal output for status, information,
# >     success, warning, failure, cancellation, debug, and trace messages.
#
# > Main files
# >     ui-say.sh
# >     sgnd-exe-common.sh
#
# > Main functions
# >     say
# >     sayinfo
# >     saystart
# >     sayok
# >     saywarning
# >     sayfail
# >     saycancel
# >     sayend
# >     saydebug
#
# > Important globals
# >     SGND_CONSOLE_LOG_LEVEL
#
# > Log levels
# >     silent
# >         Show nothing.
# >
# >     quiet
# >         Show warnings and failures.
# >
# >     normal
# >         Show operational messages.
# >
# >     verbose
# >         Show informational messages.
# >
# >     debug
# >         Show debug messages.
# >
# >     trace
# >         Show all messages.
#
# -- 9. File Logging -----------------------------------------------------------------
#
# > Purpose
# >     Write persistent log records independently from console visibility.
#
# > Main file
# >     ui-say.sh
#
# > Important globals
# >     SGND_FILE_LOG_LEVEL
# >     SGND_LOG_PATH
# >     SGND_ALTLOG_PATH
# >     SGND_LOG_MAX_BYTES
# >     SGND_LOG_KEEP
# >     SGND_LOG_COMPRESS
#
# -- 10. UI Rendering, Theming, and Palettes -----------------------------------------
#
# > Purpose
# >     Provide consistent visual formatting, colors, glyphs, labels,
# >     sections, title bars, and visible-length-safe output.
#
# > Main files
# >     ui.sh
# >     ui-say.sh
# >     ui-glyphs.sh
# >     styles/*.sh
#
# > Important globals
# >     SGND_UI_STYLE
# >     SGND_UI_PALETTE
# >     MSG_CLR_*
# >     LBL_*
# >     ICO_*
# >     SYM_*
# >     RESET
#
# -- 11. User Input and Dialogs ------------------------------------------------------
#
# > Purpose
# >     Provide reusable input helpers for prompts, choices, decisions,
# >     forms, and interruptible dialogs.
#
# > Main files
# >     ui-ask.sh
# >     ui-dlg.sh
#
# > Main functions
# >     ask
# >     ask_choose
# >     ask_choose_immediate
# >     ask_decision
# >     ask_prompt_form
# >     ask_dlg_autocontinue
#
# -- 12. Progress Helpers ------------------------------------------------------------
#
# > Purpose
# >     Provide transient progress output without flooding the terminal.
#
# > Main file
# >     ui-say.sh
#
# > Main functions
# >     sayprogress_begin
# >     sayprogress
# >     sayprogress_done
#
# -- 13. Metadata and Header Parsing -------------------------------------------------
#
# > Purpose
# >     Extract framework, script, module, function, variable, and
# >     documentation metadata from structured source comments.
#
# > Main files
# >     sgnd-comment-header-parser.sh
# >     sgnd-bootstrap.sh
#
# > Main functions
# >     sgnd_script_init_metadata
# >     sgnd_module_init_metadata
# >     sgnd_header_get_section
# >     sgnd_section_get_field_value
#
# -- 14. Documentation Generation ----------------------------------------------------
#
# > Purpose
# >     Generate navigable documentation from structured source comments.
#
# > Main tools
# >     doc-generator.sh
# >     doc-sample.sh
#
# -- 15. Datatable Helpers -----------------------------------------------------------
#
# > Purpose
# >     Work with small pipe-separated table structures in Bash.
#
# > Main file
# >     sgnd-datatable.sh
#
# -- 16. Menu API and Management Console Boundary -----------------------------------
#
# > `sgnd-menu.sh` is a reusable Framework library. It owns menu registration, rendering,
# > paging, visibility, input interpretation, and item dispatch. It does not own the
# > SolidGround Management Console application.
#
# > The console host, public `sgnd-console` command, page discovery/lazy loading, and
# > management modules belong to the separate MCM product. MCM consumes `sgnd-menu` and
# > other Framework APIs in the same way another application can consume them.
#
# -- 17. Related Products: SDK and MCM -----------------------------------------------
#
# > The Framework documentation ends at the reusable runtime boundary. Development and
# > release tooling belongs to the separate SolidGroundUX SDK product; the management
# > console host and server-management modules belong to SolidGroundUX Management Console
# > Modules. Both consume Framework APIs without becoming Framework subsystems.
#
# > Use the SDK documentation for `create-workspace`, `deploy-workspace`, documentation
# > generation, release preparation, release management, and development templates. Use
# > the MCM documentation for `sgnd-console`, lazy-loaded console modules, and module
# > validation.
