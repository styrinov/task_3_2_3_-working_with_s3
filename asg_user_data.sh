#!/bin/bash
set -e

# Update packages and install unzip & wget
sudo apt-get update -y
sudo apt-get install -y unzip wget

# Download the latest Amazon CloudWatch Agent Debian package
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

# Install the CloudWatch Agent
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb

# Create CloudWatch Agent config directory
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

# Write config file to collect memory usage metrics
sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json > /dev/null <<EOF
{
  "metrics": {
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Start the CloudWatch Agent with the config file
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

s3_bucket="ca045393-c70c-4328-aeaf-d0fd56a60a1a-docker-compose-bucket"

aws s3 cp s3://$s3_bucket/.env /home/ubuntu/projects/.env
chown ubuntu:ubuntu /home/ubuntu/projects/.env

echo "Checking .env file:"
ls -la /home/ubuntu/projects/.env || echo ".env file missing"
cat /home/ubuntu/projects/.env || echo ".env file missing content"

aws s3 cp s3://$s3_bucket/docker-compose.yml /home/ubuntu/projects/docker/docker-compose.yml
chown ubuntu:ubuntu /home/ubuntu/projects/docker/docker-compose.yml

echo "Checking docker-compose.yml file:"
ls -la /home/ubuntu/projects/docker/docker-compose.yml || echo "docker-compose.yml missing"
cat /home/ubuntu/projects/docker/docker-compose.yml || echo "docker-compose.yml missing content"

cd /home/ubuntu/projects

sudo docker compose -f ./docker/docker-compose.yml down
sudo docker compose -f ./docker/docker-compose.yml pull
sudo docker compose --env-file /home/ubuntu/projects/.env -f ./docker/docker-compose.yml up -d
sudo docker ps
sudo systemctl restart nginx