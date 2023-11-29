#!/bin/bash

set -e
ECR_URL="665162665527.dkr.ecr.eu-west-1.amazonaws.com/adm022"
IMAGE="${ECR_URL}:$(cd uploadhub && git rev-parse --short HEAD)"

echo $IMAGE
docker build -t $IMAGE -f uploadhub/Dockerfile uploadhub/

# login to our ECR

eval $(aws ecr get-login --no-include-email --region eu-west-1)
docker push $IMAGE
export TF_VAR_image=$IMAGE
terraform apply -replace="aws_instance.this" -auto-approve 