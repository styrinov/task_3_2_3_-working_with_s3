#!/bin/bash

cd /home/ubuntu/projects/task_3_2_5_deploying_app2ec2_via_cd
sudo docker compose -f docker/docker-compose.yml down
sudo docker rm -vf $(docker ps -aq)
sudo docker rmi -f $(docker images -aq)
sudo docker compose --env-file ./.env -f docker/docker-compose.yml up -d
sudo docker ps