#!/bin/bash
set -euo pipefail
INSTALL_MONITORING=${install_monitoring}
INSTANCE_NAME=${instance_name}
LOG_FILE="/var/log/user-data.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Bootstrapping $INSTANCE_NAME"
yum update -y
yum install -y docker git jq htop
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

if [ "$INSTALL_MONITORING" = "true" ]; then
  # Install Node Exporter
  cd /tmp
  curl -sLO https://github.com/prometheus/node_exporter/releases/latest/download/node_exporter-*.linux-amd64.tar.gz
  tar -xf node_exporter-*.linux-amd64.tar.gz
  mv node_exporter-*.linux-amd64/node_exporter /usr/local/bin/
  cat <<EOF2 > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
[Service]
ExecStart=/usr/local/bin/node_exporter
Restart=always
[Install]
WantedBy=multi-user.target
EOF2
  systemctl enable --now node_exporter

  # Docker compose monitoring stack
  mkdir -p /home/ec2-user/monitoring
  cat <<EOF3 > /home/ec2-user/monitoring/docker-compose.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    ports: ["9090:9090"]
    volumes: ["./prometheus.yml:/etc/prometheus/prometheus.yml", "prom-data:/prometheus"]
  grafana:
    image: grafana/grafana:latest
    ports: ["3000:3000"]
    environment: [GF_SECURITY_ADMIN_PASSWORD=admin]
volumes:
  prom-data:
EOF3
  cat <<EOF4 > /home/ec2-user/monitoring/prometheus.yml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF4
  cd /home/ec2-user/monitoring
  docker-compose up -d
  chown -R ec2-user:ec2-user /home/ec2-user/monitoring
fi
echo "Bootstrap complete."
