#! /bin/bash -xe

# Install Docker and Docker Compose
yum update -y
yum install -y docker git
service docker start
usermod -a -G docker ec2-user
chkconfig docker on
curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose version
mkdir -p /opt/app /opt/data/weaviate_data
chown -R ec2-user:ec2-user /opt/app /opt/data
git clone https://github.com/chrisammon3000/aws-cdk-ec2-weaviate.git /opt/app
cd /opt/app && docker-compose up -d