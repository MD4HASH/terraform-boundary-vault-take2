#!/bin/sh
set -e  # exit on any error

# Update packages
sudo apt-get update -y
sudo apt-get install -y wget gnupg lsb-release curl apt-transport-https ca-certificates software-properties-common


# Add HashiCorp repo GPG key
# https://developer.hashicorp.com/boundary/tutorials/enterprise/ent-deployment-guide
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
# Add HashiCorp repository
codename=$(grep '^UBUNTU_CODENAME=' /etc/os-release | cut -d= -f2 || lsb_release -cs)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $codename main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Boundary
sudo apt-get update -y
sudo apt-get install -y boundary

# Install Vault
# https://developer.hashicorp.com/vault/downloads#linux
sudo apt-get install -y vault

# Install Postgress
# https://www.postgresql.org/download/linux/ubuntu/
sudo apt-get install -y postgresql postgresql-contrib
# configure postgress
sudo -u postgres psql -c "CREATE USER boundary WITH PASSWORD 'derp';"
sudo -u postgres psql -c "CREATE DATABASE boundary OWNER boundary;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE boundary TO boundary;"

# move service and config files

sudo mkdir -p /etc/vault.d/ /etc/boundary.d/ /tmp/vault/data
sudo mv /tmp/vault.hcl /etc/vault.d/vault.hcl
sudo chown root:root /etc/vault.d/vault.hcl
sudo chmod 640 /etc/vault.d/vault.hcl
sudo mv /tmp/vault.service /etc/systemd/system/vault.service

# enable services
sudo systemctl unmask vault
sudo systemctl daemon-reload
sudo systemctl enable vault 
sudo systemctl start vault

until nc -z 127.0.0.1 8200 >/dev/null 2>&1; do
  echo "Waiting for Vault to start listening on port 8200..."
  sleep 2
done

sudo vault operator init -key-shares=5 -key-threshold=3 -format=json -address="http://127.0.0.1:8200" > ~/vault_init.json