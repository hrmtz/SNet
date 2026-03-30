#!/bin/bash
# provision_target.sh — UX improvements for reverse shell usability
# Run this during target box building (not during vagrant up).
# The target VM disables Vagrant SSH, so this cannot be a Vagrant provisioner.

set -euo pipefail

BASHRC_BLOCK='
# --- SNet UX: shell usability for reverse shells ---
# Tab completion
bind "set completion-ignore-case on"
bind "TAB:menu-complete"
bind "\"\e[Z\":menu-complete-backward"

# Arrow keys: history search
bind "\"\e[A\":history-search-backward"
bind "\"\e[B\":history-search-forward"

# History
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL=ignoredups

# Colors
export TERM=xterm-256color
alias ls="ls --color=auto"
alias grep="grep --color=auto"
# --- end SNet UX ---'

# NOTE: socat is pre-installed in the box image.
# Do NOT run dnf/yum here — it pollutes root's .bash_history.

# Per-user .bashrc
for user_home in /home/webuser /home/support /home/rocky; do
  if [ -d "$user_home" ]; then
    bashrc="$user_home/.bashrc"
    if ! grep -q 'SNet UX' "$bashrc" 2>/dev/null; then
      echo "$BASHRC_BLOCK" >> "$bashrc"
      chown "$(basename "$user_home"):" "$bashrc"
    fi
  fi
done

# Global fallback (covers root and any other users)
if ! grep -q 'SNet UX' /etc/bash.bashrc 2>/dev/null; then
  echo "$BASHRC_BLOCK" >> /etc/bash.bashrc
fi

# --- .bash_history: CTF forensic artifacts ---
# Root: sysadmin fumbling with typos, DB passwords in plaintext
cat > /root/.bash_history << 'HISTEOF'
cat /var/log/messages
systemctl status httpd
systemctl status php-fpm
cd /var/log/
ls
cd httpd/
ls
cat ironguard-clinic-ssl_access_log
cat ironguard-clinic-ssl_access_log | grep "503"
cat ironguard-clinic-ssl_access_log | grep "503" | grep "15/Oct"
cat ironguard-clinic-ssl_access_log | grep "503" | grep "15/Oct/2024:08:"
cat ironguard-clinic-ssl_access_log | grep "503" | grep "15/Oct/2024:07:"
cat ironguard-clinic-ssl_access_log | grep "200" | grep "15/Oct/2024:07:" | grep -v "wp-content"
cat ironguard-clinic-ssl_access_log | grep " 200 " | grep "15/Oct/2024:07:" | grep -v "wp-content"
ls -lha
cat ironguard-clinic-ssl_error_log
cat ironguard-clinic-ssl_error_log | grep "failed"
cat ironguard-clinic-ssl_error_log | grep "failed" | grep "sock"
free -m
exit
systemctl status httpd
systemctl restart httpd
ls
cd /var/log/
ls
cd httpd/
ls
cat error_log
cat ironguard-clinic-ssl_error_log
systemctl status php-fmp
systemctl status php-fpm
systemctl restart php-fpm
cat ironguard-clinic-ssl_access_log | gerp "503"
cat ironguard-clinic-ssl_access_log | gerp "503"
cat ironguard-clinic-ssl_access_log | grep "503"
exit
cd /home/
ls
cd webuser/
ls
cd public_html/
ls
cd igmc/
ls
cat wp-config.php
cat wp-config.php | grep "DB"
cat wp-config.php | grep "DB" | grep -v "#"
cat wp-config.php | grep "DB" | grep -v "#" | grep -v "//"
mysql -u clinicwp -pmedicine1 clinicwpdb
mysql -u root
ls
cd
ls
cd /etc/httpd/
ls
cd conf.d/
ls
cat ironguard.conf
vi ironguard.conf
httpd -t
systemctl relaod httpd
systemctl relaod httpd
systemctl reload httpd
ls
cat ironguard.conf
cat test-ironguard.conf
ls
vi test-ironguard.conf
httpd -t
systemctl reload httpd
exit
cd /home/
ls
cd webuser/
ls
cd public_html/
ls -la
chmod 755 .
ls
grep -ir "fs_method" ./
cd igmc/
ls -la
cat wp-config.php
cd
ftpasswd --passwd --file=/home/webuser/ftpd.passwd --name=yamada --uid=1002 --gid=1002 --home=/home/webuser/public_html --shell=/bin/false
systemctl status proftpd
systemctl reload proftpd
ftpasswd --passwd --file=/home/webuser/ftpd.passwd --name=yamada --uid=1002 --gid=1002 --home=/home/webuser/public_html --shell=/bin/false
ip addr
systemctl restart proftp
systemctl restart proftpd
tail -f /var/log/secure
ftpasswd --passwd --file=/home/webuser/ftpd.passwd --name=yamada --uid=1002 --gid=1002 --home=/home/webuser/public_html --shell=/bin/false
exit
adduser support
passwd support
usermod -aG wheel support
cat /etc/group | grep wheel
exit
mysqldump -u clinicwp -pmedicine1 clinicwpdb > /tmp/clinicwpdb-backup.sql
ls /tmp/
rm /tmp/clinicwpdb-backup.sql
mysqldump -u clinicwp -pmedicine1 clinicwpdb > /home/webuser/clinicwpdb-20240719.sql
ls
ls -lha /home/webuser/
exit
cat /var/log/messages
free -m
top
exit
cd /home/
ls
cd webuser/
ls
cd public_html/
ls
find ./ -name "wp-config.php"
cat index.php
cd igmc/
ls
cat wp-config.php| grep "DB"
cat wp-config.php| grep "DB" | grep -v "#"
cat wp-config.php| grep "DB" | grep -v "#" | grep -v "//"
mysqldump -u clinicwp -p clinicwpdb > /home/webuser/clinicwpdb-20241015.sql
mysqldump -u clinicwp -pmedicine1 clinicwpdb > /home/webuser/clinicwpdb-20241015.sql
ls
cd
ls
cd /home/
ls
cd rocky/
ls
vi .ssh/authorized_keys
su -l rocky
cd
ls
ls -all
exit
HISTEOF
chmod 600 /root/.bash_history

# Rocky: sudo su - spam, typos
cat > /home/rocky/.bash_history << 'HISTEOF'
exit
sudo su -
vi .ssh/authorized_keys
exit
sudo su -
exit
ip addr
top
ip addr
adduser support
sudo su -
clear
sudo su -
sudo su -
exit
sudo su -
exit
sudo su -
exit
cat /etc/passwd
sudo su -
exit
sudo su -
sudo su -
sudo su -
sudo su -
exit
sudo su -
sudo su -
sudo su -
ls
sudo -s
ls
sudo -s
ls
cd /home/
ls
cd webuser/
ls
cd public_html/
ls
find ./ -mtime -30
find ./ -mtime -60
ls -la igmc/wp-content/uploads/
find ./ -mmin -120
ls
cd /home/
ls
cd /var/log/
ls
cd httpd/
ls
sudo -s
ls
sudo -s
ls
sudo -s
ls
sudo -s
ls
sudo -s
ls
cat .ssh/authorized_keys
cd
ls
cat /var/log/secure
exit
sudo -s
sudo su -
exit
sudo su -
exit
sudo su -
exit
sudo su -
exit
ls
cat /var/log/messages
sudo -s
sudo su -
sudo -s
cd .ssh/
ls
vi authorized_keys
ls -lha
exit
php -v && mmysql --version
php -v && mysql --version
cd /home/webuser/public_html
ls
cat igmc/wp-includes/version.php | grep wp_version
cat /etc/os-release | grep VERSION
dnf history | head -10
php -v && httpd -v && mysql -V
dnf history
exit
sudo -s
cd /home/
l
cd webuser/
ls
cd public_html/
ls
find ./ -mtime -3
find ./ -mtime -3 | grep ".php"
find ./ -name "header.php"
cd igmc/wp-content/themes
ls
ls -lha
exit
HISTEOF
chown rocky:rocky /home/rocky/.bash_history
chmod 600 /home/rocky/.bash_history

# Support: minimal SSH setup (work account)
cat > /home/support/.bash_history << 'HISTEOF'
mkdir .ssh
vi .ssh/authorized_keys
chmod 600 .ssh/authorized_keys
chmod 700 .ssh/
vi /etc/hosts
exit
HISTEOF
chown support:support /home/support/.bash_history
chmod 600 /home/support/.bash_history

echo "Target UX provisioning complete."
