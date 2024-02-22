#!/bin/bash

set -e


if [[ -z $ECR_REPO_URL ]]; then
    echo "ECR_REPO_URL variable must be set" 1>&2
    exit 1
fi


docker build -t fastapi-background-tasks . --target prod
docker tag fastapi-background-tasks:latest $ECR_REPO_URL/fastapi-background-tasks:latest
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO_URL
docker push $ECR_REPO_URL/fastapi-background-tasks:latest
