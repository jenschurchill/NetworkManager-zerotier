# Spec for NetworkManager-zerotier on Fedora.
#
# Produces two binary RPMs:
#   network-manager-zerotier      - backend VPN service + reconciler (Requires zerotier-one)
#   network-manager-zerotier-gtk  - GTK4 editor plugin (nm-connection-editor / GNOME)
#
# A KDE (plasma-nm) editor plugin is packaged separately, see
# https://invent.kde.org/jemech/networkmanager-zerotier
#
# Build via the top-level Makefile ("make package") or:
#   rpmbuild -bb packaging/network-manager-zerotier.spec

Name:    network-manager-zerotier
Version: 1.0.0
Release: 1%{?dist}
Summary: NetworkManager VPN plugin for ZeroTier

License: GPL-2.0-or-later
URL:     https://github.com/ivolucas/NetworkManager-zerotier
Source0: %{name}-%{version}.tar.gz

BuildRequires: meson
BuildRequires: gcc
BuildRequires: NetworkManager-libnm-devel
BuildRequires: json-glib-devel
BuildRequires: systemd-rpm-macros

# GTK editor plugin
BuildRequires: gtk4-devel

# SELinux policy module for the VPN plugin (NetworkManager_t reads the
# zerotier-one control files in /var/lib/zerotier-one)
BuildRequires: selinux-policy-devel
BuildRequires: make


Requires:        NetworkManager
Requires:        zerotier-one
Requires(post):  systemd
Requires(post):  policycoreutils
Requires(preun): systemd
Requires(postun): systemd
Requires(postun): policycoreutils

%description
A NetworkManager VPN plugin for ZeroTier, so ZeroTier networks can be
joined/left and shown as VPN connections in nmcli, connection editors and
the desktop network applets. It talks to the running zerotier-one daemon
(via zerotier-cli) and reports the resulting interface and assigned
addresses back to NetworkManager.

This package contains the backend: the D-Bus-activated VPN service, the
nm-zerotier-reconciled system service that keeps NetworkManager and
zerotier-one state in sync, and the ZeroTier VPN service registration.

Install network-manager-zerotier-gtk for the GTK connection editor, or the
separate KDE plugin for plasma-nm.

%package gtk
Summary: GTK4 (GNOME/nm-connection-editor) editor plugin for ZeroTier VPN connections
Requires: %{name}%{?_isa} = %{version}-%{release}

%description gtk
GTK4 editor plugin for ZeroTier VPN connections, loaded by
nm-connection-editor and GNOME Settings > Network.

%prep
%setup -q

%build
%meson -Dgtk4=true
%meson_build

# SELinux policy module
make -C packaging/selinux

%check
%meson_test

%install
%meson_install
install -Dpm 644 packaging/selinux/nm-zerotier.pp \
    %{buildroot}%{_datadir}/selinux/packages/nm-zerotier.pp

%files
%license LICENSE
%{_libexecdir}/nm-zerotier-service
%{_libexecdir}/nm-zerotier-reconciled
%{_libexecdir}/nm-zerotier-auth-dialog
/usr/lib/NetworkManager/VPN/nm-zerotier-service.name
%{_datadir}/dbus-1/system.d/nm-zerotier-service.conf
%{_datadir}/dbus-1/system.d/nm-zerotier-status.conf
%{_unitdir}/nm-zerotier-reconciled.service
%{_datadir}/selinux/packages/nm-zerotier.pp

%post
%systemd_post nm-zerotier-reconciled.service
semodule -i %{_datadir}/selinux/packages/nm-zerotier.pp
restorecon -R /var/lib/zerotier-one 2>/dev/null || :

%preun
%systemd_preun nm-zerotier-reconciled.service

%postun
%systemd_postun nm-zerotier-reconciled.service
if [ $1 -eq 0 ]; then
    semodule -r nm-zerotier 2>/dev/null || :
    restorecon -R /var/lib/zerotier-one 2>/dev/null || :
fi

%files gtk
%{_libdir}/NetworkManager/libnm-vpn-plugin-zerotier.so

%changelog
* Mon Aug 24 2026 NetworkManager-zerotier contributors - 1.0.0-1
- Initial Fedora packaging: backend and GTK4 editor plugin
