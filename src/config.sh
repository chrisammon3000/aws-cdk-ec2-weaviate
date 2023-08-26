#!/bin/bash -xe

# Mounting EBS to m6i
DEBIAN_FRONTEND=noninteractive 
apt-get update -y
# Ubuntu 20 Bug prevents upgrading docker.io package noninteractively
# apt-get upgrade -y
# systemctl restart docker

# Format and mount the EBS volume to /opt
mkfs -t ext4 /dev/nvme1n1
mount /dev/nvme1n1 /opt

# Backup existing fstab and add the new mount entry
cp /etc/fstab /etc/fstab.bak
echo '/dev/nvme1n1 /opt ext4 defaults,nofail 0 0' | sudo tee -a /etc/fstab
mount -a

# Install Docker Compose and run
# https://www.cherryservers.com/blog/how-to-install-and-use-docker-compose-on-ubuntu-20-04
apt update -y
apt install ca-certificates curl gnupg lsb-release -y
mkdir /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
apt-get update -y
apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin git -y
usermod -a -G docker ubuntu

# Clone the repository to /opt/app
export REPOSITORY_URL=https://github.com/chrisammon3000/aws-cdk-ec2-weaviate.git
git clone $REPOSITORY_URL /opt/app

# Create the app and data directory to be mounted as a persistent volume
mkdir -p /opt/app /opt/data/weaviate_data

# Run Docker Compose
cd /opt/app && docker compose up -d
