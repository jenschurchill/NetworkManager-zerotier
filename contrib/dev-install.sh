#!/usr/bin/env bash
# Rebuild, (re)install, and restart NetworkManager so it picks up the new
# plugin. Meant to be re-run after every source change during development -
# there's no hot reload: NM re-activates the daemon fresh per connect, but
# .name/.so changes require a NetworkManager restart (and relaunching
# gnome-control-center / nm-connection-editor) to be picked up.
#
# Meson options are sticky per build dir: the --reconfigure below only
# overrides the prefix, so `build/` keeps whatever -D options it was first
# configured with (e.g. `meson setup build --prefix=/usr -Dgtk4=false`).
# Deleting `build/` resets them to the defaults - the echo below shows
# what's actually built.
set -euo pipefail
cd "$(dirname "$0")/.."

meson setup --reconfigure build --prefix=/usr
echo "Effective meson options:"
meson configure build | grep -E '^ *gtk4 ' || true
ninja -C build
sudo ninja -C build install
./contrib/selinux.sh relabel

sudo systemctl restart NetworkManager
sudo systemctl daemon-reload
sudo systemctl enable --now nm-zerotier-reconciled
sudo systemctl restart nm-zerotier-reconciled

echo
echo "Installed. Try:"
echo "  nmcli connection add type vpn vpn-type zerotier ifname -- con-name zt-test vpn.data \"network-id=<16hexid>\""
echo "  nmcli connection up zt-test"
