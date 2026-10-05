#!/usr/bin/env bash
# =====================================================================================
# SolidGroundUX - Repair Permissions
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627808
#   Checksum    : e6792a134d418f4de40c631b6f11e8422bb8d012bad3ace5453b4a92d026f202
#   Source      : sgnd-repair-permissions.sh
#   Type        : script
#   Group       : Framework Tools
#   Purpose     : Apply declared ownership and permission rules to files and directories.
#
# Description:
#   Reads a pipe-separated permission policy file and applies the declared owner,
#   group, and mode to each target. Relative target paths are resolved below the
#   active SolidGroundUX framework root so the same policy can be used in staged
#   development trees and on installed systems.
#
#   By default a policy row affects only its exact target. An optional filemask extends
#   the rule below a directory: * selects all immediate children, ** selects all
#   descendants recursively, and any other shell-style glob (for example sgnd-*)
#   selects matching immediate children. The declared type still filters directories
#   (d) from regular files (f).
#
#   Exact directory records create the directory when it is missing. File records and
#   masked roots are never invented; missing objects are reported instead.
#
# Design principles:
#   - Permission policy is declarative and external to the executable.
#   - Permission changes are non-recursive unless a policy row explicitly uses **.
#   - Named filemasks such as sgnd-* are limited to immediate children.
#   - Recursive selection never follows symbolic links outside the declared tree.
#   - The symbolic owner/group value "operator" resolves to the invoking sudo user.
#   - Missing or invalid policy data fails visibly instead of being guessed.
#   - Dry-run reports intended changes without modifying the filesystem.
#
# Role in framework:
#   - Repairs runtime-writable ownership after root-owned installation or update work.
#   - Provides one reusable implementation for sgnd-setup and Management Console actions.
#
# Non-goals:
#   - Implicit or unrestricted recursive permission changes.
#   - Following symbolic links while expanding masked selections.
#   - Creating missing regular files or masked search roots.
#   - Inferring ownership or modes that are not declared in the policy file.
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail

# - Bootstrap ------------------------------------------------------------------------
    # fn$ _framework_locator - Resolve and load the active SolidGroundUX framework
        # . Purpose
        #   Determine the filesystem root of the currently executing SolidGroundUX tree
        #   from the script's physical path, then load the executable runtime library.
        #
        # . Behavior
        #   - Resolves the physical path of the executing script.
        #   - Treats usr, etc, and var as the canonical top-level SolidGroundUX tree roots.
        #   - Uses the last occurrence of one of those path components to determine the
        #     active filesystem root.
        #   - Resolves production scripts beneath /usr, /etc, or /var to root (/).
        #   - Resolves staged/development trees to the path prefix preceding the detected
        #     usr, etc, or var component.
        #   - Loads sgnd-exe-common.sh from the resolved framework root when available.
        #   - For staged/development trees where the executable common library is not
        #     present, falls back to the installed framework copy without changing
        #     SGND_FRAMEWORK_ROOT.
        #
        # . Globals (write)
        #   SGND_FRAMEWORK_ROOT
        #
        # . Output
        #   Writes fatal bootstrap errors to stderr using printf because framework UI
        #   helpers are not available until sgnd-exe-common.sh has been loaded.
        #
        # . Returns
        #   0 when the framework root was resolved and executable common library loaded.
        #   126 when the script path cannot be resolved, no canonical root component can
        #   be found, or the executable common library is unreadable.
        #
        # . Usage
        #   _framework_locator || return $?
    _framework_locator() {
        local script_file=""
        local path_without_root=""
        local component=""
        local framework_root=""
        local exe_common=""
        local index=0
        local root_index=-1
        local -a path_parts=()

        script_file="$(readlink -f "${BASH_SOURCE[0]}")" || {
            printf 'FATAL: Cannot resolve executable path: %s\n' "${BASH_SOURCE[0]}" >&2
            return 126
        }

        path_without_root="${script_file#/}"
        IFS='/' read -r -a path_parts <<< "$path_without_root"

        for index in "${!path_parts[@]}"; do
            component="${path_parts[$index]}"
            case "$component" in
                usr|etc|var)
                    root_index=$index
                    ;;
            esac
        done

        if (( root_index < 0 )); then
            printf 'FATAL: Cannot determine SolidGroundUX framework root from: %s\n' "$script_file" >&2
            return 126
        fi

        if (( root_index == 0 )); then
            framework_root="/"
        else
            framework_root=""
            for (( index=0; index<root_index; index++ )); do
                framework_root+="/${path_parts[$index]}"
            done
        fi

        SGND_FRAMEWORK_ROOT="$framework_root"

        if [[ "$SGND_FRAMEWORK_ROOT" == "/" ]]; then
            exe_common="/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
        else
            exe_common="${SGND_FRAMEWORK_ROOT%/}/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"

            if [[ ! -r "$exe_common" ]]; then
                exe_common="/usr/local/lib/solidgroundux/common/sgnd-exe-common.sh"
            fi
        fi

        [[ -r "$exe_common" ]] || {
            printf 'FATAL: Cannot read executable common library: %s\n' "$exe_common" >&2
            return 126
        }

        # shellcheck source=/dev/null
        source "$exe_common"
    }

# - Script identity ------------------------------------------------------------------
    SGND_SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
    SGND_SCRIPT_DIR="$(cd -- "$(dirname -- "$SGND_SCRIPT_FILE")" && pwd)"
    SGND_SCRIPT_BASE="$(basename -- "$SGND_SCRIPT_FILE")"
    SGND_SCRIPT_NAME="${SGND_SCRIPT_BASE%.sh}"

# - Framework integration ------------------------------------------------------------
    SGND_USING=(
    )

    SGND_ARGS_SPEC=(
        "file|f|value|VAL_PERMISSION_FILE|Permission policy file; defaults to SGND_SHARE_DIR/permissions.dta||"
    )

    SGND_SCRIPT_EXAMPLES=(
        "Apply the default permission policy from SGND_SHARE_DIR:"
        "  $SGND_SCRIPT_NAME"
        ""
        "Apply an explicit permission policy:"
        "  $SGND_SCRIPT_NAME --file /path/to/permissions.dta"
        ""
        "Preview the changes:"
        "  $SGND_SCRIPT_NAME --dryrun"
    )

    SGND_SCRIPT_GLOBALS=(
    )

    SGND_STATE_VARIABLES=(
    )

    SGND_ON_EXIT_HANDLERS=(
    )

    SGND_STATE_SAVE=0

# - Local helpers --------------------------------------------------------------------
    # fn: _trim - Trim leading and trailing whitespace
        # . Arguments
        #   $1  Text to trim.
        #
        # . Output
        #   Trimmed text on stdout.
        #
        # . Returns
        #   0 always.
        #
        # . Usage
        #   value="$(_trim "$value")"
    _trim() {
        local value="${1:-}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        printf '%s' "$value"
    }

    # fn: _init_defaults - Resolve the default permission policy path
        # . Purpose
        #   Resolve the default permission policy below the framework shared-data root.
        #
        # . Behavior
        #   - Requires SGND_SHARE_DIR to have been initialized by framework bootstrap.
        #   - Defaults the policy to SGND_SHARE_DIR/permissions.dta.
        #   - Preserves an explicitly supplied --file value.
        #
        # Inputs (globals)
        #   SGND_SHARE_DIR
        #
        # Outputs (globals)
        #   VAL_PERMISSION_FILE
        #
        # . Returns
        #   0 when SGND_SHARE_DIR is available.
        #   1 when the framework shared-data directory was not initialized.
        #
        # . Usage
        #   _init_defaults
    _init_defaults() {
        [[ -n "${SGND_SHARE_DIR:-}" ]] || {
            sayfail "SGND_SHARE_DIR is not initialized by the framework."
            return 1
        }

        : "${VAL_PERMISSION_FILE:=$SGND_SHARE_DIR/permissions.dta}"
        return 0
    }

    # fn: _resolve_operator - Resolve the non-root operator account
        # . Purpose
        #   Resolve the symbolic permission-policy identity "operator".
        #
        # . Behavior
        #   - Uses SUDO_USER when the script was elevated from a non-root account.
        #   - Refuses to silently translate operator to root when no invoking operator
        #     can be identified.
        #
        # Outputs (globals)
        #   SGND_PERMISSION_OPERATOR_USER
        #   SGND_PERMISSION_OPERATOR_GROUP
        #
        # . Returns
        #   0 when an operator user and primary group were resolved.
        #   1 when no non-root operator can be identified.
        #
        # . Usage
        #   _resolve_operator
    _resolve_operator() {
        local operator_user=""
        local operator_group=""

        if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
            operator_user="$SUDO_USER"
        fi

        [[ -n "$operator_user" ]] || {
            sayfail "Cannot resolve 'operator': run the script through sudo from the intended operator account or use explicit owner/group values."
            return 1
        }

        operator_group="$(id -gn "$operator_user" 2>/dev/null || true)"
        [[ -n "$operator_group" ]] || {
            sayfail "Cannot resolve primary group for operator '$operator_user'."
            return 1
        }

        SGND_PERMISSION_OPERATOR_USER="$operator_user"
        SGND_PERMISSION_OPERATOR_GROUP="$operator_group"
        return 0
    }

    # fn: _resolve_identity - Resolve a policy owner or group value
        # . Purpose
        #   Translate the symbolic value "operator" or preserve an explicit identity.
        #
        # . Arguments
        #   $1  Raw owner/group value.
        #   $2  Identity kind: owner or group.
        #
        # . Output
        #   Resolved identity on stdout.
        #
        # . Returns
        #   0 on success.
        #   1 when operator resolution fails.
        #
        # . Usage
        #   owner="$(_resolve_identity "$owner" owner)"
    _resolve_identity() {
        local value="${1:-}"
        local kind="${2:-owner}"

        if [[ "$value" != "operator" ]]; then
            printf '%s' "$value"
            return 0
        fi

        if [[ -z "${SGND_PERMISSION_OPERATOR_USER:-}" || -z "${SGND_PERMISSION_OPERATOR_GROUP:-}" ]]; then
            _resolve_operator || return 1
        fi

        if [[ "$kind" == "group" ]]; then
            printf '%s' "$SGND_PERMISSION_OPERATOR_GROUP"
        else
            printf '%s' "$SGND_PERMISSION_OPERATOR_USER"
        fi
    }

    # fn: _resolve_target_path - Resolve a policy target against the framework root
        # . Purpose
        #   Make one policy file usable for both staged target-root trees and live systems.
        #
        # . Arguments
        #   $1  Absolute target path or path relative to SGND_FRAMEWORK_ROOT.
        #
        # . Output
        #   Resolved absolute target path on stdout.
        #
        # . Returns
        #   0 when the path is valid.
        #   1 for an empty target or the filesystem root itself.
        #
        # . Usage
        #   target="$(_resolve_target_path "usr/local/share/solidgroundux/.cache")"
    _resolve_target_path() {
        local raw="${1:-}"
        local target=""
        local framework_prefix="${SGND_FRAMEWORK_ROOT%/}"

        [[ -n "$raw" ]] || return 1

        if [[ "$raw" == /* ]]; then
            target="$raw"
        else
            target="${framework_prefix}/${raw#./}"
        fi

        [[ "$target" != "/" && -n "$target" ]] || return 1
        printf '%s' "$target"
    }

    # fn: _validate_mode - Validate an octal permission mode
        # . Arguments
        #   $1  Permission mode.
        #
        # . Returns
        #   0 for three- or four-digit octal modes; 1 otherwise.
        #
        # . Usage
        #   _validate_mode "0755"
    _validate_mode() {
        [[ "${1:-}" =~ ^[0-7]{3,4}$ ]]
    }

    # fn: _apply_target_permissions - Apply ownership and mode to one resolved target
        # . Purpose
        #   Apply one already-resolved permission rule to a single filesystem object.
        #
        # . Arguments
        #   $1  Type: d for directory or f for regular file.
        #   $2  Resolved absolute target path.
        #   $3  Resolved owner name or numeric uid.
        #   $4  Resolved group name or numeric gid.
        #   $5  Octal permission mode.
        #   $6  Source policy line number.
        #   $7  Create missing directory: 1 or 0.
        #
        # . Side effects
        #   May create an exact directory target and may change ownership and permissions.
        #
        # . Returns
        #   0 when the target was applied or was already correct.
        #   1 when validation or filesystem modification fails.
        #   2 when a declared object is absent and creation is not permitted.
        #
        # . Usage
        #   _apply_target_permissions "d" "$target" "$owner" "$group" "0755" 3 1
    _apply_target_permissions() {
        local kind="${1:-}"
        local target="${2:-}"
        local owner="${3:-}"
        local group="${4:-}"
        local mode="${5:-}"
        local line_number="${6:-0}"
        local create_missing_dir="${7:-0}"
        local current_owner=""
        local current_group=""
        local current_mode=""
        local chmod_mode=""
        local needs_owner=0
        local needs_mode=0

        if [[ "$kind" == "d" ]]; then
            if [[ -e "$target" && ! -d "$target" ]]; then
                sayfail "Policy line $line_number expects a directory but target is not a directory: $target"
                return 1
            fi

            if [[ ! -d "$target" ]]; then
                if (( create_missing_dir != 1 )); then
                    saywarning "Declared directory does not exist; skipping: $target"
                    return 2
                fi

                if (( ${FLAG_DRYRUN:-0} == 1 )); then
                    sayinfo "DRYRUN: Would create directory '$target'."
                else
                    mkdir -p -- "$target" || {
                        sayfail "Cannot create directory: $target"
                        return 1
                    }
                    sayok "Created directory '$target'."
                fi
            fi
        else
            if [[ ! -e "$target" ]]; then
                saywarning "Declared file does not exist; skipping: $target"
                return 2
            fi
            if [[ ! -f "$target" ]]; then
                sayfail "Policy line $line_number expects a regular file: $target"
                return 1
            fi
        fi

        if [[ -e "$target" ]]; then
            current_owner="$(stat -c '%U' -- "$target" 2>/dev/null || true)"
            current_group="$(stat -c '%G' -- "$target" 2>/dev/null || true)"
            current_mode="$(stat -c '%a' -- "$target" 2>/dev/null || true)"
            [[ "$current_owner" == "$owner" && "$current_group" == "$group" ]] || needs_owner=1
            [[ "$current_mode" == "${mode#0}" ]] || needs_mode=1
        else
            needs_owner=1
            needs_mode=1
        fi

        if (( needs_owner )); then
            if (( ${FLAG_DRYRUN:-0} == 1 )); then
                sayinfo "DRYRUN: Would set owner of '$target' to '$owner:$group'."
            else
                chown -- "$owner:$group" "$target" || {
                    sayfail "Cannot set owner '$owner:$group' on: $target"
                    return 1
                }
                sayok "Set owner '$owner:$group' on '$target'."
            fi
        fi

        if (( needs_mode )); then
            # Prefix an extra zero so chmod explicitly clears inherited special bits
            # when the policy does not request them (notably setgid on directories).
            if (( ${#mode} == 3 )); then
                chmod_mode="00$mode"
            else
                chmod_mode="0$mode"
            fi

            if (( ${FLAG_DRYRUN:-0} == 1 )); then
                sayinfo "DRYRUN: Would set mode of '$target' to '$mode'."
            else
                chmod -- "$chmod_mode" "$target" || {
                    sayfail "Cannot set mode '$mode' on: $target"
                    return 1
                }
                sayok "Set mode '$mode' on '$target'."
            fi
        fi

        if (( !needs_owner && !needs_mode )); then
            sayinfo "Already correct: $target"
        fi

        return 0
    }

    # fn: _apply_policy_row - Apply one permission policy row
        # . Purpose
        #   Apply an exact target rule or an explicitly masked child selection.
        #
        # . Arguments
        #   $1  Type: d for directory or f for regular file.
        #   $2  Target path, absolute or framework-root relative.
        #   $3  Owner name, numeric uid, or operator.
        #   $4  Group name, numeric gid, or operator.
        #   $5  Octal permission mode.
        #   $6  Optional filemask: empty for exact target, * for all immediate children,
        #       ** for all descendants recursively, or a shell-style glob such as
        #       sgnd-* for matching immediate children.
        #   $7  Source policy line number.
        #
        # . Behavior
        #   - Empty filemask applies only to the exact target.
        #   - * applies to all immediate children of the declared directory root.
        #   - ** applies to all descendants recursively below the declared root.
        #   - Other shell-style glob patterns, such as sgnd-*, match immediate children.
        #   - Type d selects directories; type f selects regular files.
        #   - Mask expansion uses find -P and therefore does not follow symbolic links.
        #
        # . Side effects
        #   May create an exact directory target and may change ownership and permissions.
        #
        # . Returns
        #   0 when the row is valid and applied or has no matching masked objects.
        #   1 when validation or filesystem modification fails.
        #   2 when an exact declared file is absent; this is reported as a warning.
        #
        # . Usage
        #   _apply_policy_row "d" "usr/local/share/solidgroundux/.cache" "operator" "operator" "0755" "**" 3
    _apply_policy_row() {
        local kind="${1:-}"
        local raw_path="${2:-}"
        local owner="${3:-}"
        local group="${4:-}"
        local mode="${5:-}"
        local filemask="${6:-}"
        local line_number="${7:-0}"
        local target=""
        local matched_target=""
        local matched_count=0
        local failures=0
        local rc=0
        local -a find_depth=()
        local -a find_name=()

        case "$kind" in
            d|f) ;;
            *)
                sayfail "Policy line $line_number has invalid type '$kind'; expected d or f."
                return 1
                ;;
        esac

        [[ -n "$raw_path" && -n "$owner" && -n "$group" && -n "$mode" ]] || {
            sayfail "Policy line $line_number is incomplete; expected type|path|owner|group|mode[|filemask]."
            return 1
        }

        if [[ "$filemask" == */* ]]; then
            sayfail "Policy line $line_number has invalid filemask '$filemask'; filemasks may not contain '/'."
            return 1
        fi

        _validate_mode "$mode" || {
            sayfail "Policy line $line_number has invalid mode '$mode'."
            return 1
        }

        target="$(_resolve_target_path "$raw_path")" || {
            sayfail "Policy line $line_number has unsafe or empty target path '$raw_path'."
            return 1
        }

        owner="$(_resolve_identity "$owner" owner)" || return 1
        group="$(_resolve_identity "$group" group)" || return 1

        if [[ -z "$filemask" ]]; then
            _apply_target_permissions "$kind" "$target" "$owner" "$group" "$mode" "$line_number" 1
            return $?
        fi

        [[ -d "$target" ]] || {
            sayfail "Policy line $line_number uses filemask '$filemask' but search root is not a directory: $target"
            return 1
        }

        case "$filemask" in
            "**")
                ;;
            "*")
                find_depth=(-maxdepth 1)
                ;;
            *)
                find_depth=(-maxdepth 1)
                find_name=(-name "$filemask")
                ;;
        esac

        while IFS= read -r -d '' matched_target; do
            ((matched_count++))
            rc=0
            _apply_target_permissions "$kind" "$matched_target" "$owner" "$group" "$mode" "$line_number" 0 || rc=$?
            (( rc == 0 )) || ((failures++))
        done < <(find -P "$target" -mindepth 1 "${find_depth[@]}" -type "$kind" "${find_name[@]}" -print0)

        if (( matched_count == 0 )); then
            if [[ "$kind" == "d" ]]; then
                sayinfo "Policy line $line_number matched no directories below '$target' with filemask '$filemask'."
            else
                sayinfo "Policy line $line_number matched no regular files below '$target' with filemask '$filemask'."
            fi
        fi

        (( failures == 0 )) || return 1
        return 0
    }

    # fn: _apply_policy_file - Read and apply a permission policy file
        # . Purpose
        #   Apply every active permission rule from one PSV policy file.
        #
        # . Behavior
        #   - Accepts type|path|owner|group|mode with an optional sixth filemask field.
        #   - Empty filemask keeps exact-target behavior; * selects all immediate children;
        #     ** selects descendants recursively; other glob patterns match immediate children.
        #   - Ignores blank lines and lines beginning with #.
        #   - Trims whitespace around every field.
        #   - Continues after row failures so all problems are reported in one run.
        #   - Treats missing exact declared files as warnings rather than hard failures.
        #
        # . Arguments
        #   $1  Policy file path.
        #
        # . Returns
        #   0 when every applicable row was valid and applied.
        #   1 when one or more rows failed.
        #
        # . Usage
        #   _apply_policy_file "$VAL_PERMISSION_FILE"
    _apply_policy_file() {
        local policy_file="${1:-}"
        local line=""
        local kind=""
        local path=""
        local owner=""
        local group=""
        local mode=""
        local filemask=""
        local extra=""
        local line_number=0
        local applied=0
        local warnings=0
        local failures=0
        local rc=0

        [[ -r "$policy_file" ]] || {
            sayfail "Permission policy file is not readable: $policy_file"
            return 1
        }

        saystart "Applying permission policy: $policy_file"

        while IFS= read -r line || [[ -n "$line" ]]; do
            ((line_number++))
            line="${line%$'\r'}"
            line="$(_trim "$line")"
            [[ -n "$line" && "${line:0:1}" != "#" ]] || continue

            IFS='|' read -r kind path owner group mode filemask extra <<< "$line"
            kind="$(_trim "$kind")"
            path="$(_trim "$path")"
            owner="$(_trim "$owner")"
            group="$(_trim "$group")"
            mode="$(_trim "$mode")"
            filemask="$(_trim "$filemask")"
            extra="$(_trim "$extra")"

            if [[ -n "$extra" ]]; then
                sayfail "Policy line $line_number has too many fields; expected type|path|owner|group|mode[|filemask]."
                ((failures++))
                continue
            fi

            rc=0
            _apply_policy_row "$kind" "$path" "$owner" "$group" "$mode" "$filemask" "$line_number" || rc=$?
            case "$rc" in
                0) ((applied++)) ;;
                2) ((warnings++)) ;;
                *) ((failures++)) ;;
            esac
        done < "$policy_file"

        sayinfo "Permission policy summary: applied=$applied warnings=$warnings failures=$failures"

        if (( failures > 0 )); then
            sayfail "Permission policy completed with $failures failure(s)."
            return 1
        fi

        sayend "Permission policy completed successfully."
        return 0
    }

# - Main -----------------------------------------------------------------------------
    # fn: main - Repair declared filesystem ownership and permissions
        # . Purpose
        #   Start the framework runtime with root privileges and apply the selected policy.
        #
        # . Arguments
        #   $@  Framework and script-specific command-line arguments.
        #
        # . Returns
        #   0 when all applicable policy rows were processed successfully.
        #   Non-zero when startup, validation, or filesystem changes fail.
        #
        # . Usage
        #   main "$@"
    main() {
        _framework_locator || exit $?
        sgnd_exe_start --needroot -- "$@"

        _init_defaults || exit $?

        sgnd_print_titlebar --left "Repair Permissions" --sub "Apply SolidGroundUX filesystem policy"
        sgnd_print
        sgnd_print_labeledvalue --label "Policy file" --value "$VAL_PERMISSION_FILE" --labelwidth 16
        sgnd_print_labeledvalue --label "Framework root" --value "$SGND_FRAMEWORK_ROOT" --labelwidth 16
        sgnd_print

        _apply_policy_file "$VAL_PERMISSION_FILE"
    }

    # Entrypoint: sgnd_exe_start splits framework arguments from script arguments.
    main "$@"
