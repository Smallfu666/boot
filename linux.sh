#!/bin/sh
# 新 Linux 機器上線：裝 SSH、信任 Mac 的金鑰、加入 Tailscale，讓 Mac 能遠端 SSH 進來。
# 用法（機器要能上網）：curl -fsSL https://is.gd/nklnx | sudo sh
# 可以重複跑；已經做好的步驟會跳過。
set -eu

MAC_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJpZBHkayfHyqkMd3Up10zjIDCATGNZYgEGLDILRK4RO'

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
die() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$1" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die 'Run with sudo:  curl -fsSL https://is.gd/nklnx | sudo sh'

TARGET_USER="${SUDO_USER:-}"
[ -n "$TARGET_USER" ] || TARGET_USER="$(logname 2>/dev/null || true)"
[ -n "$TARGET_USER" ] || TARGET_USER=root
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[ -n "$TARGET_HOME" ] || die "cannot find home of $TARGET_USER"

step '1/5 Install OpenSSH server'
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server curl
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y -q openssh-server curl
elif command -v yum >/dev/null 2>&1; then
  yum install -y -q openssh-server curl
elif command -v zypper >/dev/null 2>&1; then
  zypper -q -n install openssh curl
elif command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm --needed openssh curl
else
  die 'unknown package manager; install openssh-server by hand and run again'
fi
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd

step "2/5 Trust the Mac's SSH key for user $TARGET_USER"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
install -d -m 700 -o "$TARGET_USER" -g "$TARGET_GROUP" "$TARGET_HOME/.ssh"
AK="$TARGET_HOME/.ssh/authorized_keys"
touch "$AK"
grep -qF "$MAC_KEY" "$AK" || printf '%s\n' "$MAC_KEY" >> "$AK"
chown "$TARGET_USER:$TARGET_GROUP" "$AK"
chmod 600 "$AK"
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q 'Status: active'; then
  ufw allow in on tailscale0 to any port 22 proto tcp >/dev/null
fi

step '3/5 Keep the machine awake (a sleeping machine cannot be reached)'
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1 || true

step '4/5 Install Tailscale'
command -v tailscale >/dev/null 2>&1 || curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable --now tailscaled >/dev/null 2>&1 || true

step '5/5 Join the tailnet'
if tailscale status >/dev/null 2>&1; then
  echo 'Already logged in to Tailscale.'
else
  echo 'Send the login URL below (or a photo of the QR code) to Nick, then wait here until it says Success.'
  tailscale up --qr
fi

IP="$(tailscale ip -4 2>/dev/null | head -n1)"
printf '\n\033[1;32mDONE. Send this line to Nick:\033[0m\n'
printf '  user=%s  host=%s  tailscale_ip=%s  os=%s\n' "$TARGET_USER" "$(hostname)" "${IP:-?}" "$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-linux}")"
