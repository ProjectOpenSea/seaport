#!/bin/bash

# Create backup branch if it doesn't exist
git checkout -b backup/auto-save 2>/dev/null || git checkout backup/auto-save

# Add all changes
git add .

# Create a timestamp
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Commit with timestamp
git commit -m "Auto-save backup: $TIMESTAMP"

# Push to remote backup branch
git push origin backup/auto-save

# Return to previous branch
git checkout - 