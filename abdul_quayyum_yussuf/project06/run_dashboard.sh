#!/usr/bin/env bash
set -euo pipefail

tag="bmore-dashboard:latest"

echo "Building Docker image..."
docker build -t "$tag" .

echo "Running dashboard container..."
docker run --rm -p 3838:3838 "$tag"

echo "Dashboard running at http://localhost:3838 — open this in your browser"