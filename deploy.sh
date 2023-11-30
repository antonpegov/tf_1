#!/bin/bash

# Turn on Error Handling
set -e
ECR_URL="665162665527.dkr.ecr.eu-west-1.amazonaws.com/adm022"
IMAGE="${ECR_URL}:$(cd uploadhub && git rev-parse --short HEAD)"

echo $IMAGE

docker build -t $IMAGE -f uploadhub/Dockerfile uploadhub/

echo ___________________Login to our ECR...

aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin $ECR_URL

echo ___________________Pushing image to ECR...

docker push $IMAGE

echo ___________________Terraforming...

export TF_VAR_image=$IMAGE

terraform apply -replace="aws_instance.this" -auto-approve 