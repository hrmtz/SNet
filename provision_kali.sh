#!/bin/bash
# provision_kali.sh — Kali VM UX patches
# Run on a fresh Kali VM or via: vagrant provision kali
#
# Covers:
#   - rlwrap/tmux for reverse shell usability
#   - VirtualBox Guest Additions clipboard fix (devnode + autostart)
#   - HiDPI / display scaling for high-res hosts
#   - tmux config

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== [1/6] Packages ==="
apt-get update -qq
apt-get install -y -qq rlwrap tmux virtualbox-guest-x11 dkms linux-headers-$(uname -r) 2>/dev/null || \
apt-get install -y -qq rlwrap tmux virtualbox-guest-x11 dkms linux-headers-amd64 2>/dev/null || \
apt-get install -y -qq rlwrap tmux virtualbox-guest-x11

echo "=== [2/6] VBoxGuest device node fix ==="
# Kali's vboxguest module loads but doesn't create /dev/vboxguest.
# This service creates the device nodes at boot with retry.
cat > /usr/local/bin/vbox-devnodes.sh << 'SCRIPT'
#!/bin/sh
i=0
while [ $i -lt 30 ]; do
  grep -q vboxguest /proc/misc 2>/dev/null && break
  sleep 1
  i=$((i + 1))
done
GUEST_MINOR=$(awk '/vboxguest/{print $1}' /proc/misc)
USER_MINOR=$(awk '/vboxuser/{print $1}' /proc/misc)
[ -n "$GUEST_MINOR" ] && [ ! -e /dev/vboxguest ] && mknod -m 0666 /dev/vboxguest c 10 $GUEST_MINOR
[ -n "$USER_MINOR" ] && [ ! -e /dev/vboxuser ] && mknod -m 0666 /dev/vboxuser c 10 $USER_MINOR
true
SCRIPT
chmod +x /usr/local/bin/vbox-devnodes.sh

cat > /etc/systemd/system/vboxguest-devnodes.service << 'UNIT'
[Unit]
Description=Create VBoxGuest device nodes
After=systemd-modules-load.service systemd-udevd.service
Before=display-manager.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/vbox-devnodes.sh

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable vboxguest-devnodes.service

echo "=== [3/6] Clipboard autostart ==="
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/vboxclient-clipboard.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=VBoxClient Clipboard
Exec=/bin/sh -c "VBoxClient --clipboard"
X-GNOME-Autostart-enabled=true
DESKTOP

echo "=== [4/6] HiDPI settings ==="
# Only apply if host resolution is 4K+ (width >= 3840)
HOST_WIDTH=$(DISPLAY=:0 xrandr 2>/dev/null | awk '/\*/{print $1}' | head -1 | cut -dx -f1)
if [ "${HOST_WIDTH:-0}" -ge 3840 ] 2>/dev/null; then
  echo "4K display detected (${HOST_WIDTH}px). Applying HiDPI settings..."

  # DPI-only scaling (no GDK_SCALE=2 — causes inconsistent sizing)
  cat > /home/vagrant/.Xresources << 'XRES'
Xft.dpi: 144
XRES
  chown vagrant:vagrant /home/vagrant/.Xresources

  grep -q 'GDK_SCALE' /home/vagrant/.profile 2>/dev/null || cat >> /home/vagrant/.profile << 'ENVS'

# HiDPI scaling (DPI-only, no integer scaling)
export GDK_SCALE=1
export GDK_DPI_SCALE=1
export QT_SCALE_FACTOR=1.5
ENVS

  # Apply xfconf settings on first GUI login via autostart
  cat > /etc/xdg/autostart/snet-hidpi.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=SNet HiDPI Settings
Exec=/usr/local/bin/snet-hidpi.sh
X-GNOME-Autostart-enabled=true
DESKTOP

  cat > /usr/local/bin/snet-hidpi.sh << 'SCRIPT'
#!/bin/sh
# Apply once, then self-disable
if [ ! -f "$HOME/.snet-hidpi-done" ]; then
  xfconf-query -c xsettings -p /Xft/DPI -s 144
  xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 48
  xfconf-query -c xsettings -p /Gtk/IconSizes -s "gtk-menu=36,36:gtk-button=36,36:gtk-dialog=72,72:gtk-dnd=36,36:gtk-large-toolbar=36,36:gtk-small-toolbar=36,36"
  xfconf-query -c xfce4-desktop -p /desktop-icons/icon-size -s 54
  xfconf-query -c xfce4-panel -p /plugins/plugin-1/menu-width -s 675
  xfconf-query -c xfce4-panel -p /plugins/plugin-1/menu-height -s 1050
  xfconf-query -c xsettings -p /Gtk/KeyTheme --create -t string -s Emacs
  touch "$HOME/.snet-hidpi-done"
fi
SCRIPT
  chmod +x /usr/local/bin/snet-hidpi.sh
else
  echo "Standard display (${HOST_WIDTH:-unknown}px). Skipping HiDPI."
fi

echo "=== [5/6] tmux config ==="
cat > /home/vagrant/.tmux.conf << 'TMUX'
# Mouse scrolling
set -g mouse on

# Scroll buffer
set -g history-limit 50000

# Status bar
set -g status-bg colour235
set -g status-fg colour136
set -g status-left '[#S] '
set -g status-right '%H:%M'

# Window numbering from 1
set -g base-index 1
TMUX
chown vagrant:vagrant /home/vagrant/.tmux.conf

echo "=== [6/6] SNet network switch ==="
cat > /usr/local/bin/snet-switch << 'SCRIPT'
#!/bin/bash
# snet-switch — toggle active SNet network
# eth0=NAT (Vagrant), eth1=SNet-Net, eth2=SNet2-Net, eth3=SNet3-Net
# To add a new scenario: add a case entry for the new ethN

# Bring all scenario NICs down first
for iface in eth1 eth2 eth3; do
  sudo ip link set "$iface" down 2>/dev/null
done

case "$1" in
  1) sudo ip link set eth1 up 2>/dev/null
     echo "Switched to SNet1 network (10.0.1.10 on SNet-Net)" ;;
  2) sudo ip link set eth2 up 2>/dev/null
     echo "Switched to SNet2 network (10.0.2.10 on SNet2-Net)" ;;
  3) sudo ip link set eth3 up 2>/dev/null
     echo "Switched to SNet3 network (10.0.3.10 on SNet3-Net)" ;;
  *) echo "Usage: snet-switch {1|2|3}"; exit 1 ;;
esac
SCRIPT
chmod +x /usr/local/bin/snet-switch

# Default: SNet1 active, all others inactive
for iface in eth2 eth3; do
  ip link show "$iface" &>/dev/null && ip link set "$iface" down
done

echo ""
echo "=========================================="
echo " Kali UX provisioning complete"
echo "=========================================="
echo " Reboot for full effect (devnodes + DPI)"
echo " Use 'snet-switch N' to switch network."
echo " (e.g. snet-switch 1, snet-switch 2)"
echo "=========================================="
