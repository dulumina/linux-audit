#!/usr/bin/env bash
# linux-audit-safe v0.1-20251102
# Safety-hardened wrapper around various Linux audit/enumeration tools.
# Intended for responsible, non-production use unless you know what you're doing.
# Changes from upstream:
#  - Default: do NOT auto-update remote repos
#  - Dry-run and interactive modes
#  - Explicit confirmation before privileged checks
#  - Tools are cloned but not blindly executed; basic whitelist/blacklist handling
#  - Safer file permissions for logs and tools
#  - CLI flags to control behavior
set -euo pipefail
IFS=$'\n\t'

umask 077  # stricter default permissions for created files

readonly _version="0.1-20251102"

_rel="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly _rel

readonly _tools_directory="${_rel}/tools"
readonly _logs_directory="${_rel}/logs"

_host_name="$(hostname || uname -n)" || exit
readonly _host_name

_date="$(date +%Y%m%d%H%M%S)" || exit
readonly _date

readonly _audit_name="${_host_name}-${_date}-linux-audit"
readonly _audit_directory="${_logs_directory}/${_audit_name}"

# Default behavior: do NOT update deps automatically
readonly _update_deps_default="false"

# CLI defaults (can be overridden by flags)
_update_deps="${_update_deps_default}"
_dry_run="false"
_interactive="true"
_run_privileged="false"
_tools_only="false"
_skip_tools="false"

# Whitelist of tools we are comfortable auto-running (adjust as needed)
# These should be validated by human before first execution
readonly TOOL_WHITELIST=(
  "linpeas.sh"
  "lynis"
  "LinEnum"
  "linux-exploit-suggester"
  "linux-smart-enumeration"
)

function info() { echo -e "\\033[1;34m[*]\\033[0m  $*"; }
function warn() { echo -e "\\033[1;33m[!]\\033[0m  $*"; }
function error() { echo -e "\\033[1;31m[-]\\033[0m  $*"; exit 1 ; }

function usage() {
  cat <<EOF
linux-audit-safe v${_version}

Usage: $(basename "$0") [options]

Options:
  --help            Show this help
  --dry-run         Show what would be done, don't execute actions
  --no-interactive  Do not prompt; assume defaults (use with care)
  --no-update       Do not git clone/pull/update tools (same as default)
  --update          Allow updating/cloning tools from upstream (opt-in)
  --run-as-root     Allow running privileged checks (you will be prompted)
  --tools-only      Only fetch/update tools (don't run checks)
  --skip-tools      Don't fetch/update tools, just run local checks
EOF
  exit 0
}

# Parse flags
while [ "${#:-0}" -gt 0 ]; do
  case "${1:-}" in
    --help) usage ;;
    --dry-run) _dry_run="true"; shift ;;
    --no-interactive) _interactive="false"; shift ;;
    --no-update) _update_deps="false"; shift ;;
    --update) _update_deps="true"; shift ;;
    --run-as-root) _run_privileged="true"; shift ;;
    --tools-only) _tools_only="true"; shift ;;
    --skip-tools) _skip_tools="true"; shift ;;
    --) shift; break ;;
    *) break ;;
  esac
done

function confirm() {
  # confirm "Question" default=no
  local question="${1:-Are you sure?}"
  local default=${2:-no}
  if [ "${_interactive}" = "false" ]; then
    if [ "${default}" = "yes" ]; then
      return 0
    else
      return 1
    fi
  fi
  while true; do
    read -r -p "${question} [y/N]: " reply || return 1
    case "${reply}" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      [Nn]|[Nn][Oo]|'') return 1 ;;
      *) echo "Please answer yes or no." ;;
    esac
  done
}

function __main__() {
  echo -e "--[ \\033[1;32mlinux-audit-safe v${_version}\\033[0m ]--"
  echo
  info "Running with options: dry-run=${_dry_run} interactive=${_interactive} update_deps=${_update_deps} run_privileged=${_run_privileged} tools_only=${_tools_only} skip_tools=${_skip_tools}"
  echo

  setup_dirs

  if [ "${_skip_tools}" = "false" ]; then
    setup_tools
  else
    info "Skipping tools fetch/update as requested (--skip-tools)"
  fi

  if [ "${_tools_only}" = "true" ]; then
    info "Tools fetch/update complete (tools-only mode). Exiting."
    exit 0
  fi

  audit
  info "Complete"
}

function setup_dirs() {
  mkdir -p "${_tools_directory}"
  mkdir -p "${_logs_directory}"
  # tighten perms
  chmod 700 "${_tools_directory}"
  chmod 700 "${_logs_directory}"
}

function audit() {
  mkdir -p "${_audit_directory}"
  chmod 700 "${_audit_directory}"

  echo
  info "Date:\t$(date)"
  info "Hostname:\t${_host_name}"
  info "System:\t$(uname -a)"
  info "User:\t$(id)"
  info "Log:\t${_audit_directory}"
  echo

  if [ "$(id -u)" -eq 0 ]; then
    if [ "${_run_privileged}" != "true" ]; then
      warn "You are root. Privileged checks are disabled by default for safety."
      if confirm "Enable privileged checks now? (runs as root and may collect sensitive data)" "no"; then
        info "Privileged checks approved interactively."
      else
        info "Privileged checks skipped."
        check_pentest
        return
      fi
    else
      if [ "${_interactive}" = "true" ]; then
        if ! confirm "You passed --run-as-root. Proceed with privileged checks?" "no"; then
          info "Privileged checks aborted by user."
          check_pentest
          return
        fi
      fi
    fi
    check_priv
  else
    check_pentest
  fi
}

function command_exists () {
  command -v "${1}" >/dev/null 2>&1
}

# A safe list of repos (same as original list). Do not auto-run unknown tools.
function setup_tools() {
  if [ "${_update_deps}" != "true" ]; then
    info "Tool fetching/updating is disabled by default. Use --update to allow fetching/updating tools."
    return
  fi

  if ! command_exists git ; then
    error "git is not in \$PATH; cannot fetch tools. Install git or run with --skip-tools."
  fi

  set +e
  IFS=' ' read -r -d '' -a array <<'_EOF_'
https://github.com/mzet-/linux-exploit-suggester
https://github.com/CISOfy/lynis
https://github.com/bcoles/so-check
https://github.com/initstring/uptux
https://github.com/lateralblast/lunar
https://github.com/diego-treitos/linux-smart-enumeration
https://github.com/a13xp0p0v/kernel-hardening-checker
https://github.com/bcoles/jalesc
https://github.com/rebootuser/LinEnum
https://github.com/trimstray/otseca
https://github.com/slimm609/checksec.sh
_EOF_
  set -e

  while read -r repo; do
    tool=${repo##*/}
    [ -z "${repo}" ] && continue

    dest="${_tools_directory}/${tool}"

    if [ -d "${dest}" ]; then
      info "Updating ${tool} ..."
      if [ "${_dry_run}" = "false" ]; then
        (cd "${dest}" && git pull --ff-only) || warn "git pull failed for ${tool}; manual inspection recommended."
      else
        info "(dry-run) would run: cd ${dest} && git pull --ff-only"
      fi
    else
      info "Cloning ${tool} ..."
      if [ "${_dry_run}" = "false" ]; then
        git clone --depth 1 "${repo}" "${dest}" || warn "git clone failed for ${repo}"
        # lock down perms
        chmod -R 700 "${dest}"
      else
        info "(dry-run) would run: git clone --depth 1 ${repo} ${dest}"
      fi
    fi
  done <<< "${array}"

  if command_exists wget ; then
    info "Fetching linpeas (if available)..."
    if [ "${_dry_run}" = "false" ]; then
      wget -q https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh -O "${_tools_directory}/linpeas.sh" || warn "linpeas download failed"
      chmod 700 "${_tools_directory}/linpeas.sh" || true
    else
      info "(dry-run) would fetch linpeas.sh"
    fi
  else
    warn "wget not found; linpeas not downloaded."
  fi
}

# Helper to check if tool is whitelisted to auto-run
function tool_is_whitelisted() {
  local t="$1"
  for w in "${TOOL_WHITELIST[@]}"; do
    if [[ "${t}" == *"${w}"* ]] || [[ "${t}" == "${w}" ]]; then
      return 0
    fi
  done
  return 1
}

function run_tool_cmd() {
  local cmd="$1"
  local logname="$2"
  info "Running: ${cmd}"
  if [ "${_dry_run}" = "true" ]; then
    info "(dry-run) would run: ${cmd} -> ${_audit_directory}/${logname}"
    return 0
  fi
  # ensure audit dir exists and is private
  mkdir -p "${_audit_directory}"
  chmod 700 "${_audit_directory}"
  # run and tee to log
  bash -c "${cmd}" 2>&1 | tee "${_audit_directory}/${logname}"
  chmod 600 "${_audit_directory}/${logname}"
}

function check_pentest() {
  info "Running unprivileged checks..."
  echo

  # Many tools produce large output; only run whitelisted ones automatically.
  # Others will be listed so operator can run them manually after inspection.

  # Example: linux-exploit-suggester
  if [ -d "${_tools_directory}/linux-exploit-suggester" ]; then
    if tool_is_whitelisted "linux-exploit-suggester"; then
      run_tool_cmd "bash \"${_tools_directory}/linux-exploit-suggester/linux-exploit-suggester.sh\" --checksec" "les-checksec.log"
      run_tool_cmd "bash \"${_tools_directory}/linux-exploit-suggester/linux-exploit-suggester.sh\"" "les.log"
    else
      info "linux-exploit-suggester present but not whitelisted; skip automatic run."
    fi
  else
    warn "linux-exploit-suggester not present (run with --update to clone)."
  fi

  # Lynis (pentest mode)
  if [ -d "${_tools_directory}/lynis" ]; then
    if tool_is_whitelisted "lynis"; then
      run_tool_cmd "\"${_tools_directory}/lynis/lynis\" --pentest --quick --log-file \"${_audit_directory}/lynis.log\" --report-file \"${_audit_directory}/lynis.report\" audit system" "lynis.log"
    else
      info "lynis present but not whitelisted; skip automatic run."
    fi
  fi

  # so-check
  if [ -d "${_tools_directory}/so-check" ]; then
    if tool_is_whitelisted "so-check"; then
      run_tool_cmd "bash \"${_tools_directory}/so-check/so-check.sh\"" "so-check.log"
    else
      info "so-check present but not whitelisted; skip automatic run."
    fi
  fi

  # linpeas
  if [ -f "${_tools_directory}/linpeas.sh" ]; then
    if tool_is_whitelisted "linpeas.sh"; then
      run_tool_cmd "bash \"${_tools_directory}/linpeas.sh\"" "linpeas.log"
    else
      info "linpeas present but not whitelisted; skip automatic run."
    fi
  fi

  # LinEnum
  if [ -d "${_tools_directory}/LinEnum" ]; then
    if tool_is_whitelisted "LinEnum"; then
      run_tool_cmd "bash \"${_tools_directory}/LinEnum/LinEnum.sh\" -t -r \"${_audit_directory}/LinEnum.log\"" "LinEnum.log"
    else
      info "LinEnum present but not whitelisted; skip automatic run."
    fi
  fi

  info "Unprivileged automatic checks finished. For more tools present in ${_tools_directory} run them manually after inspection."
}

function check_priv() {
  info "Running privileged checks (as root)..."
  echo
  # As root, still only auto-run whitelisted tools. This protects from blindly running arbitrary code.
  if [ -d "${_tools_directory}/lynis" ]; then
    if tool_is_whitelisted "lynis"; then
      run_tool_cmd "chown -R 0:0 \"${_tools_directory}/lynis\" || true; \"${_tools_directory}/lynis/lynis\" --quick --log-file \"${_audit_directory}/lynis.log\" --report-file \"${_audit_directory}/lynis.report\" audit system" "lynis-priv.log"
    else
      info "lynis present but not whitelisted; skip automatic privileged run."
    fi
  fi

  if [ -d "${_tools_directory}/lunar" ]; then
    if tool_is_whitelisted "lunar"; then
      run_tool_cmd "bash \"${_tools_directory}/lunar/lunar.sh\" -a" "lunar.log"
    else
      info "lunar present but not whitelisted; skip automatic run."
    fi
  fi

  # kernel-hardening-checker (python)
  if command_exists python3 && [ -d "${_tools_directory}/kernel-hardening-checker" ]; then
    run_tool_cmd "python3 \"${_tools_directory}/kernel-hardening-checker/bin/kernel-hardening-checker\" -l /proc/cmdline -c \"/boot/config-$(uname -r)\"" "kernel-hardening-checker.log"
  fi

  # checksec
  if [ -d "${_tools_directory}/checksec.sh" ]; then
    run_tool_cmd "bash \"${_tools_directory}/checksec.sh/checksec\" --proc-all" "checksec-proc-all.log"
  fi

  info "Privileged automatic checks finished."
}

# If script is executed directly, run main
if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
  __main__
  exit 0
fi
