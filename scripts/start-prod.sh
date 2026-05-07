#!/bin/bash
set -e

echo "Starting LiteLLM API Gateway in PRODUCTION mode..."
docker-compose -f docker-compose.yml up -d

echo "Services started! Gateway is available at your configured domain."
