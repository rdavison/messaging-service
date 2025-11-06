#!/bin/bash

set -e

echo "Starting the application..."
echo "Environment: ${ENV:-development}"

# Build images (pull latest base layers too)
docker compose build --pull

# Start and wait until all services report healthy (requires healthchecks)
docker compose up -d --wait --wait-timeout 120

# (Optional) show a quick status summary
docker compose ps

# Add your application startup commands here
echo "Application started successfully!" 
