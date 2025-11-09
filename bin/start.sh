#!/bin/bash

set -e

echo "Starting the application..."

# Start and wait until all services report healthy (requires healthchecks)
docker compose up -d --wait --wait-timeout 120 app-apiserver

# (Optional) show a quick status summary
docker compose ps

# Add your application startup commands here
echo "Application started successfully!" 
