#!/bin/bash
set -e

echo "Starting LiteLLM API Gateway in DEVELOPMENT mode..."
docker-compose -f docker-compose.yml -f docker-compose.override.yml up -d

echo "Services started! Gateway is available at http://localhost:8080"
echo "LiteLLM is also directly accessible at http://localhost:4000"
