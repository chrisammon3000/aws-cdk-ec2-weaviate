#!/bin/bash -xe

# Mounting EBS to m6i
DEBIAN_FRONTEND=noninteractive 
apt-get update -y
# Ubuntu 20 Bug prevents upgrading docker.io package noninteractively
# apt-get upgrade -y
# systemctl restart docker
mkfs -t ext4 /dev/nvme1n1
mkdir /data
mount /dev/nvme1n1 /data
cp /etc/fstab /etc/fstab.bak
echo '/dev/nvme1n1 /data ext4 defaults,nofail 0 0' | sudo tee -a /etc/fstab
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
apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
usermod -a -G docker ubuntu
curl -o /home/ubuntu/docker-compose.yaml "https://configuration.weaviate.io/v2/docker-compose/docker-compose.yml?generative_cohere=false&generative_openai=false&generative_palm=false&gpu_support=false&media_type=text&modules=modules&ner_module=false&qna_module=false&ref2vec_centroid=false&runtime=docker-compose&spellcheck_module=false&sum_module=false&text_module=text2vec-transformers&transformers_model=sentence-transformers-multi-qa-MiniLM-L6-cos-v1&weaviate_version=v1.19.8"
sleep 1
awk '
  /^  weaviate:$/ {
    print
    print "    restart: always"
    print "    volumes:"
    print "      - /data/weaviate:/var/lib/weaviate"
    while(getline && $0 !~ /^  /);
    if ($0 ~ /^  /) {
      print
    }
    next
  }
  /^  t2v-transformers:$/ {
    print
    print "    restart: always"
    while(getline && $0 !~ /^  /);
    if ($0 ~ /^  /) {
      print
    }
    next
  }
  /CLUSTER_HOSTNAME: '\''node1'\''/ {
    print
    print "      AUTOSCHEMA_ENABLED: '\''false'\''"
    next
  }
  /restart: on-failure:0/ {
    next
  }
  1' /home/ubuntu/docker-compose.yaml > /home/ubuntu/docker-compose-temp.yaml && mv /home/ubuntu/docker-compose-temp.yaml /home/ubuntu/docker-compose.yaml
cd /home/ubuntu && docker compose up -d