#!/bin/bash
set -e

s3_bucket="ca045393-c70c-4328-aeaf-d0fd56a60a1a-docker-compose-bucket"

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