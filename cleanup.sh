#!/bin/bash

echo "Stopping and cleaning up the CDC pipeline..."

# Stop and remove containers
docker-compose down

# Remove volumes (optional - uncomment if you want to clean data)
# docker-compose down -v

# Remove dangling images (optional)
# docker image prune -f

echo "Cleanup completed!"
