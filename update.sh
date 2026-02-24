#!/bin/bash
set -e
echo "Pulling latest Newt image..."
docker compose pull newt
echo "Restarting tunnel with updated image..."
docker compose up -d newt
echo "Update complete. Current status:"
docker compose ps newt
