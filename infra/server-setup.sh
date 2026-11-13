#!/usr/bin/env bash
# One-time preparation of a fresh Ubuntu 24.04 server (docs/04-delivery/05-DEPLOYMENT.md).
# deploy.sh runs it the first time, as root. Safe to run again.
set -euo pipefail
APP_USER="${SUDO_USER:-ubuntu}"
export DEBIAN_FRONTEND=noninteractive

echo "Time zone: Africa/Tunis"
timedatectl set-timezone Africa/Tunis

echo "System updates and packages (Docker from Ubuntu, firewall, ban of password guessers)"
apt-get update -q
apt-get upgrade -yq
apt-get install -yq docker.io docker-compose-v2 ufw fail2ban unattended-upgrades rsync
systemctl enable --now docker
usermod -aG docker "$APP_USER"

echo "Firewall: only SSH, HTTP and HTTPS are open"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable

echo "2 GB of swap, a safety margin for the 4 GB of memory"
if ! swapon --show | grep -q /swapfile; then
	fallocate -l 2G /swapfile
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile
fi
grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
echo 'vm.swappiness=10' > /etc/sysctl.d/99-ngclass.conf
sysctl -q --system

echo "Security updates installed automatically"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

echo "Nightly backup at 02:00 (database and uploaded files, 30 days kept)"
chmod +x /opt/ngclass/infra/backup.sh
echo '0 2 * * * root /opt/ngclass/infra/backup.sh >> /var/log/ngclass-backup.log 2>&1' > /etc/cron.d/ngclass-backup
chmod 644 /etc/cron.d/ngclass-backup

echo "Server ready."
