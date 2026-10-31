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
        #   ```bash
        #   _sgnd_lib_guard
        #   ```
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
            #   Require root privileges, restarting this executable through sudo if necessary.
            #
            # . Description
            #   Preserves the Framework root and PATH, sets SGND_ALREADY_ROOT to prevent repeated escalation.
            #
            # . Arguments
            #   $@ - Original executable arguments to forward when restarting.
            #
            # . Side effects
            #   May replace the running process with a sudo-launched invocation.
            #
            # . Returns
            #   0 when already running as root; otherwise the restarted process determines the exit status.
            #
            # . Usage
            #   ```bash
            #   sgnd_need_root "$@"
            #   ```
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
            #   Refuse to run the current script with root privileges.
            #
            # . Side effects
            #   Exits the process if EUID is 0.
            #
            # . Returns
            #   0 when running as a non-root user; exits with status 1 if root.
            #
            # . Usage
            #   ```bash
            #   sgnd_cannot_root
            #   ```
        sgnd_cannot_root() {
            sayinfo "Script requires NOT having root permissions"

            if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
                sayfail "Do not run this script as root. Exiting..."
                exit 1
            fi
        }
        # fn: sgnd_need_systemd - Need systemd
            # . Purpose
            #   Require the systemctl command to be available.
            #
            # . Side effects
            #   Exits the process if systemctl is unavailable.
            #
            # . Returns
            #   0 when systemctl is available; exits with status 1 otherwise.
            #
            # . Usage
            #   ```bash
            #   sgnd_need_systemd
            #   ```
        sgnd_need_systemd() { sgnd_have systemctl || { sayfail "Systemd not available."; exit 1; }; }
        # fn: sgnd_need_writable - Need writable
            # . Purpose
            #   Require that the specified path is writable to the current process.
            #
            # . Arguments
            #   $1 - Path to test.
            #
            # . Side effects
            #   Exits the process on failure.
            #
            # . Returns
            #   0 if writable; exits with status 1 otherwise.
            #
            # . Usage
            #   ```bash
            #   sgnd_need_writable "/tmp"
            #   ```
        sgnd_need_writable() { [[ -w "$1" ]] || { sayfail "Not writable: $1"; exit 1; }; }
        # fn: sgnd_is_active - Is active
            # . Purpose
            #   Check whether the named systemd service is active.
            #
            # . Arguments
            #   $1 - Service name.
            #
            # . Returns
            #   Passes through the exit status of systemctl is-active --quiet.
            #
            # . Usage
            #   ```bash
            #   sgnd_is_active ssh && sayinfo "SSH is active"
            #   ```
        sgnd_is_active() { systemctl is-active --quiet "$1"; }
        # fn: sgnd_ensure_writable_dir - Ensure writable dir
            # . Purpose
            #   Ensure that a directory exists; adjust ownership when newly created under sudo.
            #
            # . Description
            #   Despite its historical name, this function does not test the directory for write permission.
            #
            # . Arguments
            #   $1 - Directory path.
            #
            # . Side effects
            #   May create the directory and attempt to chown it to SUDO_USER.
            #
            # . Returns
            #   0 if the directory exists after the attempt; 2 for empty path, 3 for mkdir failure, 4 if still absent.
            #
            # . Usage
            #   ```bash
            #   sgnd_ensure_writable_dir "/tmp/sgnd-example"
            #   ```
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
            #   Print the interface name from the first default route.
            #
            # . Output
            #   Writes the fifth field from the first ip route show default line, or an empty line if none.
            #
            # . Returns
            #   Returns the pipeline status; an absent route does not necessarily produce an error.
            #
            # . Usage
            #   ```bash
            #   sgnd_get_primary_nic
            #   ```
        sgnd_get_primary_nic() { ip route show default 2>/dev/null | awk 'NR==1 {print $5}'; }
        # fn: sgnd_ping_ok - Ping ok
            # . Purpose
            #   Test whether a host responds to a single ping.
            #
            # . Arguments
            #   $1 - Hostname or IP address.
            #
            # . Returns
            #   0 when ping succeeds; non-zero otherwise.
            #
            # . Usage
            #   ```bash
            #   sgnd_ping_ok "127.0.0.1"
            #   ```
        sgnd_ping_ok() { ping -c1 -W1 "$1" &>/dev/null; }
        # fn: sgnd_port_open - Port open
            # . Purpose
            #   Probe a TCP connection to a specified host and port.
            #
            # . Description
            #   Uses nc -z if available; otherwise Bash /dev/tcp.
            #
            # . Arguments
            #   $1 - Hostname or IP address.
            #   $2 - TCP port number.
            #
            # . Returns
            #   0 when the connection succeeds; non-zero otherwise.
            #
            # . Usage
            #   ```bash
            #   sgnd_port_open "localhost" 443
            #   ```
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
            #   Print the first address listed by hostname -I.
            #
            # . Output
            #   Writes the first whitespace-delimited address, if any.
            #
            # . Returns
            #   Returns the pipeline status; an empty result does not necessarily produce an error.
            #
            # . Usage
            #   ```bash
            #   sgnd_get_ip
            #   ```
        sgnd_get_ip() { hostname -I 2>/dev/null | awk '{print $1}'; }
    # -- User context and ownership ---------------------------------------------------
        # fn: sgnd_real_user - Real user
            # . Purpose
            #   Print the non-root invoking user or the current user.
            #
            # . Output
            #   Writes SUDO_USER when it is set and not root; otherwise writes id -un.
            #
            # . Returns
            #   0 on successful output; otherwise the status of id -un.
            #
            # . Usage
            #   ```bash
            #   sgnd_real_user
            #   ```
        sgnd_real_user() {
            if [[ -n "${SUDO_USER-}" && "${SUDO_USER}" != "root" ]]; then
                printf '%s\n' "${SUDO_USER}"
            else
                id -un
            fi
        }
        # fn: sgnd_real_home - Real home
            # . Purpose
            #   Print the home directory of the invoking or current user.
            #
            # . Output
            #   Writes the passwd database home-directory field, if present.
            #
            # . Returns
            #   Returns the getent/cut pipeline status; an unknown user may yield empty output.
            #
            # . Usage
            #   ```bash
            #   sgnd_real_home
            #   ```
        sgnd_real_home() {
            local user
            user="$(sgnd_real_user)"
            getent passwd "${user}" | cut -d: -f6
        }
        # fn: sgnd_run_as_real_user - Run as real user
            # . Purpose
            #   Execute a command as the invoking user when running through sudo.
            #
            # . Arguments
            #   $@ - Command and its arguments.
            #
            # . Side effects
            #   May execute the command through sudo -u, or directly.
            #
            # . Returns
            #   Returns the executed command or sudo exit status.
            #
            # . Usage
            #   ```bash
            #   sgnd_run_as_real_user id -un
            #   ```
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
            #   Recursively assign a path to the invoking user and that user’s primary group.
            #
            # . Arguments
            #   $1 - File or directory path.
            #
            # . Side effects
            #   Calls chown -R on the supplied path.
            #
            # . Returns
            #   Returns the exit status of chown.
            #
            # . Usage
            #   ```bash
            #   sgnd_fix_ownership "/tmp/sgnd-example"
            #   ```
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
            #   Recursively set directory modes to 755 and file modes to 644.
            #
            # . Description
            #   This removes executable bits from regular files and does not preserve existing custom modes.
            #
            # . Arguments
            #   $1 - File or directory path.
            #
            # . Side effects
            #   Runs find/chmod on directories and files below the path.
            #
            # . Returns
            #   Returns the status of the final find/chmod command.
            #
            # . Usage
            #   ```bash
            #   sgnd_fix_permissions "/tmp/sgnd-example"
            #   ```
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
            # . Output
            #   Writes the ID value without quote characters.
            #
            # . Returns
            #   Returns the pipeline status.
            #
            # . Usage
            #   ```bash
            #   sgnd_get_os
            #   ```
        sgnd_get_os() { grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"'; }
        # fn: sgnd_get_os_version - Get os version
            # . Purpose
            #   Print VERSION_ID from /etc/os-release.
            #
            # . Output
            #   Writes the VERSION_ID value without quote characters.
            #
            # . Returns
            #   Returns the pipeline status.
            #
            # . Usage
            #   ```bash
            #   sgnd_get_os_version
            #   ```
        sgnd_get_os_version() { grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"'; }
    # -- Failure and command execution ------------------------------------------------
    # fn: sgnd_die - Die
        # . Purpose
        #   Print a failure message and exit the script.
        #
        # . Description
        #   Includes a stack trace in verbose mode; otherwise includes a caller reference.
        #
        # . Arguments
        #   $1 - Optional message.
        #   $2 - Exit code (default 1).
        #
        # . Side effects
        #   Logs the error and terminates the process.
        #
        # . Returns
        #   Does not return; exits with the requested status.
        #
        # . Usage
        #   ```bash
        #   sgnd_die "Unable to continue" 1
        #   ```
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
        #   Execute a command and report its failure without exiting.
        #
        # . Arguments
        #   $@ - Command and arguments.
        #
        # . Side effects
        #   Prints a failure message when the command fails.
        #
        # . Returns
        #   Returns the command exit status.
        #
        # . Usage
        #   ```bash
        #   sgnd_require test -d "/tmp"
        #   ```
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
        #   Execute a command or terminate the current script on failure.
        #
        # . Arguments
        #   $@ - Command and arguments.
        #
        # . Side effects
        #   Calls sgnd_die when the command fails.
        #
        # . Returns
        #   0 on success; otherwise exits with the command status.
        #
        # . Usage
        #   ```bash
        #   sgnd_must mkdir -p "/tmp/sgnd-example"
        #   ```
    sgnd_must() {
        "$@"
        local rc=$?

        (( rc == 0 )) && return 0
        sgnd_die "Fatal: $* (rc=$rc)" "$rc"
    }
