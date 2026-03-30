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

echo "=== [1/5] Packages ==="
apt-get update -qq
apt-get install -y -qq rlwrap tmux virtualbox-guest-x11 dkms linux-headers-$(uname -r) 2>/dev/null || \
apt-get install -y -qq rlwrap tmux virtualbox-guest-x11 dkms linux-headers-amd64 2>/dev/null || \
apt-get install -y -qq rlwrap tmux virtualbox-guest-x11

echo "=== [2/5] VBoxGuest device node fix ==="
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

echo "=== [3/5] Clipboard autostart ==="
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/vboxclient-clipboard.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=VBoxClient Clipboard
Exec=VBoxClient --clipboard
X-GNOME-Autostart-enabled=true
DESKTOP

echo "=== [4/5] HiDPI settings ==="
# Only apply if host resolution is 4K+ (width >= 3840)
HOST_WIDTH=$(DISPLAY=:0 xrandr 2>/dev/null | awk '/\*/{print $1}' | head -1 | cut -dx -f1)
if [ "${HOST_WIDTH:-0}" -ge 3840 ] 2>/dev/null; then
  echo "4K display detected (${HOST_WIDTH}px). Applying HiDPI settings..."

  cat > /home/vagrant/.Xresources << 'XRES'
Xft.dpi: 192
XRES
  chown vagrant:vagrant /home/vagrant/.Xresources

  grep -q 'GDK_SCALE' /home/vagrant/.profile 2>/dev/null || cat >> /home/vagrant/.profile << 'ENVS'

# HiDPI scaling
export GDK_SCALE=2
export GDK_DPI_SCALE=0.5
export QT_SCALE_FACTOR=2
ENVS
else
  echo "Standard display (${HOST_WIDTH:-unknown}px). Skipping HiDPI."
fi

echo "=== [5/5] tmux config ==="
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

echo ""
echo "=========================================="
echo " Kali UX provisioning complete"
echo "=========================================="
echo " Reboot for full effect (devnodes + DPI)"
echo "=========================================="
