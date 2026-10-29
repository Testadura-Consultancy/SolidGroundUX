# =====================================================================================
# SolidGroundUX - System Utilities
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.1
#   Build       : 2627501
#   Checksum    : 9ebf3217a928b14d2d14077eaec3e34591aef660a991ce4b1781859263535803
#   Source      : sgnd-system.sh
#   Type        : library
#   Group       : Common Core
#   Purpose     : Provide host, runtime, and operating-system utility helpers
#
# Description:
#   Contains environment-aware helpers that sit above sgnd-core.
#
#   The library:
#     - Provides root/sudo/runtime guards
#     - Exposes OS, network, and service-state helpers
#     - Includes ownership and permission normalization helpers
#     - Keeps operational/debug output close to procedural system actions
#
# Design principles:
#   - Keep system behavior out of sgnd-core
#   - Depend on framework bootstrap guarantees for minimal say* functions
#   - Prefer explicit operational helpers over mixing host logic into generic primitives
#   - Keep behavior predictable and side effects documented
#
# Role in framework:
#   - System/runtime layer above sgnd-core
#   - Used by installers, setup routines, and host-aware modules
#   - Centralizes platform and privilege helpers
#
# Non-goals:
#   - Business logic or application-specific behavior
#   - Interactive UI rendering or menu behavior
#   - Generic string/array/text helpers (handled in sgnd-core)
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 - 2026 Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.1.
# =====================================================================================
set -uo pipefail
# - Library guard ------------------------------------------------------------------
    # fn$ _sgnd_lib_guard - Enforce source-only, single-load library initialization
        # . Purpose
        #   Ensure the file is sourced as a library and initialized only once.
        #
        # . Behavior
        #   - Derives a unique guard variable name from the current filename.
        #   - Aborts execution when the file is run directly instead of sourced.
        #   - Sets the guard variable on first load.
        #   - Returns immediately when the library was already loaded.
        #
        # Inputs
        #   BASH_SOURCE[0]
        #   $0
        #
        # Outputs (globals)
        #   SGND_<MODULE>_LOADED
        #
        # . Returns
        #   0 when already loaded or successfully initialized.
        #   Exits with code 2 when executed instead of sourced.
        #
        # . Usage
        #   _sgnd_lib_guard
    _sgnd_lib_guard() {
        local lib_base=""
        local guard=""

        lib_base="$(basename "${BASH_SOURCE[0]}" .sh)"
        lib_base="${lib_base//-/_}"
        guard="SGND_${lib_base^^}_LOADED"

        [[ "${BASH_SOURCE[0]}" != "$0" ]] || {
            printf 'This is a library; source it, do not execute it: %s\n' "${BASH_SOURCE[0]}" >&2
            exit 2
        }

        [[ -n "${!guard-}" ]] && return 0
        printf -v "$guard" '1'
    }

    _sgnd_lib_guard
    unset -f _sgnd_lib_guard

    if declare -F sgnd_module_init_metadata >/dev/null 2>&1 \
        && declare -F sgnd_header_buffer_load >/dev/null 2>&1; then
        sgnd_module_init_metadata "${BASH_SOURCE[0]}"
    fi
# - Public API ---------------------------------------------------------------------
    # -- Privilege and runtime requirements -------------------------------------------
        # fn: sgnd_need_root - Need root
            # . Purpose
            #   Require the current process to run as root.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #   - Reads or updates SolidGroundUX runtime, metadata, configuration, or UI globals as needed.
            #   - Uses framework UI/output conventions for terminal or dialog interaction.
            #
            # . Arguments
            #   $0  ARG0 - Positional value used by this function.
            #
            # Outputs (globals):
            #   May update SGND_* globals shown in the function body.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_need_root "example-0"
        sgnd_need_root() {
            sayinfo "Script requires root permissions"

            if [[ ${EUID:-$(id -u)} -ne 0 && -z "${SGND_ALREADY_ROOT:-}" ]]; then
                saydebug "Restarting as root"
                exec sudo \
                    --preserve-env=SGND_FRAMEWORK_ROOT,PATH \
                    -- env SGND_ALREADY_ROOT=1 "$0" "$@"
            fi

            saydebug "Already root, no restart required"
            return 0
        }
        # fn: sgnd_cannot_root - Cannot root
            # . Purpose
            #   Reject execution as root.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #   - Uses framework UI/output conventions for terminal or dialog interaction.
            #
            # . Returns
            #   0 on success.
            #   Non-zero when validation, resolution, user cancellation, or execution fails.
            #
            # . Usage
            #   sgnd_cannot_root
        sgnd_cannot_root() {
            sayinfo "Script requires NOT having root permissions"

            if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
                sayfail "Do not run this script as root. Exiting..."
                exit 1
            fi
        }
        # fn: sgnd_need_systemd - Need systemd
            # . Purpose
            #   Require systemd/systemctl availability.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #   - Uses framework UI/output conventions for terminal or dialog interaction.
            #
            # . Returns
            #   0 on success.
            #   Non-zero when validation, resolution, user cancellation, or execution fails.
            #
            # . Usage
            #   sgnd_need_systemd
        sgnd_need_systemd() { sgnd_have systemctl || { sayfail "Systemd not available."; exit 1; }; }
        # fn: sgnd_need_writable - Need writable
            # . Purpose
            #   Require a writable filesystem path.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #   - Uses framework UI/output conventions for terminal or dialog interaction.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
            #
            # . Returns
            #   0 on success.
            #   Non-zero when validation, resolution, user cancellation, or execution fails.
            #
            # . Usage
            #   sgnd_need_writable "/tmp"
        sgnd_need_writable() { [[ -w "$1" ]] || { sayfail "Not writable: $1"; exit 1; }; }
        # fn: sgnd_is_active - Is active
            # . Purpose
            #   Check whether a systemd service is active.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_is_active "ssh" && printf 'SSH service is active\n'
        sgnd_is_active() { systemctl is-active --quiet "$1"; }
        # fn: sgnd_ensure_writable_dir - Ensure writable dir
            # . Purpose
            #   Create a directory and verify that it is writable.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  DIR - Directory path.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_ensure_writable_dir "/tmp/sgnd-example" "/tmp"
        sgnd_ensure_writable_dir() {
            local dir="${1:-}"
            local created=0
            local grp

            [[ -n "$dir" ]] || return 2

            if [[ ! -d "$dir" ]]; then
                mkdir -p -- "$dir" || return 3
                created=1
            fi

            if [[ -n "${SUDO_USER:-}" ]]; then
                grp="$(id -gn "$SUDO_USER" 2>/dev/null || printf '%s' "$SUDO_USER")"
                if (( created )); then
                    chown "$SUDO_USER:$grp" "$dir" 2>/dev/null || true
                fi
            fi

            [[ -d "$dir" ]] || return 4
            return 0
        }
    # -- Network ----------------------------------------------------------------------
        # fn: sgnd_get_primary_nic - Get primary nic
            # . Purpose
            #   Print the network interface used for the default route.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $5  ARG5 - Positional value used by this function.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_get_primary_nic
        sgnd_get_primary_nic() { ip route show default 2>/dev/null | awk 'NR==1 {print $5}'; }
        # fn: sgnd_ping_ok - Ping ok
            # . Purpose
            #   Check whether a host responds to one ping probe.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_ping_ok "127.0.0.1" && printf 'Loopback responds\n'
        sgnd_ping_ok() { ping -c1 -W1 "$1" &>/dev/null; }
        # fn: sgnd_port_open - Port open
            # . Purpose
            #   Check whether a TCP port is reachable.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  H - Positional value used by this function.
            #   $2  P - Positional value used by this function.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_port_open "example" "example-2"
        sgnd_port_open() {
            local h="$1"
            local p="$2"

            if sgnd_have nc; then
                nc -z "$h" "$p" &>/dev/null
            else
                (exec 3<>"/dev/tcp/$h/$p") &>/dev/null
            fi
        }
        # fn: sgnd_get_ip - Get ip
            # . Purpose
            #   Print the first local IP address reported by hostname.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  ARG1 - Positional value used by this function.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_get_ip "lo"
        sgnd_get_ip() { hostname -I 2>/dev/null | awk '{print $1}'; }
    # -- User context and ownership ---------------------------------------------------
        # fn: sgnd_real_user - Real user
            # . Purpose
            #   Print the non-root user behind sudo, or the current user.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Output
            #   Writes computed or formatted text to stdout unless the function explicitly targets stderr or /dev/tty.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_real_user
        sgnd_real_user() {
            if [[ -n "${SUDO_USER-}" && "${SUDO_USER}" != "root" ]]; then
                printf '%s\n' "${SUDO_USER}"
            else
                id -un
            fi
        }
        # fn: sgnd_real_home - Real home
            # . Purpose
            #   Print the home directory for the real user.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_real_home
        sgnd_real_home() {
            local user
            user="$(sgnd_real_user)"
            getent passwd "${user}" | cut -d: -f6
        }
        # fn: sgnd_run_as_real_user - Run as real user
            # . Purpose
            #   Run a command as the real non-root user when invoked through sudo.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_run_as_real_user printf '%s\n' "Running as the real user"
        sgnd_run_as_real_user() {
            local user
            user="$(sgnd_real_user)"

            if (( EUID == 0 )) && [[ "${user}" != "root" ]]; then
                sudo -u "${user}" -H -- "$@"
            else
                "$@"
            fi
        }
        # fn: sgnd_fix_ownership - Fix ownership
            # . Purpose
            #   Apply recursive ownership to a path.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  PATH - Filesystem path.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_fix_ownership "/tmp/sgnd-example"
        sgnd_fix_ownership() {
            local path="$1"
            local user
            local group

            user="$(sgnd_real_user)"
            group="$(id -gn "${user}")"
            chown -R "${user}:${group}" "${path}"
        }
        # fn: sgnd_fix_permissions - Fix permissions
            # . Purpose
            #   Apply recursive permissions to a path.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Arguments
            #   $1  PATH - Filesystem path.
            #
            # . Side effects
            #   May update files, directories, runtime state, or process state required by the workflow.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_fix_permissions "/tmp/sgnd-example"
        sgnd_fix_permissions() {
            local path="$1"

            find "${path}" -type d -exec chmod 755 {} +
            find "${path}" -type f -exec chmod 644 {} +
        }
    # -- Operating system information -------------------------------------------------
        # fn: sgnd_get_os - Get os
            # . Purpose
            #   Print the operating system ID from /etc/os-release.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_get_os
        sgnd_get_os() { grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"'; }
        # fn: sgnd_get_os_version - Get os version
            # . Purpose
            #   Print the operating system version ID from /etc/os-release.
            #
            # . Behavior
            #   - Provides a public SolidGroundUX helper or command entry point.
            #
            # . Returns
            #   0 on success unless the called command returns a different status.
            #
            # . Usage
            #   sgnd_get_os_version
        sgnd_get_os_version() { grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"'; }
    # -- Failure and command execution ------------------------------------------------
    # fn: sgnd_die - Die
        # . Purpose
        #   Print a failure message and terminate the current script.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Arguments
        #   $1  MSG - Positional value used by this function.
        #   $2  RC - Return code.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_die "example" "example-2"
    sgnd_die() {
        local msg="${1-}"
        local rc="${2-1}"

        if (( ${FLAG_VERBOSE:-0} )); then
            sayfail "$rc ${msg:-Fatal error}"
            sgnd_stack_trace
        else
            sayfail "$rc ${msg:-Fatal error} ($(sgnd_caller_id 2))"
        fi

        exit "$rc"
    }
    # fn: sgnd_require - Require
        # . Purpose
        #   Require a command to succeed, terminating on failure.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #   - Uses framework UI/output conventions for terminal or dialog interaction.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_require test -d "/tmp"
    sgnd_require() {
        "$@"
        local rc=$?

        if (( rc != 0 )); then
            sayfail "Command failed (rc=$rc): $* ($(sgnd_caller_id 2))"
        fi

        return "$rc"
    }
    # fn: sgnd_must - Must
        # . Purpose
        #   Run a command and terminate with a contextual failure message if it fails.
        #
        # . Behavior
        #   - Provides a public SolidGroundUX helper or command entry point.
        #
        # . Returns
        #   0 on success unless the called command returns a different status.
        #
        # . Usage
        #   sgnd_must mkdir -p "/tmp/sgnd-example"
    sgnd_must() {
        "$@"
        local rc=$?

        (( rc == 0 )) && return 0
        sgnd_die "Fatal: $* (rc=$rc)" "$rc"
    }
