#!/usr/bin/env bash
# bootstrap.sh — run as root on a fresh Ubuntu 22.04+ VPS
# Usage: ssh root@<VPS_HOST> 'bash -s' < scripts/bootstrap.sh
# Env:   VPS_USER (default: vyshnav)
set -euo pipefail

VPS_USER="${VPS_USER:-vyshnav}"

echo "==> Creating user: $VPS_USER"
if id "$VPS_USER" &>/dev/null; then
  echo "    User already exists, skipping."
else
  adduser --disabled-password --gecos "" "$VPS_USER"
  usermod -aG sudo "$VPS_USER"
fi

echo "==> Copying SSH authorized_keys"
mkdir -p "/home/$VPS_USER/.ssh"
if [ -f /root/.ssh/authorized_keys ]; then
  cp /root/.ssh/authorized_keys "/home/$VPS_USER/.ssh/authorized_keys"
fi
chmod 700 "/home/$VPS_USER/.ssh"
chmod 600 "/home/$VPS_USER/.ssh/authorized_keys" 2>/dev/null || true
chown -R "$VPS_USER:$VPS_USER" "/home/$VPS_USER/.ssh"

echo "==> Hardening SSH"
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh

echo "==> Installing sudo, curl, ufw"
apt-get update -qq
apt-get install -y -qq sudo curl ufw

echo ""
echo "Done. Connect as: ssh $VPS_USER@<VPS_HOST>"
echo "Then run: bash scripts/provision.sh"
