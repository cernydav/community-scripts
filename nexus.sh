#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts
# Author: community-scripts
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.sonatype.com/products/sonatype-nexus-repository

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  curl \
  wget \
  gpg \
  openjdk-17-jdk \
  tar
msg_ok "Installed Dependencies"

msg_info "Creating Nexus User"
useradd -r -m -U -d /opt/nexus -s /bin/bash nexus
msg_ok "Created Nexus User"

msg_info "Installing Nexus Repository"
NEXUS_VERSION=$(curl -s https://api.github.com/repos/sonatype/nexus-public/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
NEXUS_VERSION=${NEXUS_VERSION#release-}
wget -q "https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz" -O /tmp/nexus.tar.gz
tar -xzf /tmp/nexus.tar.gz -C /opt
mv /opt/nexus-${NEXUS_VERSION} /opt/nexus-repository
mv /opt/sonatype-work /opt/nexus-data
chown -R nexus:nexus /opt/nexus-repository /opt/nexus-data
rm /tmp/nexus.tar.gz
msg_ok "Installed Nexus Repository"

msg_info "Configuring Nexus"
echo "run_as_user=\"nexus\"" >/opt/nexus-repository/bin/nexus.rc
cat <<'EOF' >/etc/systemd/system/nexus.service
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus-repository/bin/nexus start
ExecStop=/opt/nexus-repository/bin/nexus stop
User=nexus
Restart=on-abort
TimeoutSec=600

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable -q --now nexus
msg_ok "Configured Nexus"

msg_info "Waiting for Nexus to Start"
sleep 30
timeout 300 bash -c 'until curl -sf http://localhost:8081 >/dev/null 2>&1; do sleep 5; done' || true
msg_ok "Nexus Started"

msg_info "Getting Admin Password"
sleep 10
if [ -f /opt/nexus-data/admin.password ]; then
  ADMIN_PASS=$(cat /opt/nexus-data/admin.password)
  echo -e "\n${BL}Initial admin password: ${GN}${ADMIN_PASS}${CL}\n"
else
  echo -e "\n${YW}Admin password file not found yet. Check /opt/nexus-data/admin.password after startup completes${CL}\n"
fi
msg_ok "Admin Password Retrieved"

motd_ssh
customize

msg_info "Cleaning Up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
