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
echo "Skipped — use Kali's built-in HiDPI mode (Settings > Window Manager > HiDPI)"

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

# Disconnect all scenario NICs from NetworkManager and flush
for iface in eth1 eth2 eth3 eth4; do
  sudo nmcli device disconnect "$iface" 2>/dev/null
  sudo ip addr flush dev "$iface" 2>/dev/null
  sudo ip link set "$iface" down 2>/dev/null
done

case "$1" in
  1) sudo ip link set eth1 up
     sudo ip addr add 10.0.10.10/24 dev eth1 2>/dev/null
     echo "Switched to SNet1 network (10.0.10.10 on SNet-Net)" ;;
  2) sudo ip link set eth2 up
     sudo ip addr add 10.0.20.10/24 dev eth2 2>/dev/null
     echo "Switched to SNet2 network (10.0.20.10 on SNet2-Net)" ;;
  3) sudo ip link set eth3 up
     sudo ip addr add 10.0.30.10/24 dev eth3 2>/dev/null
     echo "Switched to SNet3 network (10.0.30.10 on SNet3-Net)" ;;
  128) sudo ip link set eth4 up
     sudo ip addr add 10.0.128.10/24 dev eth4 2>/dev/null
     echo "Switched to VulnHub network (10.0.128.10 on VulnHub-Net)" ;;
  *) echo "Usage: snet-switch {1|2|3|128}"; exit 1 ;;
esac
SCRIPT
chmod +x /usr/local/bin/snet-switch

# Default: SNet1 active, all others inactive
for iface in eth2 eth3 eth4; do
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
