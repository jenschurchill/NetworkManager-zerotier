#!/usr/bin/env bash
# SELinux helpers for the NetworkManager ZeroTier plugin.
#
# Fedora and other SELinux distros need two things, exposed here as two
# separate actions:
#
#   relabel (default action)
#       Restore policy-default labels on the installed files. Anything
#       installed by dev-install.sh (`sudo ninja install`) out of a
#       home-directory build tree carries user_home_t labels, which system
#       services are then denied to open - typically dbus-broker reading
#       /usr/share/dbus-1/system.d/nm-zerotier-*.conf (visible as audit
#       AVCs from dbus-broker-lau). RPM installs label files correctly,
#       so this is only needed after dev installs: run it after every
#       dev-install.sh. Paths this build doesn't install (e.g. the GTK
#       plugin in gtk4=false builds) and both lib/lib64 layouts are
#       handled automatically.
#
#   module
#       Build (when needed) and load the SELinux policy module from
#       packaging/selinux/ and relabel /var/lib/zerotier-one. One-time
#       per-machine setup; funnels through the same packaging/selinux
#       Makefile the RPM uses (%build runs `make`, %post does the
#       semodule -i + restorecon this action performs).
#
# Both actions exit 0 without doing anything when SELinux is missing or
# disabled, so callers don't need their own guards. The checks run
# unprivileged - no sudo prompt appears when there is nothing to do; the
# actual work requires root, which this script asks for itself.
#
# Usage:
#   contrib/selinux.sh relabel      (or just: contrib/selinux.sh)
#   contrib/selinux.sh module
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
action="${1:-relabel}"

selinux_enabled() {
    command -v getenforce >/dev/null 2>&1 \
        && command -v restorecon >/dev/null 2>&1 \
        && [ "$(getenforce)" != "Disabled" ]
}

case "$action" in
    relabel|module) ;;
    *)
        echo "usage: $0 [relabel|module]" >&2
        exit 2
        ;;
esac

# Unprivileged early-out: never prompt for root when there is nothing to do.
if ! selinux_enabled; then
    echo "selinux: not present or disabled - nothing to do"
    exit 0
fi

# Everything below needs root; self-elevate so callers can invoke this
# without their own sudo.
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$repo_root/contrib/selinux.sh" "$action"
fi

do_relabel() {
    # Everything dev-install.sh can install. Globs skip artifacts this
    # build variant doesn't install (e.g. gtk4=false); the
    # /usr/lib{,64}/ brace covers distros that put NetworkManager VPN
    # data under lib64 (Fedora: the .name goes to /usr/lib but the GTK
    # plugin to /usr/lib64). Nonexistent entries are filtered out below
    # because restorecon aborts on the first one it can't open.
    local candidates=() files=() f
    shopt -s nullglob
    candidates=(
        /usr/libexec/nm-zerotier-*
        /usr/lib{,64}/NetworkManager/VPN/nm-zerotier-service.name
        /usr/lib{,64}/NetworkManager/libnm-vpn-plugin-zerotier.so
        /usr/share/dbus-1/system.d/nm-zerotier-*.conf
        /usr/lib/systemd/system/nm-zerotier-reconciled.service
    )
    shopt -u nullglob

    # restorecon aborts on the first nonexistent argument, so keep only
    # files that actually exist (also protects against uninstall races).
    for f in "${candidates[@]}"; do
        [ -e "$f" ] && files+=("$f")
    done

    if [ ${#files[@]} -eq 0 ]; then
        echo "selinux: no installed nm-zerotier files found - run dev-install.sh first"
        return 0
    fi
    restorecon -v "${files[@]}"

    # The policy module must also be loaded once per machine; hint if it
    # isn't (the state dir keeps its var_lib_t label until then).
    if [ -d /var/lib/zerotier-one ]; then
        local label
        label=$(stat -c '%C' /var/lib/zerotier-one 2>/dev/null || true)
        case "$label" in
            *zerotier_var_lib_t*) ;;
            *)
                echo "selinux: policy module not loaded (/var/lib/zerotier-one is ${label:-unlabeled})"
                echo "selinux: one-time setup: sudo contrib/selinux.sh module"
                ;;
        esac
    fi
}

do_module() {
    make -C "$repo_root/packaging/selinux" install
}

case "$action" in
    relabel) do_relabel ;;
    module)  do_module ;;
esac
