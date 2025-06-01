#!/bin/bash

set -e

docker build -t docs-v2 .

docker tag docs-v2:latest ghcr.io/hololinked-dev/docs-v2:latest

docker push ghcr.io/hololinked-dev/docs-v2:latest

echo "Docker image built and pushed successfully."